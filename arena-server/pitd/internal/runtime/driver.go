package runtime

import (
	"context"

	"aexus.io/pitd/internal/model"
)

// MatchLaunchSpec describes everything the runtime driver needs to launch a match.
type MatchLaunchSpec struct {
	MatchID         string
	Mode            model.GameMode
	MapID           string
	ExecutionDriver string // "auto" | "docker" | "showcase" | "sim"
	GatewayPort     int
	GatewayHost     string
	UpstreamKeySet  bool
	Seats           []SeatLaunchSpec
	Targets         []TargetLaunchSpec
	InitialFlags    map[string]string // targetID -> flag
}

type SeatLaunchSpec struct {
	ID          string
	Name        string
	Kind        model.SeatKind
	HarnessID   string
	Model       string
	Role        string
	SeatToken   string
	TokenBudget int64
	DefendsID   string // targetID whose /app is mounted at /workspace/defense (if any)
	CustomImage string
	CustomCmd   string
	ClumsyOnce  bool
}

type TargetLaunchSpec struct {
	ID          string
	Name        string
	OwnerSeatID string
	Port        int
}

// Callbacks connects runtime events back into engine.Manager without circular imports.
type Callbacks interface {
	OnContainerReady(matchID, role, entityID, containerID, containerIP string, hostPort int)
	OnSLAHeartbeat(matchID, targetID string, res SLACheckResult)
	OnPatchDetected(matchID, targetID, seatID, filePath, commitSHA, diff string, res SLACheckResult)
	OnKingBeacon(matchID, targetID, beacon string)
	OnBridgeEBPF(matchID string, ev model.EBPFEventPayload)
	OnSimGatewayTurn(seatToken, stage, prompt string) (alive bool, thought string)
	OnSimStealFlag(matchID, seatID, targetID string)
	IsExternalEBPFActive() bool
}

// Driver abstracts Docker container orchestration and pure-Go simulation fallback.
type Driver interface {
	DockerStatus() model.DockerStatus
	StartMatch(spec MatchLaunchSpec) (resolvedDriver string, err error)
	PauseMatch(matchID string)
	ResumeMatch(matchID string)
	StopMatch(matchID string)
	RotateFlags(matchID string, flags map[string]string)
	SetPossessed(matchID, seatID string, enabled bool)
	AppendHint(matchID, seatID, hint string)
	ExecTerminal(ctx context.Context, matchID, seatID, command string) (output string, exitCode int, err error)
	ReadTargetCodeExcerpt(matchID, targetID string) []model.TargetCodeLine
	ApplyChaos(matchID, chaosType, targetSeatID string) string
	Shutdown()
}
