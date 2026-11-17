package resolver

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

var hex64Re = regexp.MustCompile(`([a-f0-9]{64})`)

// PIDRecord stores process lineage observed from execve or /proc.
type PIDRecord struct {
	PID      uint32
	PPID     uint32
	Comm     string
	Cmdline  string
	CgroupID uint64
	SeenAt   time.Time
}

// PIDHistory maintains a bounded thread-safe cache of recent container processes.
type PIDHistory struct {
	mu      sync.RWMutex
	maxSize int
	items   map[uint32]PIDRecord
}

func NewPIDHistory(maxSize int) *PIDHistory {
	if maxSize <= 0 {
		maxSize = 4096
	}
	return &PIDHistory{
		maxSize: maxSize,
		items:   make(map[uint32]PIDRecord, 512),
	}
}

func (h *PIDHistory) Record(pid, ppid uint32, comm, cmdline string, cgroupID uint64) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.items) >= h.maxSize {
		cutoff := time.Now().Add(-2 * time.Minute)
		for k, v := range h.items {
			if v.SeenAt.Before(cutoff) {
				delete(h.items, k)
			}
		}
		if len(h.items) >= h.maxSize {
			for k := range h.items {
				delete(h.items, k)
				break
			}
		}
	}
	h.items[pid] = PIDRecord{
		PID:      pid,
		PPID:     ppid,
		Comm:     comm,
		Cmdline:  cmdline,
		CgroupID: cgroupID,
		SeenAt:   time.Now(),
	}
}

func (h *PIDHistory) Get(pid uint32) (PIDRecord, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	rec, ok := h.items[pid]
	return rec, ok
}

func formatProcessNode(pid uint32, comm, cmdline string) string {
	label := strings.TrimSpace(cmdline)
	if label == "" {
		label = strings.TrimSpace(comm)
	}
	if label == "" {
		label = "proc"
	}
	if len(label) > 96 {
		label = label[:96] + "..."
	}
	return fmt.Sprintf("%s (PID %d)", label, pid)
}

// ParseContainerIDFromCgroupText extracts a 64-hex Docker/containerd ID from /proc/<pid>/cgroup content.
func ParseContainerIDFromCgroupText(raw string) (string, uint64) {
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if !strings.Contains(line, "docker") &&
			!strings.Contains(line, "containerd") &&
			!strings.Contains(line, "kubepods") &&
			!strings.Contains(line, "/containers/") {
			continue
		}
		if m := hex64Re.FindStringSubmatch(line); len(m) >= 2 {
			return m[1], 0
		}
	}
	return "", 0
}

// BuildContainerMeta maps Docker labels and naming conventions into canonical Pit telemetry metadata.
func BuildContainerMeta(rc RawDockerContainer, cgroupID uint64, cgroupPath string, includeUnlabeled bool) (model.ContainerMeta, bool) {
	name := strings.TrimPrefix(strings.TrimSpace(rc.Name), "/")
	lowerName := strings.ToLower(name)
	labels := rc.Labels
	if labels == nil {
		labels = map[string]string{}
	}

	matchID := firstNonEmpty(
		labels["pit.match_id"],
		labels["arena.match_id"],
	)
	seatID := firstNonEmpty(
		labels["pit.seat_id"],
		labels["arena.seat_id"],
	)
	targetID := firstNonEmpty(
		labels["pit.target_id"],
		labels["arena.target_id"],
	)
	rawRole := strings.ToLower(strings.TrimSpace(firstNonEmpty(
		labels["pit.role"],
		labels["arena.role"],
	)))

	hasExplicitPitLabel := matchID != "" || seatID != "" || targetID != "" || rawRole != ""
	matchesNameConvention := strings.HasPrefix(lowerName, "pit-") ||
		strings.HasPrefix(lowerName, "arena-") ||
		strings.HasPrefix(lowerName, "awd-") ||
		strings.HasPrefix(lowerName, "seat-") ||
		strings.HasPrefix(lowerName, "target-") ||
		strings.HasPrefix(lowerName, "fighter-")

	if !hasExplicitPitLabel && !matchesNameConvention && !includeUnlabeled {
		return model.ContainerMeta{}, false
	}

	var role model.ContainerRole
	switch rawRole {
	case "fighter", "attacker", "seat", "harness", "player", "red":
		role = model.RoleFighter
	case "target", "victim", "fortress", "grail", "service", "blue":
		role = model.RoleTarget
	default:
		if seatID != "" && targetID == "" {
			role = model.RoleFighter
		} else if targetID != "" {
			role = model.RoleTarget
		} else if strings.Contains(lowerName, "fighter") ||
			strings.Contains(lowerName, "attacker") ||
			strings.Contains(lowerName, "attackbox") ||
			strings.Contains(lowerName, "seat-") ||
			strings.Contains(lowerName, "harness") {
			role = model.RoleFighter
		} else {
			role = model.RoleTarget
		}
	}

	if matchID == "" {
		if proj := labels["com.docker.compose.project"]; proj != "" {
			matchID = proj
		} else {
			matchID = "default-match"
		}
	}

	if role == model.RoleFighter && seatID == "" {
		seatID = name
	}
	if role == model.RoleTarget && targetID == "" {
		targetID = name
	}

	shortID := rc.ID
	if len(shortID) > 12 {
		shortID = shortID[:12]
	}

	var primaryIP string
	if len(rc.IPs) > 0 {
		primaryIP = rc.IPs[0]
	}

	return model.ContainerMeta{
		ContainerID: rc.ID,
		ShortID:     shortID,
		Name:        name,
		Image:       rc.Image,
		InitPID:     rc.InitPID,
		CgroupID:    cgroupID,
		CgroupPath:  cgroupPath,
		PrimaryIP:   primaryIP,
		IPs:         rc.IPs,
		MatchID:     matchID,
		SeatID:      seatID,
		TargetID:    targetID,
		Role:        role,
		Labels:      labels,
	}, true
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if s := strings.TrimSpace(v); s != "" {
			return s
		}
	}
	return ""
}

type attackerTouch struct {
	SeatID string
	SrcIP  string
	SeenAt time.Time
}

// Resolver maintains real-time cgroup_id <-> container and IPv4 <-> container indexes.
type Resolver struct {
	docker           *DockerClient
	includeUnlabeled bool
	pollInterval     time.Duration
	pidHistory       *PIDHistory
	onUpdate         func([]model.ContainerMeta)

	mu                  sync.RWMutex
	byCgroup            map[uint64]model.ContainerMeta
	byID                map[string]model.ContainerMeta
	byIP                map[string]model.ContainerMeta
	byName              map[string]model.ContainerMeta
	nonContainerCgroups map[uint64]time.Time
	lastAttacker        map[string]attackerTouch
}

func NewResolver(dockerSocket string, pollInterval time.Duration, includeUnlabeled bool, onUpdate func([]model.ContainerMeta)) *Resolver {
	if pollInterval <= 0 {
		pollInterval = 1200 * time.Millisecond
	}
	return &Resolver{
		docker:              NewDockerClient(dockerSocket),
		includeUnlabeled:    includeUnlabeled,
		pollInterval:        pollInterval,
		pidHistory:          NewPIDHistory(4096),
		onUpdate:            onUpdate,
		byCgroup:            make(map[uint64]model.ContainerMeta),
		byID:                make(map[string]model.ContainerMeta),
		byIP:                make(map[string]model.ContainerMeta),
		byName:              make(map[string]model.ContainerMeta),
		nonContainerCgroups: make(map[uint64]time.Time),
		lastAttacker:        make(map[string]attackerTouch),
	}
}

func (r *Resolver) PIDHistory() *PIDHistory {
	return r.pidHistory
}

// Start runs an immediate container scan, starts the Docker event listener, and polls periodically.
func (r *Resolver) Start(ctx context.Context) {
	r.Refresh(ctx)

	triggerCh := make(chan struct{}, 1)
	go r.docker.WatchContainerEvents(ctx, func() {
		select {
		case triggerCh <- struct{}{}:
		default:
		}
	})

	go func() {
		ticker := time.NewTicker(r.pollInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-triggerCh:
				r.Refresh(ctx)
			case <-ticker.C:
				r.Refresh(ctx)
			}
		}
	}()
}

// Refresh polls Docker and rebuilds the fast in-memory lookup maps.
func (r *Resolver) Refresh(ctx context.Context) {
	subCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	rawList, err := r.docker.ListRunning(subCtx)
	if err != nil {
		return
	}

	newByCgroup := make(map[uint64]model.ContainerMeta, len(rawList))
	newByID := make(map[string]model.ContainerMeta, len(rawList))
	newByIP := make(map[string]model.ContainerMeta, len(rawList))
	newByName := make(map[string]model.ContainerMeta, len(rawList))
	snapshot := make([]model.ContainerMeta, 0, len(rawList))

	for _, rc := range rawList {
		cgID, cgPath := ResolveContainerCgroup(rc.InitPID, rc.ID)
		meta, keep := BuildContainerMeta(rc, cgID, cgPath, r.includeUnlabeled)
		if !keep {
			continue
		}
		if cgID != 0 {
			newByCgroup[cgID] = meta
		}
		newByID[rc.ID] = meta
		newByName[meta.Name] = meta
		if meta.TargetID != "" {
			newByName[meta.TargetID] = meta
		}
		for _, ip := range meta.IPs {
			newByIP[ip] = meta
		}
		snapshot = append(snapshot, meta)
	}

	r.mu.Lock()
	r.byCgroup = newByCgroup
	r.byID = newByID
	r.byIP = newByIP
	r.byName = newByName
	// Prune expired negative cache entries
	now := time.Now()
	for k, exp := range r.nonContainerCgroups {
		if now.After(exp) {
			delete(r.nonContainerCgroups, k)
		}
	}
	r.mu.Unlock()

	if r.onUpdate != nil {
		r.onUpdate(snapshot)
	}
}

// InjectContainerForTest allows unit tests and replay mode to register synthetic containers.
func (r *Resolver) InjectContainerForTest(meta model.ContainerMeta) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if meta.CgroupID != 0 {
		r.byCgroup[meta.CgroupID] = meta
	}
	if meta.ContainerID != "" {
		r.byID[meta.ContainerID] = meta
	}
	if meta.Name != "" {
		r.byName[meta.Name] = meta
	}
	if meta.TargetID != "" {
		r.byName[meta.TargetID] = meta
	}
	for _, ip := range meta.IPs {
		r.byIP[ip] = meta
	}
	if meta.PrimaryIP != "" {
		r.byIP[meta.PrimaryIP] = meta
	}
}

// Snapshot returns sorted active tracked containers.
func (r *Resolver) Snapshot() []model.ContainerMeta {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]model.ContainerMeta, 0, len(r.byID))
	seen := make(map[string]bool, len(r.byID))
	for _, c := range r.byID {
		key := c.ContainerID
		if key == "" {
			key = c.Name
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, c)
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].Name < out[j].Name
	})
	return out
}

// LookupByCgroupOrPID resolves a container by kernel cgroup_id, falling back to /proc/<pid>/cgroup
// container ID extraction + live Docker inspect for newly spawned containers.
func (r *Resolver) LookupByCgroupOrPID(cgroupID uint64, pid uint32) (model.ContainerMeta, bool) {
	r.mu.RLock()
	if cgroupID != 0 {
		if meta, ok := r.byCgroup[cgroupID]; ok {
			r.mu.RUnlock()
			return meta, true
		}
		if exp, neg := r.nonContainerCgroups[cgroupID]; neg && time.Now().Before(exp) {
			r.mu.RUnlock()
			return model.ContainerMeta{}, false
		}
	}
	r.mu.RUnlock()

	// Fallback: inspect /proc/<pid>/cgroup directly for 64-hex container ID
	containerID, _ := ExtractContainerIDFromProcCgroup(pid)
	if containerID == "" {
		if cgroupID != 0 {
			r.mu.Lock()
			r.nonContainerCgroups[cgroupID] = time.Now().Add(5 * time.Second)
			r.mu.Unlock()
		}
		return model.ContainerMeta{}, false
	}

	r.mu.RLock()
	if meta, ok := r.byID[containerID]; ok {
		r.mu.RUnlock()
		if cgroupID != 0 && meta.CgroupID == 0 {
			meta.CgroupID = cgroupID
			r.InjectContainerForTest(meta)
		}
		return meta, true
	}
	r.mu.RUnlock()

	// On-demand synchronous inspect over /var/run/docker.sock (<1.5ms)
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	rc, err := r.docker.InspectOne(ctx, containerID)
	if err != nil || rc == nil {
		return model.ContainerMeta{}, false
	}

	cgID, cgPath := ResolveContainerCgroup(rc.InitPID, rc.ID)
	if cgID == 0 {
		cgID = cgroupID
	}
	meta, keep := BuildContainerMeta(*rc, cgID, cgPath, r.includeUnlabeled)
	if !keep {
		if cgroupID != 0 {
			r.mu.Lock()
			r.nonContainerCgroups[cgroupID] = time.Now().Add(10 * time.Second)
			r.mu.Unlock()
		}
		return model.ContainerMeta{}, false
	}

	r.InjectContainerForTest(meta)
	if r.onUpdate != nil {
		r.onUpdate(r.Snapshot())
	}
	return meta, true
}

func (r *Resolver) LookupByIP(ip string) (model.ContainerMeta, bool) {
	if ip == "" {
		return model.ContainerMeta{}, false
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	m, ok := r.byIP[ip]
	return m, ok
}

// ResolveTargetInText checks cmdline for any tracked target IP or hostname, or falls back
// to the sole target container in the same match.
func (r *Resolver) ResolveTargetInText(matchID, text string) (targetID string, dstIP string) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if text != "" {
		for ip, c := range r.byIP {
			if c.Role == model.RoleTarget && strings.Contains(text, ip) {
				return c.TargetID, ip
			}
		}
		for name, c := range r.byName {
			if name != "" && c.Role == model.RoleTarget && strings.Contains(text, name) {
				return c.TargetID, c.PrimaryIP
			}
		}
	}

	// Single-target match fallback (e.g. Holy Grail War / Speedrun isolation)
	var soleTarget *model.ContainerMeta
	count := 0
	for _, c := range r.byID {
		if c.Role == model.RoleTarget && (matchID == "" || c.MatchID == matchID) {
			copyMeta := c
			soleTarget = &copyMeta
			count++
		}
	}
	if count == 1 && soleTarget != nil {
		return soleTarget.TargetID, soleTarget.PrimaryIP
	}
	return "", ""
}

func (r *Resolver) RecordAttackerTouch(targetID, seatID, srcIP string) {
	if targetID == "" || seatID == "" {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.lastAttacker[targetID] = attackerTouch{
		SeatID: seatID,
		SrcIP:  srcIP,
		SeenAt: time.Now(),
	}
}

func (r *Resolver) RecentAttackerForTarget(targetID string) (string, string) {
	if targetID == "" {
		return "", ""
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, ok := r.lastAttacker[targetID]
	if !ok || time.Since(t.SeenAt) > 45*time.Second {
		return "", ""
	}
	return t.SeatID, t.SrcIP
}
