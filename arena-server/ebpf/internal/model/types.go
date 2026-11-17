package model

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"net"
	"strings"
)

// VFXType enumerates canonical Aexus Colosseum eBPF VFX event types (SCHEMA.md §1.4).
type VFXType string

const (
	VFXSonarSweep            VFXType = "SONAR_SWEEP"
	VFXArmorPiercingBarrage  VFXType = "ARMOR_PIERCING_BARRAGE"
	VFXPrecisionExploitBeam  VFXType = "PRECISION_EXPLOIT_BEAM"
	VFXRCEParasiteBreach     VFXType = "RCE_PARASITE_BREACH"
	VFXReverseShellChain     VFXType = "REVERSE_SHELL_CHAIN"
	VFXGrailHeartStolen      VFXType = "GRAIL_HEART_STOLEN"
	VFXNanoPatchWeld         VFXType = "NANO_PATCH_WELD"
	VFXRootShockwave         VFXType = "ROOT_SHOCKWAVE"
	VFXSSLCleartextIntercept VFXType = "SSL_CLEARTEXT_INTERCEPT"
)

// OrganLayer enumerates target organ anatomy layers (SCHEMA.md §1.3).
type OrganLayer string

const (
	OrganPortGate    OrganLayer = "port_gate"
	OrganRouteVessel OrganLayer = "route_vessel"
	OrganCodeOrgan   OrganLayer = "code_organ"
	OrganDBVault     OrganLayer = "db_vault"
	OrganFlagHeart   OrganLayer = "flag_heart"
)

// ContainerRole identifies whether a Docker container is a fighter seat or a target fortress.
type ContainerRole string

const (
	RoleFighter ContainerRole = "fighter"
	RoleTarget  ContainerRole = "target"
	RoleUnknown ContainerRole = ""
)

// Kernel raw event type IDs matching bpf/probes.bpf.c.
const (
	RawEventExecve   uint8 = 1
	RawEventConnect  uint8 = 2
	RawEventOpenat   uint8 = 3
	RawEventPrivesc  uint8 = 4
	RawEventSSLWrite uint8 = 5
	RawEventSSLRead  uint8 = 6
)

// Privesc sub-types matching bpf/probes.bpf.c.
const (
	PrivescSetuid     uint8 = 1
	PrivescSetresuid  uint8 = 2
	PrivescCommitCred uint8 = 3
)

// Linux openat flags (x86_64).
const (
	O_RDONLY uint32 = 0x0
	O_WRONLY uint32 = 0x1
	O_RDWR   uint32 = 0x2
	O_CREAT  uint32 = 0x40
	O_TRUNC  uint32 = 0x200
	O_APPEND uint32 = 0x400
)

// RawEventByteSize is sizeof(struct pit_raw_event) in bpf/probes.bpf.c.
const RawEventByteSize = 1184

// LegacyRawEventByteSize supports older 1176-byte samples if replayed from disk.
const LegacyRawEventByteSize = 1176

// RawKernelEvent is the decoded userspace representation of struct pit_raw_event.
type RawKernelEvent struct {
	TimestampNs uint64
	DurationNs  uint64
	CgroupID    uint64
	PID         uint32
	TID         uint32
	UID         uint32
	PPID        uint32
	TargetUID   uint32
	Flags       uint32
	DFD         int32
	DstIP       string
	DstPort     uint16
	PayloadLen  uint16
	EventType   uint8
	SubType     uint8
	ArgCount    uint8
	Comm        string
	ParentComm  string
	Filename    string
	Args        []string
	Payload     []byte
}

// DecodeRawKernelEvent decodes a 1184-byte struct pit_raw_event emitted by BPF ringbuf.
func DecodeRawKernelEvent(b []byte) (RawKernelEvent, error) {
	if len(b) < LegacyRawEventByteSize {
		return RawKernelEvent{}, fmt.Errorf("short raw event buffer: got %d bytes, want >= %d", len(b), LegacyRawEventByteSize)
	}

	le := binary.LittleEndian
	ev := RawKernelEvent{
		TimestampNs: le.Uint64(b[0:8]),
		CgroupID:    le.Uint64(b[8:16]),
		PID:         le.Uint32(b[16:20]),
		TID:         le.Uint32(b[20:24]),
		UID:         le.Uint32(b[24:28]),
		PPID:        le.Uint32(b[28:32]),
		TargetUID:   le.Uint32(b[32:36]),
		Flags:       le.Uint32(b[36:40]),
		DFD:         int32(le.Uint32(b[40:44])),
		DstPort:     le.Uint16(b[48:50]),
		PayloadLen:  le.Uint16(b[50:52]),
		EventType:   b[52],
		SubType:     b[53],
		ArgCount:    b[54],
		Comm:        cString(b[56:72]),
		ParentComm:  cString(b[72:88]),
		Filename:    cString(b[88:280]),
	}
	if len(b) >= RawEventByteSize {
		ev.DurationNs = le.Uint64(b[1176:1184])
	}

	rawIP := b[44:48]
	if rawIP[0] != 0 || rawIP[1] != 0 || rawIP[2] != 0 || rawIP[3] != 0 {
		ev.DstIP = net.IPv4(rawIP[0], rawIP[1], rawIP[2], rawIP[3]).String()
	}

	argSlices := [][]byte{
		b[280:344],
		b[344:408],
		b[408:536],
		b[536:664],
	}
	maxArgs := int(ev.ArgCount)
	if maxArgs > len(argSlices) {
		maxArgs = len(argSlices)
	}
	for i := 0; i < maxArgs; i++ {
		s := cString(argSlices[i])
		if s != "" || i == 0 {
			ev.Args = append(ev.Args, s)
		}
	}

	if ev.PayloadLen > 0 {
		n := int(ev.PayloadLen)
		if n > 512 {
			n = 512
		}
		ev.Payload = make([]byte, n)
		copy(ev.Payload, b[664:664+n])
	}

	return ev, nil
}

// Cmdline reconstructs a readable command line from Args and Filename.
func (r RawKernelEvent) Cmdline() string {
	if len(r.Args) > 0 {
		parts := make([]string, 0, len(r.Args))
		for _, a := range r.Args {
			if a != "" {
				parts = append(parts, a)
			}
		}
		if len(parts) > 0 {
			if r.Filename != "" && parts[0] != r.Filename && !strings.HasSuffix(r.Filename, "/"+parts[0]) {
				return r.Filename + " " + strings.Join(parts[1:], " ")
			}
			if r.Filename != "" && !strings.Contains(parts[0], "/") {
				parts[0] = r.Filename
			}
			return strings.Join(parts, " ")
		}
	}
	return r.Filename
}

// ProbeName returns the canonical probe identifier for telemetry reporting.
func (r RawKernelEvent) ProbeName() string {
	switch r.EventType {
	case RawEventExecve:
		return "sys_enter_execve"
	case RawEventConnect:
		return "sys_enter_connect"
	case RawEventOpenat:
		return "sys_enter_openat"
	case RawEventPrivesc:
		switch r.SubType {
		case PrivescSetuid:
			return "sys_enter_setuid"
		case PrivescSetresuid:
			return "sys_enter_setresuid"
		case PrivescCommitCred:
			return "commit_creds"
		default:
			return "sys_enter_setuid"
		}
	case RawEventSSLWrite:
		return "uprobe/SSL_write"
	case RawEventSSLRead:
		return "uprobe/SSL_read"
	default:
		return "unknown"
	}
}

func cString(b []byte) string {
	if idx := bytes.IndexByte(b, 0); idx >= 0 {
		return string(b[:idx])
	}
	return string(b)
}

// ContainerMeta holds resolved Docker container metadata indexed by cgroup_id and IPv4.
type ContainerMeta struct {
	ContainerID string            `json:"container_id"`
	ShortID     string            `json:"short_id"`
	Name        string            `json:"name"`
	Image       string            `json:"image,omitempty"`
	InitPID     int               `json:"init_pid"`
	CgroupID    uint64            `json:"cgroup_id"`
	CgroupPath  string            `json:"cgroup_path,omitempty"`
	PrimaryIP   string            `json:"primary_ip,omitempty"`
	IPs         []string          `json:"ips,omitempty"`
	MatchID     string            `json:"match_id,omitempty"`
	SeatID      string            `json:"seat_id,omitempty"`
	TargetID    string            `json:"target_id,omitempty"`
	Role        ContainerRole     `json:"role"`
	Labels      map[string]string `json:"labels,omitempty"`
}

// EBPFEventPayload strictly follows SCHEMA.md §4 EBPF_EVENT payload contract.
type EBPFEventPayload struct {
	Probe            string     `json:"probe"`
	VFXType          VFXType    `json:"vfx_type"`
	SourceSeatID     string     `json:"source_seat_id"`
	TargetID         string     `json:"target_id"`
	OrganLayer       OrganLayer `json:"organ_layer"`
	CgroupID         uint64     `json:"cgroup_id"`
	PID              uint32     `json:"pid"`
	PPID             uint32     `json:"ppid"`
	UID              uint32     `json:"uid"`
	Comm             string     `json:"comm"`
	ParentComm       string     `json:"parent_comm"`
	Cmdline          string     `json:"cmdline"`
	Filename         string     `json:"filename,omitempty"`
	Flags            uint32     `json:"flags,omitempty"`
	SrcIP            string     `json:"src_ip"`
	DstIP            string     `json:"dst_ip"`
	DstPort          uint16     `json:"dst_port"`
	CleartextPayload string     `json:"cleartext_payload"`
	ProcessTree      []string   `json:"process_tree"`
	HitLocation      string     `json:"hit_location"`
	KernelTsNs       uint64     `json:"kernel_ts_ns,omitempty"`
	KernelLatencyNs  uint64     `json:"kernel_latency_ns,omitempty"`
}

// EventEnvelope wraps EBPFEventPayload with sequence/timestamp/match metadata while also
// exposing top-level payload fields for direct JSON line consumers.
type EventEnvelope struct {
	Seq           uint64        `json:"seq"`
	TsMs          int64         `json:"ts_ms"`
	MatchID       string        `json:"match_id"`
	Kind          string        `json:"kind"`
	ContainerID   string        `json:"container_id,omitempty"`
	ContainerName string        `json:"container_name,omitempty"`
	ContainerRole ContainerRole `json:"container_role,omitempty"`
	EBPFEventPayload
	Payload EBPFEventPayload `json:"payload"`
}

// KernelPerfStats exposes live zero-lock BPF_MAP_TYPE_PERCPU_ARRAY kernel telemetry.
type KernelPerfStats struct {
	CPUCores             int     `json:"cpu_cores"`
	RingbufCapacityBytes uint64  `json:"ringbuf_capacity_bytes"`
	SyscallsEntered      uint64  `json:"syscalls_entered"`
	FilteredInKernel     uint64  `json:"filtered_in_kernel"`
	RingbufSubmitted     uint64  `json:"ringbuf_submitted"`
	RingbufDrops         uint64  `json:"ringbuf_drops"`
	ExecveSubmitted      uint64  `json:"execve_submitted"`
	ConnectSubmitted     uint64  `json:"connect_submitted"`
	OpenatSubmitted      uint64  `json:"openat_submitted"`
	SecuritySubmitted    uint64  `json:"security_submitted"`
	KernelFilterPct      float64 `json:"kernel_filter_pct"`
	SyscallsPerSec       float64 `json:"syscalls_per_sec"`
	EventsPerSec         float64 `json:"events_per_sec"`
}

// SensorStatus reports health, attached kernel probes, and metrics on GET /status & /health.
type SensorStatus struct {
	OK                 bool              `json:"ok"`
	Service            string            `json:"service"`
	Mode               string            `json:"mode"`
	BTFEnabled         bool              `json:"btf_enabled"`
	KernelRelease      string            `json:"kernel_release,omitempty"`
	AttachedProbes     []string          `json:"attached_probes"`
	SSLLibrariesHooked int               `json:"ssl_libraries_hooked"`
	TrackedContainers  int               `json:"tracked_containers"`
	Containers         []ContainerMeta   `json:"containers"`
	EventsCaptured     uint64            `json:"events_captured"`
	EventsByVFX        map[string]uint64 `json:"events_by_vfx"`
	EventsShipped      uint64            `json:"events_shipped"`
	ShipErrors         uint64            `json:"ship_errors"`
	UptimeMs           int64             `json:"uptime_ms"`
	PerfStats          *KernelPerfStats  `json:"perf_stats,omitempty"`
}
