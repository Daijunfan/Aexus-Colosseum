package model

import "sort"

// GameMode enumerates the 4 signature Pit game modes defined in SCHEMA.md.
type GameMode string

const (
	ModeAWD       GameMode = "awd"        // 攻防混战 (Classic AWD)
	ModeGrail     GameMode = "grail"      // 圣杯战争 (Holy Grail War)
	ModeSpeedrun  GameMode = "speedrun"   // 竞速夺旗 (Speedrun CTF)
	ModeLastStand GameMode = "last_stand" // 人类防线 (Humanity's Last Stand)
)

func ValidGameMode(m GameMode) bool {
	switch m {
	case ModeAWD, ModeGrail, ModeSpeedrun, ModeLastStand:
		return true
	default:
		return false
	}
}

// SeatKind enumerates gladiator seat controller types.
type SeatKind string

const (
	SeatHarness SeatKind = "harness"
	SeatHuman   SeatKind = "human"
	SeatCentaur SeatKind = "centaur"
)

// OrganLayer enumerates the 5 anatomical layers of every Target Fortress.
type OrganLayer string

const (
	OrganPortGate    OrganLayer = "port_gate"    // 端口大门
	OrganRouteVessel OrganLayer = "route_vessel" // 路由血管
	OrganCodeOrgan   OrganLayer = "code_organ"   // 源码器官
	OrganDBVault     OrganLayer = "db_vault"     // 数据库金库
	OrganFlagHeart   OrganLayer = "flag_heart"   // 圣杯心脏
)

// VFXType enumerates Linux kernel eBPF visual telemetry classifications.
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

// CameraLens enumerates AI Auto-Director camera lenses.
type CameraLens string

const (
	LensMacroArena    CameraLens = "MACRO_ARENA"
	LensXRayOrgan     CameraLens = "XRAY_ORGAN"
	LensLiveWebHijack CameraLens = "LIVE_WEB_HIJACK"
)

// EventKind enumerates real-time WebSocket stream envelope kinds.
type EventKind string

const (
	KindEBPFEvent      EventKind = "EBPF_EVENT"
	KindThoughtBubble  EventKind = "THOUGHT_BUBBLE"
	KindTokenBurn      EventKind = "TOKEN_BURN"
	KindSLAHeartbeat   EventKind = "SLA_HEARTBEAT"
	KindFlagCaptured   EventKind = "FLAG_CAPTURED"
	KindGrailClaimed   EventKind = "GRAIL_CLAIMED"
	KindPatchApplied   EventKind = "PATCH_APPLIED"
	KindManaDepleted   EventKind = "MANA_DEPLETED"
	KindKillFeed       EventKind = "KILL_FEED"
	KindCasterLine     EventKind = "CASTER_LINE"
	KindCameraCue      EventKind = "CAMERA_CUE"
	KindTerminalOutput EventKind = "TERMINAL_OUTPUT"
	KindWebHijack      EventKind = "WEB_HIJACK"
	KindMatchState     EventKind = "MATCH_STATE"
)

// EventEnvelope is the canonical real-time WebSocket & replay timeline frame.
type EventEnvelope struct {
	Seq     int64     `json:"seq"`
	TsMs    int64     `json:"ts_ms"`
	MatchID string    `json:"match_id"`
	Kind    EventKind `json:"kind"`
	Payload any       `json:"payload"`
}

// HealthResponse represents GET /api/v1/health.
type HealthResponse struct {
	OK               bool         `json:"ok"`
	Status           string       `json:"status"`
	Service          string       `json:"service"`
	Version          string       `json:"version"`
	UptimeSeconds    int64        `json:"uptime_seconds"`
	EBPFSensor       EBPFStatus   `json:"ebpf_sensor"`
	EBPF             EBPFStatus   `json:"ebpf"`
	Docker           DockerStatus `json:"docker"`
	ActiveMatchCount int          `json:"active_match_count"`
	ActiveMatches    int          `json:"active_matches"`
	TotalMatches     int          `json:"total_matches"`
	ArmoryMapsCount  int          `json:"armory_maps_count"`
	HarnessesCount   int          `json:"harnesses_count"`
}

type EBPFPerfStats struct {
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

type EBPFStatus struct {
	Mode               string         `json:"mode"` // "kernel_ebpf" | "active_bridge" | "replay_sim" | "offline"
	BTFEnabled         bool           `json:"btf_enabled"`
	KernelRelease      string         `json:"kernel_release,omitempty"`
	SSLLibrariesHooked int            `json:"ssl_libraries_hooked,omitempty"`
	TrackedContainers  int            `json:"tracked_containers,omitempty"`
	AttachedProbes     []string       `json:"attached_probes"`
	EventsCaptured     int64          `json:"events_captured"`
	LastEventTsMs      int64          `json:"last_event_ts_ms,omitempty"`
	PerfStats          *EBPFPerfStats `json:"perf_stats,omitempty"`
}

type DockerStatus struct {
	Available         bool   `json:"available"`
	Version           string `json:"version"`
	PythonSlimCached  bool   `json:"python_slim_cached"`
	AttackboxCached   bool   `json:"attackbox_cached"`
	RunningContainers int    `json:"running_containers"`
}

// Armory structures (GET /api/v1/armory)

type ArmoryCategory struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Symbol string `json:"symbol"`
	Color  string `json:"color"`
	Blurb  string `json:"blurb"`
}

type MapAccess struct {
	Label  string `json:"label"`
	Port   int    `json:"port"`
	Scheme string `json:"scheme"`
	Path   string `json:"path"`
}

type OrganSpec struct {
	Layer     OrganLayer `json:"layer"`
	Name      string     `json:"name"`
	LabelZH   string     `json:"label_zh"`
	Component string     `json:"component"`
	VulnClass string     `json:"vuln_class"`
}

type ArenaMap struct {
	ID               string      `json:"id"`
	Name             string      `json:"name"`
	Subtitle         string      `json:"subtitle,omitempty"`
	Category         string      `json:"category"`
	Source           string      `json:"source"`
	Difficulty       int         `json:"difficulty"`
	Summary          string      `json:"summary"`
	Tags             []string    `json:"tags"`
	MITRE            []string    `json:"mitre,omitempty"`
	Ports            []int       `json:"ports"`
	Access           []MapAccess `json:"access,omitempty"`
	SupportsAWDPatch bool        `json:"supports_awd_patch"`
	SupportsGrail    bool        `json:"supports_grail"`
	Featured         bool        `json:"featured"`
	Organs           []OrganSpec `json:"organs"`
}

type PipelineStage struct {
	Title  string `json:"title"`
	Detail string `json:"detail"`
	Symbol string `json:"symbol"`
}

type HarnessSpec struct {
	ID           string            `json:"id"`
	Name         string            `json:"name"`
	Developer    string            `json:"developer"`
	Repo         string            `json:"repo"`
	Stars        int               `json:"stars"`
	StarsDisplay string            `json:"stars_display"`
	Language     string            `json:"language"`
	License      string            `json:"license"`
	Mode         string            `json:"mode"`
	Tagline      string            `json:"tagline"`
	Summary      string            `json:"summary"`
	AccentColor  string            `json:"accent_color"`
	Colors       []string          `json:"colors"`
	Symbol       string            `json:"symbol"`
	Featured     bool              `json:"featured"`
	Capabilities []string          `json:"capabilities"`
	AdapterCmd   string            `json:"adapter_cmd"`
	DockerImage  string            `json:"docker_image"`
	EnvTemplate  map[string]string `json:"env_template"`
	Pipeline     []PipelineStage   `json:"pipeline,omitempty"`
}

type GameModeSpec struct {
	ID          GameMode `json:"id"`
	Name        string   `json:"name"`
	NameEN      string   `json:"name_en"`
	Tagline     string   `json:"tagline"`
	AccentColor string   `json:"accent_color"`
	Rules       []string `json:"rules"`
}

type ArmoryResponse struct {
	OK         bool             `json:"ok"`
	Categories []ArmoryCategory `json:"categories"`
	Maps       []ArenaMap       `json:"maps"`
	Harnesses  []HarnessSpec    `json:"harnesses"`
	GameModes  []GameModeSpec   `json:"game_modes"`
}

// Match creation & state structures

type UpstreamLLMConfig struct {
	BaseURL      string `json:"base_url"`
	APIKey       string `json:"api_key,omitempty"`
	DefaultModel string `json:"default_model"`
}

type SeatSpec struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Kind        SeatKind `json:"kind"`
	HarnessID   string   `json:"harness_id"`
	Model       string   `json:"model"`
	TeamColor   string   `json:"team_color"`
	Role        string   `json:"role,omitempty"` // "gladiator" | "defender" | "besieger"
	CustomImage string   `json:"custom_image,omitempty"`
	CustomCmd   string   `json:"custom_cmd,omitempty"`
}

type CreateMatchRequest struct {
	Title           string            `json:"title"`
	Mode            GameMode          `json:"mode"`
	MapID           string            `json:"map_id"`
	TokenBudget     int64             `json:"token_budget"`
	RoundSeconds    int               `json:"round_seconds"`
	MaxRounds       int               `json:"max_rounds"`
	AutoStart       *bool             `json:"auto_start,omitempty"`
	ExecutionDriver string            `json:"execution_driver"` // "auto" | "docker" | "showcase" | "sim"
	UpstreamLLM     UpstreamLLMConfig `json:"upstream_llm"`
	Seats           []SeatSpec        `json:"seats"`
}

type MatchControlRequest struct {
	Action       string `json:"action"` // "start" | "pause" | "resume" | "stop" | "next_round" | "chaos"
	ChaosType    string `json:"chaos_type,omitempty"`
	TargetSeatID string `json:"target_seat_id,omitempty"`
}

type InterveneRequest struct {
	Type    string `json:"type"` // "possess" | "terminal_input" | "hint" | "agent_log"
	Enabled *bool  `json:"enabled,omitempty"`
	Data    string `json:"data,omitempty"`
	Prompt  string `json:"prompt,omitempty"`
	Command string `json:"command,omitempty"`
	Stream  string `json:"stream,omitempty"`
	Output  string `json:"output,omitempty"`
}

type SubmitFlagRequest struct {
	SeatID    string `json:"seat_id"`
	SeatToken string `json:"seat_token"`
	Flag      string `json:"flag"`
}

type SubmitFlagResponse struct {
	OK          bool   `json:"ok"`
	Accepted    bool   `json:"accepted"`
	Duplicate   bool   `json:"duplicate,omitempty"`
	FirstBlood  bool   `json:"first_blood,omitempty"`
	GrailCrowned bool  `json:"grail_crowned,omitempty"`
	PointsDelta int    `json:"points_delta"`
	NewScore    int    `json:"new_score"`
	TargetID    string `json:"target_id,omitempty"`
	Message     string `json:"message"`
}

type OrganState struct {
	Layer            OrganLayer `json:"layer"`
	Name             string     `json:"name"`
	LabelZH          string     `json:"label_zh"`
	Component        string     `json:"component"`
	Status           string     `json:"status"` // "intact" | "probed" | "breached" | "patched"
	HP               float64    `json:"hp"`
	BreachedBySeatID string     `json:"breached_by_seat_id,omitempty"`
	PatchedBySeatID  string     `json:"patched_by_seat_id,omitempty"`
	LastVFX          VFXType    `json:"last_vfx,omitempty"`
	HitLocation      string     `json:"hit_location,omitempty"`
	ProcessTree      []string   `json:"process_tree,omitempty"`
}

type WebPreviewState struct {
	Title             string  `json:"title"`
	TargetURL         string  `json:"target_url"`
	StatusBanner      string  `json:"status_banner"`
	DefaceBanner      string  `json:"deface_banner,omitempty"`
	LastInjectedInput string  `json:"last_injected_input,omitempty"`
	DOMMutation       string  `json:"dom_mutation,omitempty"`
	HijackedBySeatID  string  `json:"hijacked_by_seat_id,omitempty"`
	HijackedByName    string  `json:"hijacked_by_name,omitempty"`
	HijackedByColor   string  `json:"hijacked_by_color,omitempty"`
	CursorX           float64 `json:"cursor_x"`
	CursorY           float64 `json:"cursor_y"`
}

type TargetCodeLine struct {
	Line int    `json:"line"`
	Code string `json:"code"`
	Tag  string `json:"tag,omitempty"` // "normal" | "vulnerable" | "patched"
}

type TargetState struct {
	ID            string           `json:"id"`
	Name          string           `json:"name"`
	OwnerSeatID   string           `json:"owner_seat_id,omitempty"`
	KingSeatID    string           `json:"king_seat_id,omitempty"`
	Address       string           `json:"address"`
	HostPort      int              `json:"host_port,omitempty"`
	ContainerPort int              `json:"container_port"`
	ContainerID   string           `json:"container_id,omitempty"`
	ContainerIP   string           `json:"container_ip,omitempty"`
	Healthy       bool             `json:"healthy"`
	Flatlined     bool             `json:"flatlined"`
	WAFDropped    bool             `json:"waf_dropped,omitempty"`
	SLAScore      float64          `json:"sla_score"`
	LatencyMs     int              `json:"latency_ms"`
	LastSLADetail string           `json:"last_sla_detail"`
	ECGSamples    []float64        `json:"ecg_samples"`
	Organs        []OrganState     `json:"organs"`
	CompromisedBy []string         `json:"compromised_by"`
	PatchCount    int              `json:"patch_count"`
	LastDiff      string           `json:"last_diff,omitempty"`
	CodeFile      string           `json:"code_file,omitempty"`
	CodeExcerpt   []TargetCodeLine `json:"code_excerpt,omitempty"`
	WebState      WebPreviewState  `json:"web_state"`
}

type SeatState struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	Kind             SeatKind `json:"kind"`
	HarnessID        string   `json:"harness_id"`
	Model            string   `json:"model"`
	TeamColor        string   `json:"team_color"`
	Role             string   `json:"role"`
	Rank             int      `json:"rank"`
	Score            int      `json:"score"`
	AttackScore      int      `json:"attack_score"`
	DefenseScore     int      `json:"defense_score"`
	SLAScore         float64  `json:"sla_score"`
	SLAHealthy       bool     `json:"sla_healthy"`
	TokensUsed       int64    `json:"tokens_used"`
	PromptTokens     int64    `json:"prompt_tokens"`
	CompletionTokens int64    `json:"completion_tokens"`
	ReasoningTokens  int64    `json:"reasoning_tokens"`
	LLMCalls         int      `json:"llm_calls"`
	TokenBudget      int64    `json:"token_budget"`
	ManaRemainingPct float64  `json:"mana_remaining_pct"`
	ManaExhausted    bool     `json:"mana_exhausted"`
	Possessed        bool     `json:"possessed"`
	Status           string   `json:"status"` // "ready" | "fighting" | "patching" | "possessed" | "out_of_mana" | "flatlined"
	FlagsCaptured    int      `json:"flags_captured"`
	FirstBloodCount  int      `json:"first_blood_count"`
	PatchesVerified  int      `json:"patches_verified"`
	GrailSeconds     int      `json:"grail_seconds"`
	CurrentAction    string   `json:"current_action"`
	LastThought      string   `json:"last_thought"`
	Hints            []string `json:"hints"`
	SeatToken        string   `json:"seat_token,omitempty"`
	ContainerID      string   `json:"container_id,omitempty"`
	ContainerIP      string   `json:"container_ip,omitempty"`
}

type SeatRankEntry struct {
	Rank             int      `json:"rank"`
	SeatID           string   `json:"seat_id"`
	Name             string   `json:"name"`
	Kind             SeatKind `json:"kind"`
	HarnessID        string   `json:"harness_id"`
	Model            string   `json:"model"`
	TeamColor        string   `json:"team_color"`
	Score            int      `json:"score"`
	TokensUsed       int64    `json:"tokens_used"`
	ManaRemainingPct float64  `json:"mana_remaining_pct"`
	ManaExhausted    bool     `json:"mana_exhausted"`
	FlagsCaptured    int      `json:"flags_captured"`
	FirstBloodCount  int      `json:"first_blood_count"`
	PatchesVerified  int      `json:"patches_verified"`
	GrailSeconds     int      `json:"grail_seconds"`
}

type MatchSummary struct {
	ID              string          `json:"id"`
	Title           string          `json:"title"`
	Mode            GameMode        `json:"mode"`
	MapID           string          `json:"map_id"`
	MapName         string          `json:"map_name"`
	Status          string          `json:"status"`
	ExecutionDriver string          `json:"execution_driver"`
	Round           int             `json:"round"`
	MaxRounds       int             `json:"max_rounds"`
	ElapsedSec      int             `json:"elapsed_sec"`
	EventsCount     int             `json:"events_count"`
	TokenBudget     int64           `json:"token_budget"`
	SeatCount       int             `json:"seat_count"`
	KingSeatID      string          `json:"king_seat_id,omitempty"`
	WinnerSeatID    string          `json:"winner_seat_id,omitempty"`
	CreatedAt       string          `json:"created_at"`
	StartedAt       string          `json:"started_at,omitempty"`
	EndedAt         string          `json:"ended_at,omitempty"`
	Leaderboard     []SeatRankEntry `json:"leaderboard"`
}

type MatchState struct {
	OK                bool             `json:"ok"`
	ID                string           `json:"id"`
	Title             string           `json:"title"`
	Mode              GameMode         `json:"mode"`
	MapID             string           `json:"map_id"`
	MapName           string           `json:"map_name"`
	Status            string           `json:"status"`
	ExecutionDriver   string           `json:"execution_driver"`
	Round             int              `json:"round"`
	Wave              int              `json:"wave"`
	MaxRounds         int              `json:"max_rounds"`
	RoundSeconds      int              `json:"round_seconds"`
	RoundRemainingSec int              `json:"round_remaining_sec"`
	ElapsedSec        int              `json:"elapsed_sec"`
	TokenBudget       int64            `json:"token_budget"`
	KingSeatID        string           `json:"king_seat_id,omitempty"`
	KingHoldSeconds   int              `json:"king_hold_seconds"`
	FirstBloodSeatID  string           `json:"first_blood_seat_id,omitempty"`
	WinnerSeatID      string           `json:"winner_seat_id,omitempty"`
	CreatedAt         string           `json:"created_at"`
	StartedAt         string           `json:"started_at,omitempty"`
	EndedAt           string           `json:"ended_at,omitempty"`
	Seats             []SeatState      `json:"seats"`
	Targets           []TargetState    `json:"targets"`
	CameraCue         CameraCuePayload `json:"camera_cue"`
	Events            []EventEnvelope  `json:"events"`
	KillFeed          []KillFeedItem   `json:"kill_feed"`
	CasterLines       []CasterLineItem `json:"caster_lines"`
	Leaderboard       []SeatRankEntry  `json:"leaderboard"`
}

// Event Payloads matching SCHEMA.md Section 4

type EBPFEventPayload struct {
	MatchID          string     `json:"match_id,omitempty"`
	Probe            string     `json:"probe"`
	VFXType          VFXType    `json:"vfx_type"`
	SourceSeatID     string     `json:"source_seat_id"`
	TargetID         string     `json:"target_id"`
	OrganLayer       OrganLayer `json:"organ_layer"`
	CgroupID         uint64     `json:"cgroup_id"`
	ContainerID      string     `json:"container_id,omitempty"`
	PID              int        `json:"pid"`
	PPID             int        `json:"ppid"`
	UID              int        `json:"uid"`
	Comm             string     `json:"comm"`
	ParentComm       string     `json:"parent_comm"`
	Cmdline          string     `json:"cmdline"`
	Filename         string     `json:"filename,omitempty"`
	SrcIP            string     `json:"src_ip"`
	DstIP            string     `json:"dst_ip"`
	DstPort          int        `json:"dst_port"`
	CleartextPayload string     `json:"cleartext_payload,omitempty"`
	ProcessTree      []string   `json:"process_tree,omitempty"`
	HitLocation      string     `json:"hit_location,omitempty"`
	KernelVerified   bool       `json:"kernel_verified,omitempty"`
	KernelTsNs       uint64     `json:"kernel_ts_ns,omitempty"`
	KernelLatencyNs  uint64     `json:"kernel_latency_ns,omitempty"`
}

type ThoughtBubblePayload struct {
	SeatID    string `json:"seat_id"`
	SeatName  string `json:"seat_name"`
	HarnessID string `json:"harness_id"`
	Model     string `json:"model"`
	Stage     string `json:"stage"`
	Thought   string `json:"thought"`
	ToolCall  string `json:"tool_call,omitempty"`
}

type TokenBurnPayload struct {
	SeatID           string  `json:"seat_id"`
	SeatName         string  `json:"seat_name"`
	Model            string  `json:"model"`
	DeltaTokens      int64   `json:"delta_tokens"`
	PromptTokens     int64   `json:"prompt_tokens"`
	CompletionTokens int64   `json:"completion_tokens"`
	ReasoningTokens  int64   `json:"reasoning_tokens"`
	TokensUsed       int64   `json:"tokens_used"`
	TokenBudget      int64   `json:"token_budget"`
	ManaRemainingPct float64 `json:"mana_remaining_pct"`
}

type SLAHeartbeatPayload struct {
	TargetID    string    `json:"target_id"`
	OwnerSeatID string    `json:"owner_seat_id,omitempty"`
	Healthy     bool      `json:"healthy"`
	Flatlined   bool      `json:"flatlined"`
	SLAScore    float64   `json:"sla_score"`
	LatencyMs   int       `json:"latency_ms"`
	CheckName   string    `json:"check_name"`
	Detail      string    `json:"detail"`
	PointsDelta int       `json:"points_delta"`
	ECGSamples  []float64 `json:"ecg_samples"`
}

type FlagCapturedPayload struct {
	SeatID       string `json:"seat_id"`
	SeatName     string `json:"seat_name"`
	VictimSeatID string `json:"victim_seat_id,omitempty"`
	TargetID     string `json:"target_id"`
	Round        int    `json:"round"`
	FirstBlood   bool   `json:"first_blood"`
	PointsEarned int    `json:"points_earned"`
	VictimLoss   int    `json:"victim_loss,omitempty"`
}

type GrailClaimedPayload struct {
	KingSeatID     string `json:"king_seat_id"`
	KingName       string `json:"king_name"`
	KingColor      string `json:"king_color"`
	PreviousKingID string `json:"previous_king_id,omitempty"`
	TargetID       string `json:"target_id"`
	Method         string `json:"method"` // "flag_submit" | "king_beacon"
	PointsDelta    int    `json:"points_delta"`
}

type PatchAppliedPayload struct {
	SeatID      string `json:"seat_id"`
	SeatName    string `json:"seat_name"`
	TargetID    string `json:"target_id"`
	FilePath    string `json:"file_path"`
	CommitSHA   string `json:"commit_sha"`
	Verified    bool   `json:"verified"`
	PointsDelta int    `json:"points_delta"`
	SLADetail   string `json:"sla_detail,omitempty"`
	Diff        string `json:"diff"`
}

type ManaDepletedPayload struct {
	SeatID      string `json:"seat_id"`
	SeatName    string `json:"seat_name"`
	HarnessID   string `json:"harness_id"`
	TokensUsed  int64  `json:"tokens_used"`
	TokenBudget int64  `json:"token_budget"`
	HTTPStatus  int    `json:"http_status"`
}

type KillFeedItem struct {
	ID           string `json:"id"`
	TsMs         int64  `json:"ts_ms"`
	Category     string `json:"category"` // "FIRST_BLOOD" | "BREACH" | "PATCH" | "GRAIL" | "FLATLINE" | "OUT_OF_MANA" | "POSSESS" | "CHAOS"
	ActorSeatID  string `json:"actor_seat_id,omitempty"`
	ActorName    string `json:"actor_name"`
	ActorColor   string `json:"actor_color"`
	VictimSeatID string `json:"victim_seat_id,omitempty"`
	VictimName   string `json:"victim_name,omitempty"`
	TargetID     string `json:"target_id,omitempty"`
	Weapon       string `json:"weapon"`
	Headline     string `json:"headline"`
	PointsDelta  int    `json:"points_delta,omitempty"`
}

type CasterLineItem struct {
	ID       string `json:"id"`
	TsMs     int64  `json:"ts_ms"`
	Tone     string `json:"tone"` // "HYPE" | "CRITICAL" | "SAVAGE" | "TACTICAL"
	Speaker  string `json:"speaker"`
	Text     string `json:"text"`
	SeatID   string `json:"seat_id,omitempty"`
	TargetID string `json:"target_id,omitempty"`
}

type CameraCuePayload struct {
	Lens          CameraLens `json:"lens"`
	FocusTargetID string     `json:"focus_target_id,omitempty"`
	FocusSeatID   string     `json:"focus_seat_id,omitempty"`
	Reason        string     `json:"reason"`
	HoldMs        int        `json:"hold_ms"`
	TsMs          int64      `json:"ts_ms"`
}

type TerminalOutputPayload struct {
	SeatID   string `json:"seat_id"`
	SeatName string `json:"seat_name"`
	Command  string `json:"command,omitempty"`
	Stream   string `json:"stream"` // "stdout" | "stderr" | "system"
	Output   string `json:"output"`
	ExitCode int    `json:"exit_code"`
}

type WebHijackPayload struct {
	TargetID       string  `json:"target_id"`
	AttackerSeatID string  `json:"attacker_seat_id"`
	AttackerName   string  `json:"attacker_name"`
	AttackerColor  string  `json:"attacker_color"`
	CursorX        float64 `json:"cursor_x"`
	CursorY        float64 `json:"cursor_y"`
	TargetURL      string  `json:"target_url"`
	InjectedInput  string  `json:"injected_input"`
	DOMMutation    string  `json:"dom_mutation"`
	DefaceBanner   string  `json:"deface_banner"`
}

// Global Leaderboard (GET /api/v1/leaderboard)

type GlobalLeaderboardEntry struct {
	Rank              int      `json:"rank"`
	ID                string   `json:"id"`
	Name              string   `json:"name"`
	Kind              SeatKind `json:"kind"`
	HarnessID         string   `json:"harness_id"`
	Developer         string   `json:"developer"`
	DefaultModel      string   `json:"default_model"`
	AccentColor       string   `json:"accent_color"`
	MatchesPlayed     int      `json:"matches_played"`
	Wins              int      `json:"wins"`
	WinRate           float64  `json:"win_rate"`
	TotalScore        int      `json:"total_score"`
	FlagsCaptured     int      `json:"flags_captured"`
	FirstBloodCount   int      `json:"first_blood_count"`
	PatchesVerified   int      `json:"patches_verified"`
	TotalTokensUsed   int64    `json:"total_tokens_used"`
	AvgTokensPerSolve int64    `json:"avg_tokens_per_solve"`
}

type GlobalLeaderboardResponse struct {
	OK             bool                     `json:"ok"`
	TieBreakerRule string                   `json:"tie_breaker_rule"`
	Leaderboard    []GlobalLeaderboardEntry `json:"leaderboard"`
	Entries        []GlobalLeaderboardEntry `json:"entries"`
}

type ReplayBundle struct {
	OK          bool            `json:"ok"`
	Format      string          `json:"format"`
	Version     string          `json:"version"`
	ExportedAt  string          `json:"exported_at"`
	Match       MatchState      `json:"match"`
	Timeline    []EventEnvelope `json:"timeline"`
	Leaderboard []SeatRankEntry `json:"leaderboard"`
}

// SortSeatLeaderboard enforces The Pit's ironclad tie-breaker rule:
// 1. Score DESC
// 2. TokensUsed ASC (equal score -> fewer Tokens burned wins!)
// 3. FirstBloodCount DESC
// 4. SeatID ASC
func SortSeatLeaderboard(entries []SeatRankEntry) {
	sort.SliceStable(entries, func(i, j int) bool {
		if entries[i].Score != entries[j].Score {
			return entries[i].Score > entries[j].Score
		}
		if entries[i].TokensUsed != entries[j].TokensUsed {
			return entries[i].TokensUsed < entries[j].TokensUsed
		}
		if entries[i].FirstBloodCount != entries[j].FirstBloodCount {
			return entries[i].FirstBloodCount > entries[j].FirstBloodCount
		}
		return entries[i].SeatID < entries[j].SeatID
	})
	for idx := range entries {
		entries[idx].Rank = idx + 1
	}
}

// SortGlobalLeaderboard enforces The Pit's global tie-breaker rule:
// 1. TotalScore DESC
// 2. AvgTokensPerSolve ASC (fewer tokens per solve wins ties!)
// 3. TotalTokensUsed ASC
// 4. FirstBloodCount DESC
func SortGlobalLeaderboard(entries []GlobalLeaderboardEntry) {
	sort.SliceStable(entries, func(i, j int) bool {
		if entries[i].TotalScore != entries[j].TotalScore {
			return entries[i].TotalScore > entries[j].TotalScore
		}
		if entries[i].AvgTokensPerSolve != entries[j].AvgTokensPerSolve {
			return entries[i].AvgTokensPerSolve < entries[j].AvgTokensPerSolve
		}
		if entries[i].TotalTokensUsed != entries[j].TotalTokensUsed {
			return entries[i].TotalTokensUsed < entries[j].TotalTokensUsed
		}
		if entries[i].FirstBloodCount != entries[j].FirstBloodCount {
			return entries[i].FirstBloodCount > entries[j].FirstBloodCount
		}
		return entries[i].ID < entries[j].ID
	})
	for idx := range entries {
		entries[idx].Rank = idx + 1
	}
}
