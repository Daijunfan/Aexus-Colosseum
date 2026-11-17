//go:build linux

package resolver

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

// SSLLibCandidate represents a unique OpenSSL shared library inode to attach uprobes to.
type SSLLibCandidate struct {
	Path string
	Dev  uint64
	Ino  uint64
}

// HostRootCgroupID returns the inode number of /sys/fs/cgroup (root cgroupv2).
func HostRootCgroupID() uint64 {
	var st syscall.Stat_t
	if err := syscall.Stat("/sys/fs/cgroup", &st); err == nil {
		return st.Ino
	}
	return 0
}

// KernelRelease reads /proc/sys/kernel/osrelease.
func KernelRelease() string {
	b, err := os.ReadFile("/proc/sys/kernel/osrelease")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// ResolveContainerCgroup determines the exact cgroup_id matching bpf_get_current_cgroup_id()
// for a running Docker container (supporting cgroup v2 & v1 layouts).
func ResolveContainerCgroup(initPID int, fullContainerID string) (uint64, string) {
	var candidates []string

	if initPID > 0 {
		if raw, err := os.ReadFile(fmt.Sprintf("/proc/%d/cgroup", initPID)); err == nil {
			for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
				// Format: hierarchy-ID:controller-list:cgroup-path
				parts := strings.SplitN(line, ":", 3)
				if len(parts) != 3 {
					continue
				}
				sub := strings.TrimSpace(parts[2])
				if sub == "" || sub == "/" {
					continue
				}
				// Prefer unified cgroupv2 (0::/...) first
				if parts[0] == "0" {
					candidates = append([]string{filepath.Join("/sys/fs/cgroup", sub)}, candidates...)
				} else {
					candidates = append(candidates,
						filepath.Join("/sys/fs/cgroup/unified", sub),
						filepath.Join("/sys/fs/cgroup/systemd", sub),
						filepath.Join("/sys/fs/cgroup", sub),
					)
				}
			}
		}
	}

	if fullContainerID != "" {
		candidates = append(candidates,
			fmt.Sprintf("/sys/fs/cgroup/system.slice/docker-%s.scope", fullContainerID),
			fmt.Sprintf("/sys/fs/cgroup/docker/%s", fullContainerID),
		)
	}

	for _, p := range candidates {
		var st syscall.Stat_t
		if err := syscall.Stat(p, &st); err == nil && st.Ino != 0 {
			return st.Ino, p
		}
	}
	return 0, ""
}

// ExtractContainerIDFromProcCgroup parses /proc/<pid>/cgroup for a 64-char hex container ID.
func ExtractContainerIDFromProcCgroup(pid uint32) (string, uint64) {
	if pid == 0 {
		return "", 0
	}
	raw, err := os.ReadFile(fmt.Sprintf("/proc/%d/cgroup", pid))
	if err != nil {
		return "", 0
	}
	return ParseContainerIDFromCgroupText(string(raw))
}

// ReadProcDetails enriches PPID, parent comm, cmdline, and builds process_tree from /proc + PIDHistory.
func ReadProcDetails(
	pid uint32,
	containerCgroupID uint64,
	kernPPID uint32,
	kernComm string,
	kernParentComm string,
	kernCmdline string,
	history *PIDHistory,
) (ppid uint32, parentComm string, cmdline string, tree []string) {
	ppid = kernPPID
	parentComm = kernParentComm
	cmdline = kernCmdline

	if procCmd := readProcCmdline(pid); procCmd != "" && len(procCmd) > len(cmdline) {
		cmdline = procCmd
	}
	if ppid == 0 {
		ppid = readProcPPID(pid)
	}
	if parentComm == "" && ppid > 0 {
		if c := readProcComm(ppid); c != "" {
			parentComm = c
		} else if h, ok := history.Get(ppid); ok {
			parentComm = h.Comm
		}
	}

	curLabel := formatProcessNode(pid, kernComm, cmdline)
	if history != nil && pid > 0 {
		history.Record(pid, ppid, kernComm, cmdline, containerCgroupID)
	}

	// Build ancestor chain from oldest container process -> current process
	var ancestors []string
	currParent := ppid
	for depth := 0; depth < 4 && currParent > 1; depth++ {
		pCgroup := readProcCgroupIno(currParent)
		if containerCgroupID != 0 && pCgroup != 0 && pCgroup != containerCgroupID {
			break // Reached host containerd-shim / systemd outside container namespace
		}
		pComm := readProcComm(currParent)
		pCmd := readProcCmdline(currParent)
		nextPPID := readProcPPID(currParent)

		if pComm == "" && history != nil {
			if rec, ok := history.Get(currParent); ok {
				if containerCgroupID != 0 && rec.CgroupID != 0 && rec.CgroupID != containerCgroupID {
					break
				}
				pComm = rec.Comm
				pCmd = rec.Cmdline
				nextPPID = rec.PPID
			}
		}
		if pComm == "" && currParent == kernPPID && kernParentComm != "" {
			pComm = kernParentComm
		}
		if pComm == "" || pComm == "containerd-shim" || strings.HasPrefix(pComm, "containerd-shim") {
			break
		}

		ancestors = append(ancestors, formatProcessNode(currParent, pComm, pCmd))
		if nextPPID == 0 || nextPPID == currParent {
			break
		}
		currParent = nextPPID
	}

	tree = make([]string, 0, len(ancestors)+1)
	for i := len(ancestors) - 1; i >= 0; i-- {
		tree = append(tree, ancestors[i])
	}
	tree = append(tree, curLabel)
	return ppid, parentComm, cmdline, tree
}

func readProcCmdline(pid uint32) string {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/cmdline", pid))
	if err != nil || len(b) == 0 {
		return ""
	}
	b = bytes.TrimRight(b, "\x00")
	parts := bytes.Split(b, []byte{0})
	strs := make([]string, 0, len(parts))
	for _, p := range parts {
		if len(p) > 0 {
			strs = append(strs, string(p))
		}
	}
	res := strings.Join(strs, " ")
	if len(res) > 240 {
		res = res[:240]
	}
	return res
}

func readProcComm(pid uint32) string {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readProcPPID(pid uint32) uint32 {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/status", pid))
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "PPid:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				if v, err := strconv.ParseUint(fields[1], 10, 32); err == nil {
					return uint32(v)
				}
			}
			break
		}
	}
	return 0
}

func readProcCgroupIno(pid uint32) uint64 {
	raw, err := os.ReadFile(fmt.Sprintf("/proc/%d/cgroup", pid))
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
		parts := strings.SplitN(line, ":", 3)
		if len(parts) == 3 && parts[0] == "0" && parts[2] != "" {
			var st syscall.Stat_t
			if syscall.Stat(filepath.Join("/sys/fs/cgroup", strings.TrimSpace(parts[2])), &st) == nil {
				return st.Ino
			}
		}
	}
	return 0
}

// DiscoverSSLLibraries locates OpenSSL shared libraries on the host and inside active containers,
// deduplicated by (st_dev, st_ino).
func DiscoverSSLLibraries(containers []model.ContainerMeta) []SSLLibCandidate {
	relPaths := []string{
		"/usr/lib/x86_64-linux-gnu/libssl.so.3",
		"/lib/x86_64-linux-gnu/libssl.so.3",
		"/usr/lib64/libssl.so.3",
		"/lib64/libssl.so.3",
		"/lib/libssl.so.3",
		"/usr/lib/libssl.so.3",
		"/usr/lib/x86_64-linux-gnu/libssl.so.1.1",
		"/lib/x86_64-linux-gnu/libssl.so.1.1",
	}

	type inoKey struct {
		dev uint64
		ino uint64
	}
	seen := make(map[inoKey]bool)
	var out []SSLLibCandidate

	checkPath := func(p string) {
		var st syscall.Stat_t
		if err := syscall.Stat(p, &st); err != nil || st.Ino == 0 {
			return
		}
		k := inoKey{dev: uint64(st.Dev), ino: st.Ino}
		if seen[k] {
			return
		}
		seen[k] = true
		out = append(out, SSLLibCandidate{
			Path: p,
			Dev:  uint64(st.Dev),
			Ino:  st.Ino,
		})
	}

	for _, rp := range relPaths {
		checkPath(rp)
	}
	for _, c := range containers {
		if c.InitPID <= 0 {
			continue
		}
		rootPrefix := fmt.Sprintf("/proc/%d/root", c.InitPID)
		for _, rp := range relPaths {
			checkPath(rootPrefix + rp)
		}
	}
	return out
}
