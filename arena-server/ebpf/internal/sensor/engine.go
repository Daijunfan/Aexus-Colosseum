package sensor

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"aexus.colosseum/pit-ebpf-sensor/internal/classifier"
	"aexus.colosseum/pit-ebpf-sensor/internal/model"
	"aexus.colosseum/pit-ebpf-sensor/internal/resolver"
)

// Config configures pit-ebpf-sensor runtime behavior.
type Config struct {
	DockerSocket     string
	PollInterval     time.Duration
	IncludeUnlabeled bool
	PitdURL          string
	PitdToken        string
	ListenAddr       string
	ReplayDemo       bool
	ReplayInterval   time.Duration
	ReplayLoop       bool
	DedupWindow      time.Duration
	Stdout           io.Writer
	Stderr           io.Writer
}

// Engine coordinates eBPF probes (or replay emitter), Docker container resolution,
// deterministic VFX classification, stdout JSONL output, SSE fanout, and pitd shipping.
type Engine struct {
	cfg       Config
	startedAt time.Time
	resolver  *resolver.Resolver
	shipper   *Shipper

	seq           atomic.Uint64
	sslHookedLibs atomic.Int32

	stateMu        sync.RWMutex
	mode           string
	btfEnabled     bool
	attachedProbes []string
	vfxCounts      map[string]uint64
	recentEvents   []model.EventEnvelope
	perfStats      *model.KernelPerfStats

	outMu sync.Mutex

	dedupMu   sync.Mutex
	dedupSeen map[string]time.Time

	subMu     sync.RWMutex
	nextSubID int
	subs      map[int]chan model.EventEnvelope

	sslSyncHook func([]model.ContainerMeta)
}

func NewEngine(cfg Config) *Engine {
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = 1200 * time.Millisecond
	}
	if cfg.Stdout == nil {
		cfg.Stdout = os.Stdout
	}
	if cfg.Stderr == nil {
		cfg.Stderr = os.Stderr
	}

	e := &Engine{
		cfg:       cfg,
		startedAt: time.Now(),
		shipper:   NewShipper(cfg.PitdURL, cfg.PitdToken),
		mode:      "initializing",
		vfxCounts: make(map[string]uint64),
		dedupSeen: make(map[string]time.Time),
		subs:      make(map[int]chan model.EventEnvelope),
	}

	e.resolver = resolver.NewResolver(
		cfg.DockerSocket,
		cfg.PollInterval,
		cfg.IncludeUnlabeled,
		func(containers []model.ContainerMeta) {
			e.stateMu.RLock()
			hook := e.sslSyncHook
			e.stateMu.RUnlock()
			if hook != nil {
				hook(containers)
			}
		},
	)
	return e
}

func (e *Engine) Resolver() *resolver.Resolver {
	return e.resolver
}

func (e *Engine) setKernelStatus(mode string, btf bool, probes []string) {
	e.stateMu.Lock()
	defer e.stateMu.Unlock()
	e.mode = mode
	e.btfEnabled = btf
	cp := make([]string, len(probes))
	copy(cp, probes)
	e.attachedProbes = cp
}

func (e *Engine) updatePerfStats(ps model.KernelPerfStats) {
	e.stateMu.Lock()
	cp := ps
	e.perfStats = &cp
	e.stateMu.Unlock()
}

func (e *Engine) setSSLSyncHook(fn func([]model.ContainerMeta)) {
	e.stateMu.Lock()
	e.sslSyncHook = fn
	e.stateMu.Unlock()
}

// Run starts background shippers, container discovery, and either real Linux eBPF probes or replay mode.
func (e *Engine) Run(ctx context.Context) error {
	if e.shipper != nil {
		e.shipper.Start(ctx)
	}

	if e.cfg.ReplayDemo {
		e.setKernelStatus("replay_sim", false, []string{
			"replay/sys_enter_execve",
			"replay/sys_enter_connect",
			"replay/sys_enter_openat",
			"replay/commit_creds",
			"replay/uprobe:SSL_write",
		})
		return e.RunReplayDemo(ctx, e.cfg.ReplayInterval, e.cfg.ReplayLoop)
	}

	return e.runKernelSensor(ctx)
}

// ProcessRawEvent resolves, classifies, deduplicates, logs, and ships a raw event.
func (e *Engine) ProcessRawEvent(raw model.RawKernelEvent) (model.EventEnvelope, bool) {
	srcMeta, ok := e.resolver.LookupByCgroupOrPID(raw.CgroupID, raw.PID)
	if !ok {
		return model.EventEnvelope{}, false
	}

	var dstPtr *model.ContainerMeta
	if raw.DstIP != "" {
		if dm, found := e.resolver.LookupByIP(raw.DstIP); found {
			copyMeta := dm
			dstPtr = &copyMeta
		}
	}

	ppid, parentComm, cmdline, tree := resolver.ReadProcDetails(
		raw.PID,
		srcMeta.CgroupID,
		raw.PPID,
		raw.Comm,
		raw.ParentComm,
		raw.Cmdline(),
		e.resolver.PIDHistory(),
	)

	inferredTargetID, inferredDstIP := e.resolver.ResolveTargetInText(srcMeta.MatchID, cmdline)
	recentSeatID, recentSrcIP := e.resolver.RecentAttackerForTarget(srcMeta.TargetID)

	payload, matched := classifier.Classify(classifier.Input{
		Raw:                  raw,
		SourceContainer:      srcMeta,
		DstContainer:         dstPtr,
		InferredTargetID:     inferredTargetID,
		InferredDstIP:        inferredDstIP,
		RecentAttackerSeatID: recentSeatID,
		RecentAttackerIP:     recentSrcIP,
		PPID:                 ppid,
		ParentComm:           parentComm,
		Cmdline:              cmdline,
		ProcessTree:          tree,
	})
	if !matched {
		return model.EventEnvelope{}, false
	}

	if !e.allowAfterDedup(srcMeta.CgroupID, payload) {
		return model.EventEnvelope{}, false
	}

	if srcMeta.Role == model.RoleFighter && payload.TargetID != "" {
		e.resolver.RecordAttackerTouch(payload.TargetID, srcMeta.SeatID, srcMeta.PrimaryIP)
	}

	seq := e.seq.Add(1)
	env := model.EventEnvelope{
		Seq:              seq,
		TsMs:             time.Now().UnixMilli(),
		MatchID:          srcMeta.MatchID,
		Kind:             "EBPF_EVENT",
		ContainerID:      srcMeta.ShortID,
		ContainerName:    srcMeta.Name,
		ContainerRole:    srcMeta.Role,
		EBPFEventPayload: payload,
		Payload:          payload,
	}

	e.recordAndBroadcast(env)
	return env, true
}

func (e *Engine) allowAfterDedup(cgroupID uint64, p model.EBPFEventPayload) bool {
	if e.cfg.DedupWindow <= 0 {
		return true
	}

	var key string
	switch p.VFXType {
	case model.VFXPrecisionExploitBeam:
		if p.Probe == "sys_enter_connect" {
			// Coalesce high-rate TCP port scan connect bursts per (container, pid, dst_ip)
			key = fmt.Sprintf("conn:%d:%d:%s", cgroupID, p.PID, p.DstIP)
		} else {
			key = fmt.Sprintf("exec:%d:%d:%s", cgroupID, p.PID, p.Cmdline)
		}
	case model.VFXRootShockwave:
		// Coalesce simultaneous setuid + commit_creds for the same PID
		key = fmt.Sprintf("root:%d:%d", cgroupID, p.PID)
	case model.VFXSSLCleartextIntercept:
		key = fmt.Sprintf("ssl:%d:%d:%s:%s", cgroupID, p.PID, p.Probe, p.HitLocation)
	default:
		key = fmt.Sprintf("ev:%d:%s:%d:%s", cgroupID, p.VFXType, p.PID, p.HitLocation)
	}

	now := time.Now()
	e.dedupMu.Lock()
	defer e.dedupMu.Unlock()

	if prev, exists := e.dedupSeen[key]; exists && now.Sub(prev) < e.cfg.DedupWindow {
		return false
	}
	if len(e.dedupSeen) > 4096 {
		cutoff := now.Add(-2 * e.cfg.DedupWindow)
		for k, ts := range e.dedupSeen {
			if ts.Before(cutoff) {
				delete(e.dedupSeen, k)
			}
		}
	}
	e.dedupSeen[key] = now
	return true
}

func (e *Engine) recordAndBroadcast(env model.EventEnvelope) {
	if line, err := json.Marshal(env); err == nil {
		e.outMu.Lock()
		_, _ = e.cfg.Stdout.Write(append(line, '\n'))
		e.outMu.Unlock()
	}

	e.stateMu.Lock()
	e.vfxCounts[string(env.VFXType)]++
	const maxRecent = 512
	if len(e.recentEvents) >= maxRecent {
		copy(e.recentEvents, e.recentEvents[1:])
		e.recentEvents[len(e.recentEvents)-1] = env
	} else {
		e.recentEvents = append(e.recentEvents, env)
	}
	e.stateMu.Unlock()

	e.subMu.RLock()
	for _, ch := range e.subs {
		select {
		case ch <- env:
		default:
		}
	}
	e.subMu.RUnlock()

	if e.shipper != nil {
		e.shipper.Enqueue(env)
	}
}

func (e *Engine) Subscribe() (<-chan model.EventEnvelope, func()) {
	ch := make(chan model.EventEnvelope, 128)
	e.subMu.Lock()
	id := e.nextSubID
	e.nextSubID++
	e.subs[id] = ch
	e.subMu.Unlock()

	unsub := func() {
		e.subMu.Lock()
		if existing, ok := e.subs[id]; ok {
			delete(e.subs, id)
			close(existing)
		}
		e.subMu.Unlock()
	}
	return ch, unsub
}

func (e *Engine) RecentEvents(limit int) []model.EventEnvelope {
	e.stateMu.RLock()
	defer e.stateMu.RUnlock()
	n := len(e.recentEvents)
	if limit <= 0 || limit > n {
		limit = n
	}
	out := make([]model.EventEnvelope, limit)
	copy(out, e.recentEvents[n-limit:])
	return out
}

func (e *Engine) Status() model.SensorStatus {
	containers := e.resolver.Snapshot()
	shipped, shipErrs := e.shipper.Stats()

	e.stateMu.RLock()
	mode := e.mode
	btf := e.btfEnabled
	probes := make([]string, len(e.attachedProbes))
	copy(probes, e.attachedProbes)
	counts := make(map[string]uint64, len(e.vfxCounts))
	for k, v := range e.vfxCounts {
		counts[k] = v
	}
	var perfCopy *model.KernelPerfStats
	if e.perfStats != nil {
		cp := *e.perfStats
		perfCopy = &cp
	}
	e.stateMu.RUnlock()

	return model.SensorStatus{
		OK:                 true,
		Service:            "pit-ebpf-sensor",
		Mode:               mode,
		BTFEnabled:         btf,
		KernelRelease:      resolver.KernelRelease(),
		AttachedProbes:     probes,
		SSLLibrariesHooked: int(e.sslHookedLibs.Load()),
		TrackedContainers:  len(containers),
		Containers:         containers,
		EventsCaptured:     e.seq.Load(),
		EventsByVFX:        counts,
		EventsShipped:      shipped,
		ShipErrors:         shipErrs,
		UptimeMs:           time.Since(e.startedAt).Milliseconds(),
		PerfStats:          perfCopy,
	}
}

func (e *Engine) logf(format string, args ...any) {
	_, _ = fmt.Fprintf(e.cfg.Stderr, "[pit-ebpf-sensor] "+format+"\n", args...)
}
