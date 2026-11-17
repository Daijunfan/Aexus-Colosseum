//go:build linux

package sensor

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"sync"
	"time"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
	"github.com/cilium/ebpf/ringbuf"
	"github.com/cilium/ebpf/rlimit"

	"aexus.colosseum/pit-ebpf-sensor/bpf"
	"aexus.colosseum/pit-ebpf-sensor/internal/model"
	"aexus.colosseum/pit-ebpf-sensor/internal/resolver"
)

type sensorConfigMapVal struct {
	SensorTGID       uint32
	Pad              uint32
	HostRootCgroupID uint64
}

type bpfPerfStatsVal struct {
	SyscallsEntered   uint64
	FilteredInKernel  uint64
	RingbufSubmitted  uint64
	RingbufDrops      uint64
	ExecveSubmitted   uint64
	ConnectSubmitted  uint64
	OpenatSubmitted   uint64
	SecuritySubmitted uint64
}

type sslInodeKey struct {
	dev uint64
	ino uint64
}

func (e *Engine) runKernelSensor(ctx context.Context) error {
	if err := rlimit.RemoveMemlock(); err != nil {
		e.logf("warning: RemoveMemlock failed (continuing): %v", err)
	}

	btfPresent := false
	if _, err := os.Stat("/sys/kernel/btf/vmlinux"); err == nil {
		btfPresent = true
	}

	spec, err := ebpf.LoadCollectionSpecFromReader(bytes.NewReader(bpf.ProbesELF))
	if err != nil {
		return fmt.Errorf("load embedded eBPF spec: %w", err)
	}

	coll, err := ebpf.NewCollectionWithOptions(spec, ebpf.CollectionOptions{})
	if err != nil {
		return fmt.Errorf("load eBPF collection into kernel: %w", err)
	}
	defer coll.Close()

	// Configure kernel-side self-PID & host root cgroup filtering to prevent feedback loops
	if cfgMap, ok := coll.Maps["sensor_config"]; ok {
		zero := uint32(0)
		val := sensorConfigMapVal{
			SensorTGID:       uint32(os.Getpid()),
			HostRootCgroupID: resolver.HostRootCgroupID(),
		}
		if err := cfgMap.Put(&zero, &val); err != nil {
			e.logf("warning: failed to update sensor_config map: %v", err)
		}
	}

	var links []link.Link
	defer func() {
		for _, l := range links {
			_ = l.Close()
		}
	}()

	var attachedNames []string

	// Attach core syscall tracepoints
	tpSpecs := []struct {
		group string
		name  string
		prog  string
	}{
		{"syscalls", "sys_enter_execve", "handle_sys_enter_execve"},
		{"syscalls", "sys_exit_execve", "handle_sys_exit_execve"},
		{"syscalls", "sys_enter_connect", "handle_sys_enter_connect"},
		{"syscalls", "sys_enter_openat", "handle_sys_enter_openat"},
		{"syscalls", "sys_enter_setuid", "handle_sys_enter_setuid"},
		{"syscalls", "sys_enter_setresuid", "handle_sys_enter_setresuid"},
	}

	for _, tp := range tpSpecs {
		prog, ok := coll.Programs[tp.prog]
		if !ok {
			return fmt.Errorf("missing eBPF program %q in collection", tp.prog)
		}
		l, err := link.Tracepoint(tp.group, tp.name, prog, nil)
		if err != nil {
			return fmt.Errorf("attach tracepoint/%s/%s: %w", tp.group, tp.name, err)
		}
		links = append(links, l)
		attachedNames = append(attachedNames, fmt.Sprintf("tracepoint/%s/%s", tp.group, tp.name))
	}

	// Optional graceful attach for kprobe/commit_creds
	if kpProg, ok := coll.Programs["handle_commit_creds"]; ok {
		if kpLink, err := link.Kprobe("commit_creds", kpProg, nil); err == nil {
			links = append(links, kpLink)
			attachedNames = append(attachedNames, "kprobe/commit_creds")
		} else {
			e.logf("optional kprobe/commit_creds unavailable (setuid/setresuid tracepoints active): %v", err)
		}
	}

	// Dynamic OpenSSL uprobe/uretprobe manager across host + container rootfs overlays
	var sslMu sync.Mutex
	sslLinks := make(map[sslInodeKey][]link.Link)
	defer func() {
		sslMu.Lock()
		for _, ls := range sslLinks {
			for _, l := range ls {
				_ = l.Close()
			}
		}
		sslMu.Unlock()
	}()

	syncSSL := func(containers []model.ContainerMeta) {
		candidates := resolver.DiscoverSSLLibraries(containers)
		sslMu.Lock()
		defer sslMu.Unlock()

		for _, cand := range candidates {
			key := sslInodeKey{dev: cand.Dev, ino: cand.Ino}
			if _, already := sslLinks[key]; already {
				continue
			}

			ex, err := link.OpenExecutable(cand.Path)
			if err != nil {
				continue
			}

			var libAttached []link.Link
			if p := coll.Programs["handle_ssl_write"]; p != nil {
				if l, err := ex.Uprobe("SSL_write", p, nil); err == nil {
					libAttached = append(libAttached, l)
				}
			}
			if p := coll.Programs["handle_ssl_write_ex"]; p != nil {
				if l, err := ex.Uprobe("SSL_write_ex", p, nil); err == nil {
					libAttached = append(libAttached, l)
				}
			}
			if pEnter, pExit := coll.Programs["handle_ssl_read_enter"], coll.Programs["handle_ssl_read_exit"]; pEnter != nil && pExit != nil {
				if l1, err := ex.Uprobe("SSL_read", pEnter, nil); err == nil {
					if l2, err := ex.Uretprobe("SSL_read", pExit, nil); err == nil {
						libAttached = append(libAttached, l1, l2)
					} else {
						_ = l1.Close()
					}
				}
			}
			if pEnter, pExit := coll.Programs["handle_ssl_read_ex_enter"], coll.Programs["handle_ssl_read_ex_exit"]; pEnter != nil && pExit != nil {
				if l1, err := ex.Uprobe("SSL_read_ex", pEnter, nil); err == nil {
					if l2, err := ex.Uretprobe("SSL_read_ex", pExit, nil); err == nil {
						libAttached = append(libAttached, l1, l2)
					} else {
						_ = l1.Close()
					}
				}
			}

			if len(libAttached) > 0 {
				sslLinks[key] = libAttached
				e.sslHookedLibs.Store(int32(len(sslLinks)))
				e.logf("attached OpenSSL cleartext uprobes (%d symbols) -> %s (ino=%d)", len(libAttached), cand.Path, cand.Ino)
			}
		}
	}

	e.setSSLSyncHook(syncSSL)
	e.resolver.Start(ctx)
	syncSSL(e.resolver.Snapshot())

	if e.sslHookedLibs.Load() > 0 {
		attachedNames = append(attachedNames, "uprobe/libssl:SSL_write", "uretprobe/libssl:SSL_read")
	}

	e.setKernelStatus("kernel_ebpf", btfPresent, attachedNames)
	e.logf("kernel eBPF God's-Eye active (kernel=%s, btf=%v, probes=%d, ssl_libs=%d)",
		resolver.KernelRelease(), btfPresent, len(attachedNames), e.sslHookedLibs.Load())

	eventsMap, ok := coll.Maps["events"]
	if !ok {
		return fmt.Errorf("missing events ringbuf map")
	}
	ringbufCap := uint64(eventsMap.MaxEntries())

	// Sample zero-lock per-CPU pit_perf_stats map every 1s to compute live kernel filtering efficiency & throughput
	if perfMap, hasPerf := coll.Maps["pit_perf_stats"]; hasPerf {
		samplePerf := func(prevSys, prevSub uint64, prevAt time.Time) (uint64, uint64, time.Time) {
			zero := uint32(0)
			var perCPU []bpfPerfStatsVal
			now := time.Now()
			if err := perfMap.Lookup(&zero, &perCPU); err != nil || len(perCPU) == 0 {
				return prevSys, prevSub, prevAt
			}
			var sum bpfPerfStatsVal
			for _, cpuVal := range perCPU {
				sum.SyscallsEntered += cpuVal.SyscallsEntered
				sum.FilteredInKernel += cpuVal.FilteredInKernel
				sum.RingbufSubmitted += cpuVal.RingbufSubmitted
				sum.RingbufDrops += cpuVal.RingbufDrops
				sum.ExecveSubmitted += cpuVal.ExecveSubmitted
				sum.ConnectSubmitted += cpuVal.ConnectSubmitted
				sum.OpenatSubmitted += cpuVal.OpenatSubmitted
				sum.SecuritySubmitted += cpuVal.SecuritySubmitted
			}
			filterPct := 0.0
			if sum.SyscallsEntered > 0 {
				filterPct = (float64(sum.FilteredInKernel) / float64(sum.SyscallsEntered)) * 100.0
				if filterPct > 100.0 {
					filterPct = 100.0
				}
				filterPct = math.Round(filterPct*100) / 100
			}
			sysPerSec := 0.0
			evPerSec := 0.0
			if !prevAt.IsZero() {
				dt := now.Sub(prevAt).Seconds()
				if dt > 0.05 {
					if sum.SyscallsEntered >= prevSys {
						sysPerSec = math.Round((float64(sum.SyscallsEntered-prevSys)/dt)*10) / 10
					}
					if sum.RingbufSubmitted >= prevSub {
						evPerSec = math.Round((float64(sum.RingbufSubmitted-prevSub)/dt)*10) / 10
					}
				}
			}
			e.updatePerfStats(model.KernelPerfStats{
				CPUCores:             len(perCPU),
				RingbufCapacityBytes: ringbufCap,
				SyscallsEntered:      sum.SyscallsEntered,
				FilteredInKernel:     sum.FilteredInKernel,
				RingbufSubmitted:     sum.RingbufSubmitted,
				RingbufDrops:         sum.RingbufDrops,
				ExecveSubmitted:      sum.ExecveSubmitted,
				ConnectSubmitted:     sum.ConnectSubmitted,
				OpenatSubmitted:      sum.OpenatSubmitted,
				SecuritySubmitted:    sum.SecuritySubmitted,
				KernelFilterPct:      filterPct,
				SyscallsPerSec:       sysPerSec,
				EventsPerSec:         evPerSec,
			})
			return sum.SyscallsEntered, sum.RingbufSubmitted, now
		}

		pSys, pSub, pAt := samplePerf(0, 0, time.Time{})
		go func() {
			ticker := time.NewTicker(time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-ctx.Done():
					return
				case <-ticker.C:
					pSys, pSub, pAt = samplePerf(pSys, pSub, pAt)
				}
			}
		}()
	}
	rd, err := ringbuf.NewReader(eventsMap)
	if err != nil {
		return fmt.Errorf("open BPF ringbuf reader: %w", err)
	}

	go func() {
		<-ctx.Done()
		_ = rd.Close()
	}()

	for {
		rec, err := rd.Read()
		if err != nil {
			if errors.Is(err, ringbuf.ErrClosed) || ctx.Err() != nil {
				return nil
			}
			e.logf("ringbuf read warning: %v", err)
			continue
		}

		rawEv, err := model.DecodeRawKernelEvent(rec.RawSample)
		if err != nil {
			continue
		}
		e.ProcessRawEvent(rawEv)
	}
}
