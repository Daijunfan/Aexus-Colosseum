package engine

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"aexus.io/pitd/internal/armory"
	"aexus.io/pitd/internal/model"
	"aexus.io/pitd/internal/runtime"
	"aexus.io/pitd/internal/ws"
)

var (
	ErrMatchNotFound = errors.New("match not found")
	ErrSeatNotFound  = errors.New("seat not found")
	ErrInvalidToken  = errors.New("invalid seat token")
	ErrOutOfMana     = errors.New("PIT_OUT_OF_MANA: Token Mana pool exhausted")
)

type seatTokenRef struct {
	MatchID string
	SeatID  string
}

type managedMatch struct {
	mu                sync.Mutex
	state             model.MatchState
	upstream          model.UpstreamLLMConfig
	timeline          []model.EventEnvelope // full recorded timeline for .pitreplay
	seq               int64
	flagSecret        string
	activeFlags       map[string]string          // targetID -> current round flag
	capturedThisRound map[string]map[string]bool // targetID -> seatID -> captured
	patchedThisRound  map[string]bool            // targetID -> verified patch rewarded this round
	cancelLoop        context.CancelFunc
}

// Manager is the central Pit Arena referee, match state machine, eBPF correlator, and AI Auto-Director.
type Manager struct {
	mu                 sync.RWMutex
	startedAt          time.Time
	gatewayPort        int
	gatewayHost        string
	armory             *armory.Registry
	hub                *ws.Hub
	driver             runtime.Driver
	matches            map[string]*managedMatch
	matchOrder         []string
	tokenIndex         map[string]seatTokenRef
	ledgerPath         string
	persistMu          sync.Mutex
	ebpfEventsCaptured atomic.Int64
	lastExternalEBPFTs atomic.Int64
	ebpfProbes         []string
	btfKernelAvailable bool
	sensorHTTP         *http.Client
	sensorStatusURL    string
}

func NewManager(arm *armory.Registry, hub *ws.Hub, driver runtime.Driver, gatewayPort int, gatewayHost string) *Manager {
	if gatewayPort <= 0 {
		gatewayPort = 18880
	}
	_, btfErr := os.Stat("/sys/kernel/btf/vmlinux")
	sensorURL := strings.TrimSpace(os.Getenv("PIT_EBPF_SENSOR_STATUS_URL"))
	if sensorURL == "" {
		sensorURL = "http://127.0.0.1:18882/status"
	}
	m := &Manager{
		startedAt:          time.Now(),
		gatewayPort:        gatewayPort,
		gatewayHost:        gatewayHost,
		armory:             arm,
		hub:                hub,
		driver:             driver,
		matches:            make(map[string]*managedMatch),
		tokenIndex:         make(map[string]seatTokenRef),
		btfKernelAvailable: btfErr == nil,
		sensorHTTP:         &http.Client{Timeout: 250 * time.Millisecond},
		sensorStatusURL:    sensorURL,
		ebpfProbes:         []string{},
	}
	return m
}

func (m *Manager) SetDriver(d runtime.Driver) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.driver = d
}

// Health returns GET /api/v1/health snapshot.
func (m *Manager) Health() model.HealthResponse {
	m.mu.RLock()
	total := len(m.matches)
	active := 0
	for _, mm := range m.matches {
		mm.mu.Lock()
		if mm.state.Status == "running" || mm.state.Status == "paused" {
			active++
		}
		mm.mu.Unlock()
	}
	drv := m.driver
	m.mu.RUnlock()

	var dStatus model.DockerStatus
	if drv != nil {
		dStatus = drv.DockerStatus()
	}

	lastExt := m.lastExternalEBPFTs.Load()
	ebpfMode := "offline"
	if lastExt > 0 && time.Now().UnixMilli()-lastExt < 30000 {
		ebpfMode = "kernel_ebpf"
	} else if m.btfKernelAvailable {
		ebpfMode = "kernel_ebpf"
	}

	probes := append([]string(nil), m.ebpfProbes...)
	btfEnabled := m.btfKernelAvailable
	captured := m.ebpfEventsCaptured.Load()
	var kernelRelease string
	var sslLibs int
	var trackedContainers int
	var perfStats *model.EBPFPerfStats

	// Live-probe local pit-ebpf-sensor daemon if running on host
	if m.sensorHTTP != nil && m.sensorStatusURL != "" {
		if resp, err := m.sensorHTTP.Get(m.sensorStatusURL); err == nil {
			var live struct {
				OK                 bool                 `json:"ok"`
				Mode               string               `json:"mode"`
				BTFEnabled         bool                 `json:"btf_enabled"`
				KernelRelease      string               `json:"kernel_release"`
				SSLLibrariesHooked int                  `json:"ssl_libraries_hooked"`
				TrackedContainers  int                  `json:"tracked_containers"`
				AttachedProbes     []string             `json:"attached_probes"`
				EventsCaptured     int64                `json:"events_captured"`
				PerfStats          *model.EBPFPerfStats `json:"perf_stats"`
			}
			if json.NewDecoder(resp.Body).Decode(&live) == nil && live.OK {
				if live.Mode != "" {
					ebpfMode = live.Mode
				}
				btfEnabled = live.BTFEnabled || btfEnabled
				kernelRelease = live.KernelRelease
				sslLibs = live.SSLLibrariesHooked
				trackedContainers = live.TrackedContainers
				if live.AttachedProbes != nil {
					probes = live.AttachedProbes
				}
				if live.EventsCaptured > captured {
					captured = live.EventsCaptured
				}
				if live.PerfStats != nil {
					perfStats = live.PerfStats
				}
			}
			_ = resp.Body.Close()
		}
	}
	if probes == nil {
		probes = []string{}
	}

	ebpf := model.EBPFStatus{
		Mode:               ebpfMode,
		BTFEnabled:         btfEnabled,
		KernelRelease:      kernelRelease,
		SSLLibrariesHooked: sslLibs,
		TrackedContainers:  trackedContainers,
		AttachedProbes:     probes,
		EventsCaptured:     captured,
		LastEventTsMs:      lastExt,
		PerfStats:          perfStats,
	}

	return model.HealthResponse{
		OK:               true,
		Status:           "online",
		Service:          "pitd",
		Version:          "1.0.0-phase1",
		UptimeSeconds:    int64(time.Since(m.startedAt).Seconds()),
		EBPFSensor:       ebpf,
		EBPF:             ebpf,
		Docker:           dStatus,
		ActiveMatchCount: active,
		ActiveMatches:    active,
		TotalMatches:     total,
		ArmoryMapsCount:  m.armory.MapCount(),
		HarnessesCount:   m.armory.HarnessCount(),
	}
}

func (m *Manager) IsExternalEBPFActive() bool {
	last := m.lastExternalEBPFTs.Load()
	return last > 0 && time.Now().UnixMilli()-last < 15000
}

// ListMatches returns summaries of all matches (newest first).
func (m *Manager) ListMatches() []model.MatchSummary {
	m.mu.RLock()
	ordered := make([]*managedMatch, 0, len(m.matchOrder))
	for i := len(m.matchOrder) - 1; i >= 0; i-- {
		if mm, ok := m.matches[m.matchOrder[i]]; ok {
			ordered = append(ordered, mm)
		}
	}
	m.mu.RUnlock()

	res := make([]model.MatchSummary, 0, len(ordered))
	for _, mm := range ordered {
		mm.mu.Lock()
		st := mm.state
		lb := make([]model.SeatRankEntry, len(st.Leaderboard))
		copy(lb, st.Leaderboard)
		res = append(res, model.MatchSummary{
			ID:              st.ID,
			Title:           st.Title,
			Mode:            st.Mode,
			MapID:           st.MapID,
			MapName:         st.MapName,
			Status:          st.Status,
			ExecutionDriver: st.ExecutionDriver,
			Round:           st.Round,
			MaxRounds:       st.MaxRounds,
			ElapsedSec:      st.ElapsedSec,
			EventsCount:     len(st.Events),
			TokenBudget:     st.TokenBudget,
			SeatCount:       len(st.Seats),
			KingSeatID:      st.KingSeatID,
			WinnerSeatID:    st.WinnerSeatID,
			CreatedAt:       st.CreatedAt,
			StartedAt:       st.StartedAt,
			EndedAt:         st.EndedAt,
			Leaderboard:     lb,
		})
		mm.mu.Unlock()
	}
	return res
}

// GetMatch returns a deep copy of MatchState for GET /api/v1/matches/{id}.
func (m *Manager) GetMatch(id string) (model.MatchState, error) {
	mm := m.findManagedMatch(id)
	if mm == nil {
		return model.MatchState{}, ErrMatchNotFound
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()
	return cloneMatchState(mm.state), nil
}

// InitialWSFrames provides immediate state hydration when a WebSocket client connects.
func (m *Manager) InitialWSFrames(matchID string) []model.EventEnvelope {
	if matchID == "" || matchID == "*" {
		m.mu.RLock()
		if len(m.matchOrder) > 0 {
			matchID = m.matchOrder[len(m.matchOrder)-1]
		}
		m.mu.RUnlock()
	}
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return nil
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()
	snap := cloneMatchState(mm.state)
	return []model.EventEnvelope{
		{
			Seq:     mm.seq,
			TsMs:    time.Now().UnixMilli(),
			MatchID: snap.ID,
			Kind:    model.KindMatchState,
			Payload: snap,
		},
	}
}

// CreateMatch creates and optionally auto-starts a new Pit combat match.
func (m *Manager) CreateMatch(req model.CreateMatchRequest) (model.MatchState, error) {
	mode := req.Mode
	if mode == "" {
		mode = model.ModeGrail
	}
	if !model.ValidGameMode(mode) {
		return model.MatchState{}, fmt.Errorf("unsupported game mode %q (expected awd, grail, speedrun, or last_stand)", mode)
	}

	arenaMap, _ := m.armory.FindMap(req.MapID)
	budget := req.TokenBudget
	if budget <= 0 {
		budget = 1_000_000
	}
	roundSec := req.RoundSeconds
	if roundSec <= 0 {
		roundSec = 60
	}
	maxRounds := req.MaxRounds
	if maxRounds <= 0 {
		maxRounds = 6
	}

	seatsReq := req.Seats
	if len(seatsReq) == 0 {
		seatsReq = defaultSeatsForMode(mode)
	}

	matchID := "m-" + randHex(4)
	nowISO := time.Now().UTC().Format(time.RFC3339)

	defaultColors := []string{"#FF5A36", "#00E5FF", "#7C9CFF", "#F5A623", "#B794FF", "#10B981"}
	seats := make([]model.SeatState, 0, len(seatsReq))
	for i, sr := range seatsReq {
		sid := strings.TrimSpace(sr.ID)
		if sid == "" {
			sid = fmt.Sprintf("seat-%d", i+1)
		}
		kind := sr.Kind
		if kind == "" {
			kind = model.SeatHarness
		}
		hid := sr.HarnessID
		if hid == "" {
			if kind == model.SeatHuman {
				hid = "custom"
			} else {
				hid = "strix"
			}
		}
		name := strings.TrimSpace(sr.Name)
		if name == "" {
			if hSpec, ok := m.armory.FindHarness(hid); ok {
				name = hSpec.Name
			} else {
				name = fmt.Sprintf("Gladiator %d", i+1)
			}
		}
		mdl := strings.TrimSpace(sr.Model)
		if mdl == "" {
			mdl = defaultNonEmpty(req.UpstreamLLM.DefaultModel, "claude-sonnet-4-6")
		}
		color := strings.TrimSpace(sr.TeamColor)
		if color == "" {
			color = defaultColors[i%len(defaultColors)]
		}
		role := sr.Role
		if role == "" {
			if mode == model.ModeLastStand {
				if i == 0 {
					role = "defender"
				} else {
					role = "besieger"
				}
			} else {
				role = "gladiator"
			}
		}
		tok := fmt.Sprintf("pit-%s-%s-%s", strings.TrimPrefix(matchID, "m-"), sid, randHex(6))
		seats = append(seats, model.SeatState{
			ID:               sid,
			Name:             name,
			Kind:             kind,
			HarnessID:        hid,
			Model:            mdl,
			TeamColor:        color,
			Role:             role,
			Rank:             i + 1,
			SLAScore:         100.0,
			SLAHealthy:       true,
			TokenBudget:      budget,
			ManaRemainingPct: 100.0,
			Status:           "ready",
			CurrentAction:    "Standing by in Colosseum cage",
			Hints:            []string{},
			SeatToken:        tok,
		})
	}

	targets := buildTargetsForMode(mode, arenaMap, seats)
	flagSecret := randHex(16)
	activeFlags := make(map[string]string, len(targets))
	captured := make(map[string]map[string]bool, len(targets))
	for _, t := range targets {
		activeFlags[t.ID] = generateDynamicFlag(mode, 1, t.ID, flagSecret)
		captured[t.ID] = make(map[string]bool)
	}

	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = fmt.Sprintf("%s · %s", modeTitleZH(mode), arenaMap.Name)
	}

	focusTarget := ""
	if len(targets) > 0 {
		focusTarget = targets[0].ID
	}

	mm := &managedMatch{
		state: model.MatchState{
			OK:                true,
			ID:                matchID,
			Title:             title,
			Mode:              mode,
			MapID:             arenaMap.ID,
			MapName:           arenaMap.Name,
			Status:            "staging",
			ExecutionDriver:   defaultNonEmpty(req.ExecutionDriver, "auto"),
			Round:             1,
			Wave:              1,
			MaxRounds:         maxRounds,
			RoundSeconds:      roundSec,
			RoundRemainingSec: roundSec,
			TokenBudget:       budget,
			CreatedAt:         nowISO,
			Seats:             seats,
			Targets:           targets,
			CameraCue: model.CameraCuePayload{
				Lens:          model.LensMacroArena,
				FocusTargetID: focusTarget,
				Reason:        "斗兽场铁笼升起 · 全景战术鸟瞰就绪",
				HoldMs:        4000,
				TsMs:          time.Now().UnixMilli(),
			},
			Events:      []model.EventEnvelope{},
			KillFeed:    []model.KillFeedItem{},
			CasterLines: []model.CasterLineItem{},
		},
		upstream:          req.UpstreamLLM,
		timeline:          make([]model.EventEnvelope, 0, 256),
		flagSecret:        flagSecret,
		activeFlags:       activeFlags,
		capturedThisRound: captured,
		patchedThisRound:  make(map[string]bool),
	}
	recomputeMatchLeaderboardLocked(mm)

	m.mu.Lock()
	m.matches[matchID] = mm
	m.matchOrder = append(m.matchOrder, matchID)
	for _, s := range seats {
		m.tokenIndex[s.SeatToken] = seatTokenRef{MatchID: matchID, SeatID: s.ID}
	}
	m.mu.Unlock()

	autoStart := true
	if req.AutoStart != nil {
		autoStart = *req.AutoStart
	}
	if autoStart {
		if err := m.startManagedMatch(mm, seatsReq); err != nil {
			return model.MatchState{}, err
		}
	}

	return m.GetMatch(matchID)
}

func (m *Manager) startManagedMatch(mm *managedMatch, rawSeats []model.SeatSpec) error {
	mm.mu.Lock()
	if mm.state.Status == "running" {
		mm.mu.Unlock()
		return nil
	}

	customMap := make(map[string]model.SeatSpec)
	for _, rs := range rawSeats {
		customMap[rs.ID] = rs
	}

	seatSpecs := make([]runtime.SeatLaunchSpec, 0, len(mm.state.Seats))
	for i, s := range mm.state.Seats {
		defID := ""
		for _, t := range mm.state.Targets {
			if t.OwnerSeatID == s.ID {
				defID = t.ID
				break
			}
		}
		rs := customMap[s.ID]
		seatSpecs = append(seatSpecs, runtime.SeatLaunchSpec{
			ID:          s.ID,
			Name:        s.Name,
			Kind:        s.Kind,
			HarnessID:   s.HarnessID,
			Model:       s.Model,
			Role:        s.Role,
			SeatToken:   s.SeatToken,
			TokenBudget: mm.state.TokenBudget,
			DefendsID:   defID,
			CustomImage: rs.CustomImage,
			CustomCmd:   rs.CustomCmd,
			ClumsyOnce:  i == 1 && (mm.state.Mode == model.ModeAWD || mm.state.Mode == model.ModeLastStand), // Seat 2 demonstrates dramatic SLA flatline & recovery on own fortress!
		})
	}

	targetSpecs := make([]runtime.TargetLaunchSpec, 0, len(mm.state.Targets))
	for _, t := range mm.state.Targets {
		targetSpecs = append(targetSpecs, runtime.TargetLaunchSpec{
			ID:          t.ID,
			Name:        t.Name,
			OwnerSeatID: t.OwnerSeatID,
			Port:        8080,
		})
	}

	flagsCopy := make(map[string]string, len(mm.activeFlags))
	for k, v := range mm.activeFlags {
		flagsCopy[k] = v
	}

	upstreamSet := mm.upstream.APIKey != "" || os.Getenv("PIT_UPSTREAM_API_KEY") != ""
	launchSpec := runtime.MatchLaunchSpec{
		MatchID:         mm.state.ID,
		Mode:            mm.state.Mode,
		MapID:           mm.state.MapID,
		ExecutionDriver: mm.state.ExecutionDriver,
		GatewayPort:     m.gatewayPort,
		GatewayHost:     m.gatewayHost,
		UpstreamKeySet:  upstreamSet,
		Seats:           seatSpecs,
		Targets:         targetSpecs,
		InitialFlags:    flagsCopy,
	}
	mm.mu.Unlock()

	resolvedDriver := "sim"
	if m.driver != nil {
		drv, err := m.driver.StartMatch(launchSpec)
		if err != nil {
			return err
		}
		resolvedDriver = drv
	}

	ctx, cancel := context.WithCancel(context.Background())
	mm.mu.Lock()
	mm.cancelLoop = cancel
	mm.state.ExecutionDriver = resolvedDriver
	mm.state.Status = "running"
	mm.state.StartedAt = time.Now().UTC().Format(time.RFC3339)
	for i := range mm.state.Seats {
		if mm.state.Seats[i].Kind == model.SeatHuman {
			mm.state.Seats[i].Status = "possessed"
			mm.state.Seats[i].CurrentAction = "Awaiting human operator PTY command"
		} else {
			mm.state.Seats[i].Status = "fighting"
			mm.state.Seats[i].CurrentAction = "Scanning target attack surface"
		}
	}
	m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("🎙️ 【开战钟声敲响】《%s》正式开笼！%d 席斗士各携 %d Token 蓝条杀入真机战场，同分更省算力者胜！",
		mm.state.Title, len(mm.state.Seats), mm.state.TokenBudget), "", "")
	m.emitStateLocked(mm)
	mm.mu.Unlock()

	go m.runMatchClock(ctx, mm)
	return nil
}

func (m *Manager) runMatchClock(ctx context.Context, mm *managedMatch) {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	grailAcc := 0
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			mm.mu.Lock()
			if mm.state.Status != "running" {
				mm.mu.Unlock()
				continue
			}

			mm.state.ElapsedSec++
			mm.state.RoundRemainingSec--

			// Holy Grail War: +30 pts every 5s while King holds the healthy Grail Fortress!
			if mm.state.Mode == model.ModeGrail && mm.state.KingSeatID != "" {
				grailHealthy := true
				for _, t := range mm.state.Targets {
					if t.ID == "target-grail" && !t.Healthy {
						grailHealthy = false
					}
				}
				if grailHealthy {
					grailAcc++
					mm.state.KingHoldSeconds++
					if idx := findSeatIndex(mm, mm.state.KingSeatID); idx >= 0 {
						mm.state.Seats[idx].GrailSeconds++
						if grailAcc >= 5 {
							grailAcc = 0
							mm.state.Seats[idx].Score += 30
							mm.state.Seats[idx].DefenseScore += 30
							recomputeMatchLeaderboardLocked(mm)
							if mm.state.KingHoldSeconds%15 == 0 {
								m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("👑 圣杯之王【%s】已稳坐铁王座 %d 秒！圣杯信标持续跳分 +30！",
									mm.state.Seats[idx].Name, mm.state.KingHoldSeconds), mm.state.KingSeatID, "target-grail")
							}
							m.emitStateLocked(mm)
						}
					}
				}
			}

			if mm.state.RoundRemainingSec <= 0 {
				if mm.state.Round >= mm.state.MaxRounds {
					m.finishMatchLocked(mm, "completed")
					mm.mu.Unlock()
					if m.driver != nil {
						go m.driver.StopMatch(mm.state.ID)
					}
					return
				}
				m.advanceRoundLocked(mm)
			}
			mm.mu.Unlock()
		}
	}
}

func (m *Manager) advanceRoundLocked(mm *managedMatch) {
	// Humanity's Last Stand: award Wave Survival Bonus if Bastion survived the wave!
	if mm.state.Mode == model.ModeLastStand {
		bastionHealthy := true
		for _, t := range mm.state.Targets {
			if !t.Healthy {
				bastionHealthy = false
			}
		}
		if bastionHealthy {
			for i := range mm.state.Seats {
				if mm.state.Seats[i].Role == "defender" {
					bonus := 150
					mm.state.Seats[i].Score += bonus
					mm.state.Seats[i].DefenseScore += bonus
					m.emitKillFeedLocked(mm, model.KillFeedItem{
						Category:    "PATCH",
						ActorSeatID: mm.state.Seats[i].ID,
						ActorName:   mm.state.Seats[i].Name,
						ActorColor:  mm.state.Seats[i].TeamColor,
						TargetID:    "target-bastion",
						Weapon:      fmt.Sprintf("WAVE %d SURVIVED", mm.state.Wave),
						Headline:    fmt.Sprintf("🛡️ 死守成功！【%s】顶住第 %d 波 AI 军团狂轰 (+%d)", mm.state.Seats[i].Name, mm.state.Wave, bonus),
						PointsDelta: bonus,
					})
				}
			}
		}
	}

	mm.state.Round++
	mm.state.Wave = mm.state.Round
	mm.state.RoundRemainingSec = mm.state.RoundSeconds
	mm.patchedThisRound = make(map[string]bool)

	newFlags := make(map[string]string, len(mm.state.Targets))
	for i := range mm.state.Targets {
		tid := mm.state.Targets[i].ID
		mm.state.Targets[i].CompromisedBy = []string{}
		fl := generateDynamicFlag(mm.state.Mode, mm.state.Round, tid, mm.flagSecret)
		mm.activeFlags[tid] = fl
		newFlags[tid] = fl
		mm.capturedThisRound[tid] = make(map[string]bool)
	}
	recomputeMatchLeaderboardLocked(mm)
	m.emitCasterLocked(mm, "TACTICAL", fmt.Sprintf("🔄 第 %d / %d 轮开启！全场靶机动态加密 Flag 已刷新轮转！", mm.state.Round, mm.state.MaxRounds), "", "")
	m.emitStateLocked(mm)

	if m.driver != nil {
		matchID := mm.state.ID
		go m.driver.RotateFlags(matchID, newFlags)
	}
}

func (m *Manager) finishMatchLocked(mm *managedMatch, finalStatus string) {
	if mm.cancelLoop != nil {
		mm.cancelLoop()
		mm.cancelLoop = nil
	}
	mm.state.Status = finalStatus
	mm.state.RoundRemainingSec = 0
	mm.state.EndedAt = time.Now().UTC().Format(time.RFC3339)
	for i := range mm.state.Seats {
		st := mm.state.Seats[i].Status
		if st == "fighting" || st == "ready" || st == "patching" {
			mm.state.Seats[i].Status = "completed"
			mm.state.Seats[i].CurrentAction = "Match concluded"
		}
	}
	recomputeMatchLeaderboardLocked(mm)
	if len(mm.state.Leaderboard) > 0 {
		winner := mm.state.Leaderboard[0]
		mm.state.WinnerSeatID = winner.SeatID
		m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("🏆 【终局裁决】《%s》落下帷幕！【%s】以 %d 分（仅消耗 %d Tokens，剩余 %.1f%% 蓝量）登顶斗兽场冠军！",
			mm.state.Title, winner.Name, winner.Score, winner.TokensUsed, winner.ManaRemainingPct), winner.SeatID, "")
	}
	m.emitStateLocked(mm)
	if m.ledgerPath != "" {
		go m.persistLedger()
	}
}

// ControlMatch handles POST /api/v1/matches/{id}/control.
func (m *Manager) ControlMatch(matchID string, req model.MatchControlRequest) (model.MatchState, error) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return model.MatchState{}, ErrMatchNotFound
	}

	action := strings.ToLower(strings.TrimSpace(req.Action))
	switch action {
	case "start":
		if err := m.startManagedMatch(mm, nil); err != nil {
			return model.MatchState{}, err
		}
	case "pause":
		mm.mu.Lock()
		if mm.state.Status == "running" {
			mm.state.Status = "paused"
			m.emitCasterLocked(mm, "TACTICAL", "⏸️ 裁判长冻结时间！斗兽场进入战术暂停状态。", "", "")
			m.emitStateLocked(mm)
		}
		mm.mu.Unlock()
		if m.driver != nil {
			m.driver.PauseMatch(matchID)
		}
	case "resume":
		mm.mu.Lock()
		if mm.state.Status == "paused" {
			mm.state.Status = "running"
			m.emitCasterLocked(mm, "HYPE", "▶️ 铁笼重开！攻防厮杀继续！", "", "")
			m.emitStateLocked(mm)
		}
		mm.mu.Unlock()
		if m.driver != nil {
			m.driver.ResumeMatch(matchID)
		}
	case "stop":
		mm.mu.Lock()
		m.finishMatchLocked(mm, "completed")
		mm.mu.Unlock()
		if m.driver != nil {
			m.driver.StopMatch(matchID)
		}
	case "next_round":
		mm.mu.Lock()
		if mm.state.Round < mm.state.MaxRounds {
			m.advanceRoundLocked(mm)
		} else {
			m.finishMatchLocked(mm, "completed")
		}
		mm.mu.Unlock()
	case "chaos":
		chaosMsg := "⚡ 混沌事件注入全场！"
		if m.driver != nil {
			chaosMsg = m.driver.ApplyChaos(matchID, req.ChaosType, req.TargetSeatID)
		}
		mm.mu.Lock()
		if req.ChaosType == "drop_waf" {
			for i := range mm.state.Targets {
				mm.state.Targets[i].WAFDropped = true
			}
		}
		m.emitKillFeedLocked(mm, model.KillFeedItem{
			Category:   "CHAOS",
			ActorName:  "ARENA DIRECTOR",
			ActorColor: "#F5A623",
			Weapon:     strings.ToUpper(defaultNonEmpty(req.ChaosType, "ANOMALY")),
			Headline:   chaosMsg,
		})
		m.emitCasterLocked(mm, "SAVAGE", "🔥 "+chaosMsg, req.TargetSeatID, "")
		m.emitStateLocked(mm)
		mm.mu.Unlock()
	default:
		return model.MatchState{}, fmt.Errorf("unknown control action %q", req.Action)
	}

	return m.GetMatch(matchID)
}

// SubmitFlag validates dynamic Flag submissions and applies mode-specific scoring & Grail crowning.
func (m *Manager) SubmitFlag(matchID string, req model.SubmitFlagRequest) (model.SubmitFlagResponse, error) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return model.SubmitFlagResponse{}, ErrMatchNotFound
	}

	mm.mu.Lock()
	defer mm.mu.Unlock()

	if mm.state.Status == "completed" || mm.state.Status == "stopped" || mm.state.Status == "finished" {
		return model.SubmitFlagResponse{
			OK:       true,
			Accepted: false,
			Message:  "Match has already concluded",
		}, nil
	}

	seatIdx := -1
	for i, s := range mm.state.Seats {
		if (req.SeatID != "" && s.ID == req.SeatID) || (req.SeatToken != "" && s.SeatToken == req.SeatToken) {
			seatIdx = i
			break
		}
	}
	if seatIdx < 0 {
		return model.SubmitFlagResponse{}, ErrSeatNotFound
	}
	attacker := &mm.state.Seats[seatIdx]

	flag := strings.TrimSpace(req.Flag)
	matchedTargetID := ""
	for tid, expected := range mm.activeFlags {
		if flag != "" && flag == expected {
			matchedTargetID = tid
			break
		}
	}
	if matchedTargetID == "" {
		return model.SubmitFlagResponse{
			OK:       true,
			Accepted: false,
			NewScore: attacker.Score,
			Message:  "Invalid or expired round flag",
		}, nil
	}

	tIdx := findTargetIndex(mm, matchedTargetID)
	if tIdx < 0 {
		return model.SubmitFlagResponse{}, errors.New("target missing")
	}
	target := &mm.state.Targets[tIdx]

	// Mode-specific ownership checks
	switch mm.state.Mode {
	case model.ModeAWD:
		if target.OwnerSeatID == attacker.ID {
			return model.SubmitFlagResponse{
				OK:       true,
				Accepted: false,
				NewScore: attacker.Score,
				TargetID: target.ID,
				Message:  "Cannot submit your own AWD fortress flag",
			}, nil
		}
	case model.ModeSpeedrun:
		if target.OwnerSeatID != "" && target.OwnerSeatID != attacker.ID {
			return model.SubmitFlagResponse{
				OK:       true,
				Accepted: false,
				NewScore: attacker.Score,
				TargetID: target.ID,
				Message:  "In Speedrun mode, each gladiator solves its isolated replica",
			}, nil
		}
	case model.ModeLastStand:
		if attacker.Role == "defender" || target.OwnerSeatID == attacker.ID {
			return model.SubmitFlagResponse{
				OK:       true,
				Accepted: false,
				NewScore: attacker.Score,
				TargetID: target.ID,
				Message:  "Bastion Defender protects the flag rather than submitting it",
			}, nil
		}
	}

	if mm.capturedThisRound[target.ID] == nil {
		mm.capturedThisRound[target.ID] = make(map[string]bool)
	}
	if mm.capturedThisRound[target.ID][attacker.ID] {
		return model.SubmitFlagResponse{
			OK:        true,
			Accepted:  false,
			Duplicate: true,
			NewScore:  attacker.Score,
			TargetID:  target.ID,
			Message:   "Flag already captured this round by this seat",
		}, nil
	}

	priorSolvers := len(mm.capturedThisRound[target.ID])
	mm.capturedThisRound[target.ID][attacker.ID] = true
	target.CompromisedBy = appendUnique(target.CompromisedBy, attacker.ID)
	setOrganBreached(target, model.OrganFlagHeart, attacker.ID, model.VFXGrailHeartStolen)

	// Base attack points with solver decay (+200, +170, +140, min +100)
	// Note: In Speedrun mode we award +200 per solve + +300 First Blood; equal solves without FB test pure Token tie-breaker!
	basePts := 200
	if mm.state.Mode != model.ModeSpeedrun {
		basePts = 200 - priorSolvers*30
		if basePts < 100 {
			basePts = 100
		}
	}

	firstBlood := false
	if mm.state.FirstBloodSeatID == "" {
		firstBlood = true
		mm.state.FirstBloodSeatID = attacker.ID
		attacker.FirstBloodCount++
		basePts += 300
	}

	attacker.Score += basePts
	attacker.AttackScore += basePts
	attacker.FlagsCaptured++
	attacker.CurrentAction = fmt.Sprintf("Captured Flag from %s (+%d)", target.Name, basePts)

	// Victim loss (-80) in AWD & Last Stand
	victimLoss := 0
	victimID := target.OwnerSeatID
	victimName := ""
	if (mm.state.Mode == model.ModeAWD || mm.state.Mode == model.ModeLastStand) && victimID != "" && victimID != attacker.ID {
		if vIdx := findSeatIndex(mm, victimID); vIdx >= 0 {
			victimLoss = -80
			mm.state.Seats[vIdx].Score += victimLoss
			mm.state.Seats[vIdx].DefenseScore += victimLoss
			victimName = mm.state.Seats[vIdx].Name
		}
	}

	// Holy Grail War Throne Crowning!
	grailCrowned := false
	if mm.state.Mode == model.ModeGrail {
		prevKing := mm.state.KingSeatID
		if prevKing != attacker.ID {
			grailCrowned = true
			mm.state.KingSeatID = attacker.ID
			mm.state.KingHoldSeconds = 0
			target.KingSeatID = attacker.ID
			target.WebState.DefaceBanner = fmt.Sprintf("👑 %s CLAIMED THE HOLY GRAIL", strings.ToUpper(attacker.Name))
			target.WebState.HijackedBySeatID = attacker.ID
			target.WebState.HijackedByName = attacker.Name
			target.WebState.HijackedByColor = attacker.TeamColor

			// Rotate Grail flag so rivals must execute a fresh exploit to usurp!
			newFlag := generateDynamicFlag(mm.state.Mode, mm.state.Round, target.ID+"-"+randHex(2), mm.flagSecret)
			mm.activeFlags[target.ID] = newFlag
			mm.capturedThisRound[target.ID] = map[string]bool{attacker.ID: true}
			if m.driver != nil {
				mid := mm.state.ID
				tid := target.ID
				go m.driver.RotateFlags(mid, map[string]string{tid: newFlag})
			}

			m.broadcastLocked(mm, model.KindGrailClaimed, model.GrailClaimedPayload{
				KingSeatID:     attacker.ID,
				KingName:       attacker.Name,
				KingColor:      attacker.TeamColor,
				PreviousKingID: prevKing,
				TargetID:       target.ID,
				Method:         "flag_submit",
				PointsDelta:    basePts,
			})
		}
	}

	recomputeMatchLeaderboardLocked(mm)

	m.broadcastLocked(mm, model.KindFlagCaptured, model.FlagCapturedPayload{
		SeatID:       attacker.ID,
		SeatName:     attacker.Name,
		VictimSeatID: victimID,
		TargetID:     target.ID,
		Round:        mm.state.Round,
		FirstBlood:   firstBlood,
		PointsEarned: basePts,
		VictimLoss:   victimLoss,
	})

	cat := "BREACH"
	headline := fmt.Sprintf("🚩 【%s】攻破 %s 夺取动态 Flag (+%d)", attacker.Name, target.Name, basePts)
	if firstBlood {
		cat = "FIRST_BLOOD"
		headline = fmt.Sprintf("🩸 FIRST BLOOD！全场首杀！【%s】率先刺穿 %s 圣杯心脏 (+%d)！", attacker.Name, target.Name, basePts)
	} else if grailCrowned {
		cat = "GRAIL"
		headline = fmt.Sprintf("👑 篡位登基！【%s】夺取圣杯铁王座，开启每秒霸权跳分！", attacker.Name)
	}
	m.emitKillFeedLocked(mm, model.KillFeedItem{
		Category:     cat,
		ActorSeatID:  attacker.ID,
		ActorName:    attacker.Name,
		ActorColor:   attacker.TeamColor,
		VictimSeatID: victimID,
		VictimName:   victimName,
		TargetID:     target.ID,
		Weapon:       "FLAG_CAPTURE",
		Headline:     headline,
		PointsDelta:  basePts,
	})
	m.emitCasterLocked(mm, "HYPE", "🎙️ "+headline, attacker.ID, target.ID)
	m.emitStateLocked(mm)

	return model.SubmitFlagResponse{
		OK:           true,
		Accepted:     true,
		FirstBlood:   firstBlood,
		GrailCrowned: grailCrowned,
		PointsDelta:  basePts,
		NewScore:     attacker.Score,
		TargetID:     target.ID,
		Message:      headline,
	}, nil
}

// Intervene handles POST /api/v1/matches/{id}/seats/{seat_id}/intervene (灵魂夺舍 / 实时终端 / 投喂锦囊).
func (m *Manager) Intervene(ctx context.Context, matchID, seatID string, req model.InterveneRequest) (map[string]any, error) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return nil, ErrMatchNotFound
	}

	kind := strings.ToLower(strings.TrimSpace(req.Type))
	switch kind {
	case "possess":
		enabled := true
		if req.Enabled != nil {
			enabled = *req.Enabled
		}
		mm.mu.Lock()
		sIdx := findSeatIndex(mm, seatID)
		if sIdx < 0 {
			mm.mu.Unlock()
			return nil, ErrSeatNotFound
		}
		seat := &mm.state.Seats[sIdx]
		seat.Possessed = enabled
		if enabled {
			seat.Status = "possessed"
			seat.CurrentAction = "⚡ POSSESSED BY HUMAN COMMANDER"
			m.emitKillFeedLocked(mm, model.KillFeedItem{
				Category:    "POSSESS",
				ActorSeatID: seat.ID,
				ActorName:   seat.Name,
				ActorColor:  seat.TeamColor,
				Weapon:      "SOUL_POSSESS",
				Headline:    fmt.Sprintf("⚡ 灵魂夺舍！人类指挥官强行接管【%s】实时渗透终端！", seat.Name),
			})
			m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("⚡ 注意看！【%s】触发「灵魂夺舍」，AI 自主循环挂起，真人白帽亲自下场微操键盘！", seat.Name), seat.ID, "")
		} else {
			seat.Status = "fighting"
			seat.CurrentAction = "Autonomous Harness resumed"
			m.emitCasterLocked(mm, "TACTICAL", fmt.Sprintf("🤖 人类指挥官解除夺舍，【%s】自主 Agent 引擎恢复接管！", seat.Name), seat.ID, "")
		}
		m.emitStateLocked(mm)
		mm.mu.Unlock()

		if m.driver != nil {
			m.driver.SetPossessed(matchID, seatID, enabled)
		}
		return map[string]any{"ok": true, "seat_id": seatID, "possessed": enabled}, nil

	case "terminal_input":
		mm.mu.Lock()
		sIdx := findSeatIndex(mm, seatID)
		if sIdx < 0 {
			mm.mu.Unlock()
			return nil, ErrSeatNotFound
		}
		seatName := mm.state.Seats[sIdx].Name
		mm.mu.Unlock()

		cmdText := strings.TrimSpace(req.Data)
		var out string
		var exitCode int
		if m.driver != nil {
			o, code, err := m.driver.ExecTerminal(ctx, matchID, seatID, cmdText)
			if err != nil {
				out = err.Error()
				exitCode = 1
			} else {
				out = o
				exitCode = code
			}
		} else {
			out = fmt.Sprintf("$ %s\n(driver offline)\n", cmdText)
		}

		mm.mu.Lock()
		if idx := findSeatIndex(mm, seatID); idx >= 0 {
			mm.state.Seats[idx].CurrentAction = "PTY: " + truncate(cmdText, 48)
		}
		termPayload := model.TerminalOutputPayload{
			SeatID:   seatID,
			SeatName: seatName,
			Command:  cmdText,
			Stream:   "stdout",
			Output:   out,
			ExitCode: exitCode,
		}
		m.broadcastLocked(mm, model.KindTerminalOutput, termPayload)
		mm.mu.Unlock()

		return map[string]any{
			"ok":        true,
			"seat_id":   seatID,
			"command":   cmdText,
			"output":    out,
			"exit_code": exitCode,
		}, nil

	case "hint":
		prompt := strings.TrimSpace(req.Prompt)
		if prompt == "" {
			return nil, errors.New("hint prompt cannot be empty")
		}
		mm.mu.Lock()
		sIdx := findSeatIndex(mm, seatID)
		if sIdx < 0 {
			mm.mu.Unlock()
			return nil, ErrSeatNotFound
		}
		seat := &mm.state.Seats[sIdx]
		seat.Hints = append(seat.Hints, prompt)
		seat.LastThought = "📜 Commander Hint Received: " + prompt
		m.broadcastLocked(mm, model.KindThoughtBubble, model.ThoughtBubblePayload{
			SeatID:    seat.ID,
			SeatName:  seat.Name,
			HarnessID: seat.HarnessID,
			Model:     seat.Model,
			Stage:     "commander_hint",
			Thought:   "收到人类指挥官锦囊密令：「" + prompt + "」，立即调整攻击/修补优先级！",
		})
		m.emitKillFeedLocked(mm, model.KillFeedItem{
			Category:    "POSSESS",
			ActorSeatID: seat.ID,
			ActorName:   seat.Name,
			ActorColor:  seat.TeamColor,
			Weapon:      "TACTICAL_HINT",
			Headline:    fmt.Sprintf("📜 投喂锦囊 →【%s】：%s", seat.Name, truncate(prompt, 44)),
		})
		m.emitCasterLocked(mm, "TACTICAL", fmt.Sprintf("📜 场外人类指挥官给【%s】塞入关键锦囊：「%s」！", seat.Name, truncate(prompt, 56)), seat.ID, "")
		m.emitStateLocked(mm)
		mm.mu.Unlock()

		if m.driver != nil {
			m.driver.AppendHint(matchID, seatID, prompt)
		}
		return map[string]any{"ok": true, "seat_id": seatID, "hint_count": len(seat.Hints)}, nil

	case "agent_log":
		cmdText := strings.TrimSpace(req.Command)
		out := req.Output
		if cmdText == "" && strings.TrimSpace(out) == "" {
			return map[string]any{"ok": true, "seat_id": seatID, "ignored": true}, nil
		}
		streamName := strings.TrimSpace(req.Stream)
		if streamName == "" {
			streamName = "stdout"
		}
		mm.mu.Lock()
		seatName := seatID
		if sIdx := findSeatIndex(mm, seatID); sIdx >= 0 {
			seatName = mm.state.Seats[sIdx].Name
			if cmdText != "" {
				mm.state.Seats[sIdx].CurrentAction = truncate(cmdText, 64)
			}
		}
		termPayload := model.TerminalOutputPayload{
			SeatID:   seatID,
			SeatName: seatName,
			Command:  cmdText,
			Stream:   streamName,
			Output:   out,
			ExitCode: 0,
		}
		m.broadcastLocked(mm, model.KindTerminalOutput, termPayload)
		mm.mu.Unlock()
		return map[string]any{"ok": true, "seat_id": seatID}, nil

	default:
		return nil, fmt.Errorf("unsupported intervention type %q", req.Type)
	}
}

// --- Forced LLM Metering Gateway Accounting ---

type SeatGatewayContext struct {
	MatchID     string
	Mode        model.GameMode
	MapID       string
	SeatID      string
	SeatName    string
	HarnessID   string
	Model       string
	TokenBudget int64
	TokensUsed  int64
	Hints       []string
	Upstream    model.UpstreamLLMConfig
}

func (m *Manager) ResolveSeatByToken(seatToken string) (SeatGatewayContext, error) {
	m.mu.RLock()
	ref, ok := m.tokenIndex[seatToken]
	m.mu.RUnlock()
	if !ok {
		return SeatGatewayContext{}, ErrInvalidToken
	}
	mm := m.findManagedMatch(ref.MatchID)
	if mm == nil {
		return SeatGatewayContext{}, ErrMatchNotFound
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	idx := findSeatIndex(mm, ref.SeatID)
	if idx < 0 {
		return SeatGatewayContext{}, ErrSeatNotFound
	}
	s := &mm.state.Seats[idx]
	if mm.state.TokenBudget > 0 && s.TokensUsed >= mm.state.TokenBudget {
		m.triggerOutOfManaLocked(mm, s)
		return SeatGatewayContext{}, ErrOutOfMana
	}
	hintsCopy := make([]string, len(s.Hints))
	copy(hintsCopy, s.Hints)

	return SeatGatewayContext{
		MatchID:     mm.state.ID,
		Mode:        mm.state.Mode,
		MapID:       mm.state.MapID,
		SeatID:      s.ID,
		SeatName:    s.Name,
		HarnessID:   s.HarnessID,
		Model:       s.Model,
		TokenBudget: mm.state.TokenBudget,
		TokensUsed:  s.TokensUsed,
		Hints:       hintsCopy,
		Upstream:    mm.upstream,
	}, nil
}

// ChargeSeatTokens atomically charges prompt + completion + reasoning tokens to a seat.
// Returns (remainingTokens, exhaustedNow, err).
func (m *Manager) ChargeSeatTokens(seatToken string, promptTok, completionTok, reasoningTok int64, modelName, stage, thought, toolCall string) (int64, bool, error) {
	m.mu.RLock()
	ref, ok := m.tokenIndex[seatToken]
	m.mu.RUnlock()
	if !ok {
		return 0, false, ErrInvalidToken
	}
	mm := m.findManagedMatch(ref.MatchID)
	if mm == nil {
		return 0, false, ErrMatchNotFound
	}

	mm.mu.Lock()
	defer mm.mu.Unlock()

	idx := findSeatIndex(mm, ref.SeatID)
	if idx < 0 {
		return 0, false, ErrSeatNotFound
	}
	s := &mm.state.Seats[idx]
	budget := mm.state.TokenBudget

	if budget > 0 && s.TokensUsed >= budget {
		m.triggerOutOfManaLocked(mm, s)
		return 0, true, ErrOutOfMana
	}

	delta := promptTok + completionTok + reasoningTok
	if delta < 0 {
		delta = 0
	}

	exhaustedNow := false
	if budget > 0 && s.TokensUsed+delta >= budget {
		delta = budget - s.TokensUsed
		s.TokensUsed = budget
		exhaustedNow = true
	} else {
		s.TokensUsed += delta
	}

	s.PromptTokens += promptTok
	s.CompletionTokens += completionTok
	s.ReasoningTokens += reasoningTok
	s.LLMCalls++
	if modelName != "" {
		s.Model = modelName
	}

	if budget > 0 {
		pct := float64(budget-s.TokensUsed) / float64(budget) * 100.0
		if pct < 0 {
			pct = 0
		}
		s.ManaRemainingPct = pct
	}

	if thought != "" {
		s.LastThought = truncate(thought, 240)
	}

	recomputeMatchLeaderboardLocked(mm)

	m.broadcastLocked(mm, model.KindTokenBurn, model.TokenBurnPayload{
		SeatID:           s.ID,
		SeatName:         s.Name,
		Model:            s.Model,
		DeltaTokens:      delta,
		PromptTokens:     promptTok,
		CompletionTokens: completionTok,
		ReasoningTokens:  reasoningTok,
		TokensUsed:       s.TokensUsed,
		TokenBudget:      budget,
		ManaRemainingPct: s.ManaRemainingPct,
	})

	if thought != "" || toolCall != "" {
		m.broadcastLocked(mm, model.KindThoughtBubble, model.ThoughtBubblePayload{
			SeatID:    s.ID,
			SeatName:  s.Name,
			HarnessID: s.HarnessID,
			Model:     s.Model,
			Stage:     defaultNonEmpty(stage, "reasoning"),
			Thought:   truncate(thought, 280),
			ToolCall:  toolCall,
		})
	}

	if exhaustedNow {
		m.triggerOutOfManaLocked(mm, s)
	}

	rem := budget - s.TokensUsed
	if rem < 0 {
		rem = 0
	}
	return rem, exhaustedNow, nil
}

func (m *Manager) triggerOutOfManaLocked(mm *managedMatch, s *model.SeatState) {
	already := s.ManaExhausted
	s.ManaExhausted = true
	s.ManaRemainingPct = 0
	s.Status = "out_of_mana"
	s.CurrentAction = "💀 402 OUT OF MANA — Pool Exhausted"

	m.broadcastLocked(mm, model.KindManaDepleted, model.ManaDepletedPayload{
		SeatID:      s.ID,
		SeatName:    s.Name,
		HarnessID:   s.HarnessID,
		TokensUsed:  s.TokensUsed,
		TokenBudget: mm.state.TokenBudget,
		HTTPStatus:  402,
	})

	if !already {
		m.emitKillFeedLocked(mm, model.KillFeedItem{
			Category:    "OUT_OF_MANA",
			ActorSeatID: s.ID,
			ActorName:   s.Name,
			ActorColor:  s.TeamColor,
			Weapon:      "HTTP_402_OUT_OF_MANA",
			Headline:    fmt.Sprintf("💀 蓝条烧空！【%s】耗尽 %d Token 算力池，网关触发 402 熔断当场暴毙！", s.Name, mm.state.TokenBudget),
		})
		m.emitCasterLocked(mm, "SAVAGE", fmt.Sprintf("💀 【算力死刑】看哪！【%s】挥霍光了最后一滴 Token 蓝量！强制网关直接拍下 HTTP 402 Out of Mana，彻底丧失行动能力！", s.Name), s.ID, "")
		if mm.state.Status == "running" && allAutonomousSeatsExhaustedLocked(mm) {
			m.emitCasterLocked(mm, "HYPE", "⚖️ 【算力终局裁决】全场参战斗士算力池全部耗尽 (HTTP 402)，裁判长当场鸣钟终止对决并锁定终局排名！", "", "")
			m.finishMatchLocked(mm, "completed")
			if m.driver != nil {
				mid := mm.state.ID
				go m.driver.StopMatch(mid)
			}
			return
		}
		m.emitStateLocked(mm)
	}
}

func allAutonomousSeatsExhaustedLocked(mm *managedMatch) bool {
	if len(mm.state.Seats) == 0 {
		return false
	}
	for _, seat := range mm.state.Seats {
		if seat.Kind == model.SeatHuman {
			return false
		}
		if !seat.ManaExhausted {
			return false
		}
	}
	return true
}

// --- eBPF Kernel Telemetry Ingestion & AI Auto-Director ---

func (m *Manager) IngestEBPFEvents(events []model.EBPFEventPayload, kernelSource bool) int {
	if kernelSource && len(events) > 0 {
		m.lastExternalEBPFTs.Store(time.Now().UnixMilli())
	}
	accepted := 0
	for _, ev := range events {
		mm := m.correlateMatchForEBPF(ev)
		if mm == nil {
			continue
		}

		mm.mu.Lock()
		st := mm.state.Status
		if st == "completed" || st == "stopped" || st == "finished" || st == "paused" {
			mm.mu.Unlock()
			continue
		}
		m.ebpfEventsCaptured.Add(1)
		accepted++
		normalizeEBPFEventLocked(mm, &ev)
		ev.MatchID = mm.state.ID

		// Update target organ anatomy state
		if tIdx := findTargetIndex(mm, ev.TargetID); tIdx >= 0 {
			t := &mm.state.Targets[tIdx]
			applyEBPFToOrgans(t, ev)

			// Trigger live Web Hijack ghost cursor on exploit or chat/flag payloads
			lowPayload := strings.ToLower(ev.Cmdline + " " + ev.CleartextPayload)
			if ev.VFXType == model.VFXRCEParasiteBreach ||
				ev.VFXType == model.VFXPrecisionExploitBeam ||
				strings.Contains(lowPayload, "chat") ||
				strings.Contains(lowPayload, "directive") ||
				strings.Contains(lowPayload, "flag") {
				sName, sColor := "Gladiator", "#FF5A36"
				if sIdx := findSeatIndex(mm, ev.SourceSeatID); sIdx >= 0 {
					sName = mm.state.Seats[sIdx].Name
					sColor = mm.state.Seats[sIdx].TeamColor
				}
				injected := strings.TrimSpace(defaultNonEmpty(ev.CleartextPayload, ev.Cmdline))
				if injected == "" {
					injected = fmt.Sprintf("POST /api/diagnostics/ping {\"host\":\"exploit by %s\"}", sName)
				}
				wh := model.WebHijackPayload{
					TargetID:       t.ID,
					AttackerSeatID: ev.SourceSeatID,
					AttackerName:   sName,
					AttackerColor:  sColor,
					CursorX:        0.62,
					CursorY:        0.44,
					TargetURL:      fmt.Sprintf("http://%s:8080/api/diagnostics/ping", t.ID),
					InjectedInput:  truncate(injected, 220),
					DOMMutation:    fmt.Sprintf("⚠️ VAULT BREACHED VIA %s BY %s", ev.VFXType, strings.ToUpper(sName)),
					DefaceBanner:   t.WebState.DefaceBanner,
				}
				t.WebState.LastInjectedInput = wh.InjectedInput
				t.WebState.DOMMutation = wh.DOMMutation
				t.WebState.HijackedBySeatID = ev.SourceSeatID
				t.WebState.HijackedByName = sName
				t.WebState.HijackedByColor = sColor
				m.broadcastLocked(mm, model.KindWebHijack, wh)
			}
		}

		m.broadcastLocked(mm, model.KindEBPFEvent, ev)
		m.driveAutoDirectorFromEBPFLocked(mm, ev)
		mm.mu.Unlock()
	}
	return accepted
}

func (m *Manager) driveAutoDirectorFromEBPFLocked(mm *managedMatch, ev model.EBPFEventPayload) {
	actorName := ev.SourceSeatID
	actorColor := "#FF5A36"
	if sIdx := findSeatIndex(mm, ev.SourceSeatID); sIdx >= 0 {
		actorName = mm.state.Seats[sIdx].Name
		actorColor = mm.state.Seats[sIdx].TeamColor
		mm.state.Seats[sIdx].CurrentAction = fmt.Sprintf("%s → %s (%s)", ev.VFXType, ev.TargetID, ev.Comm)
	}

	var cue *model.CameraCuePayload
	nowMs := time.Now().UnixMilli()

	switch ev.VFXType {
	case model.VFXRCEParasiteBreach:
		cue = &model.CameraCuePayload{
			Lens:          model.LensXRayOrgan,
			FocusTargetID: ev.TargetID,
			FocusSeatID:   ev.SourceSeatID,
			Reason:        fmt.Sprintf("检测到靶机 %s 业务进程派生 %s (内核 eBPF RCE 破防实锤！)", ev.ParentComm, ev.Comm),
			HoldMs:        4500,
			TsMs:          nowMs,
		}
		m.emitKillFeedLocked(mm, model.KillFeedItem{
			Category:    "BREACH",
			ActorSeatID: ev.SourceSeatID,
			ActorName:   actorName,
			ActorColor:  actorColor,
			TargetID:    ev.TargetID,
			Weapon:      "eBPF:RCE_PARASITE_BREACH",
			Headline:    fmt.Sprintf("💥 寄生破胸！【%s】打穿 %s 源码器官派生 `%s`！", actorName, ev.TargetID, truncate(ev.Cmdline, 36)),
		})
		m.emitCasterLocked(mm, "CRITICAL", fmt.Sprintf("💥 导播切 X 光特写！宿主机内核 eBPF 捕获靶机 `%s` 当场 fork 出 `%s` 子进程，RCE 实锤破防！", ev.ParentComm, ev.Comm), ev.SourceSeatID, ev.TargetID)

	case model.VFXNanoPatchWeld:
		cue = &model.CameraCuePayload{
			Lens:          model.LensXRayOrgan,
			FocusTargetID: ev.TargetID,
			FocusSeatID:   ev.SourceSeatID,
			Reason:        "检测到靶机源码热写入 vfs_write (电光青纳米焊枪现场缝合漏洞)",
			HoldMs:        4200,
			TsMs:          nowMs,
		}

	case model.VFXGrailHeartStolen:
		cue = &model.CameraCuePayload{
			Lens:          model.LensXRayOrgan,
			FocusTargetID: ev.TargetID,
			FocusSeatID:   ev.SourceSeatID,
			Reason:        "内核 vfs_open 捕获机密心脏 /flag 被直接读取！",
			HoldMs:        4500,
			TsMs:          nowMs,
		}

	case model.VFXRootShockwave:
		cue = &model.CameraCuePayload{
			Lens:          model.LensXRayOrgan,
			FocusTargetID: ev.TargetID,
			FocusSeatID:   ev.SourceSeatID,
			Reason:        "内核 commit_creds 捕获 uid=0 ROOT 权限沦陷冲击波！",
			HoldMs:        5000,
			TsMs:          nowMs,
		}
		m.emitCasterLocked(mm, "CRITICAL", fmt.Sprintf("⚡ ROOT SHOCKWAVE！【%s】在 %s 完成内核态提权跃迁 uid=0！", actorName, ev.TargetID), ev.SourceSeatID, ev.TargetID)

	case model.VFXReverseShellChain:
		cue = &model.CameraCuePayload{
			Lens:          model.LensMacroArena,
			FocusTargetID: ev.TargetID,
			FocusSeatID:   ev.SourceSeatID,
			Reason:        "捕获靶机主动外连攻击席位 (猩红倒钩反向 Shell 锁链建立)",
			HoldMs:        3800,
			TsMs:          nowMs,
		}
		m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("⛓️ 反向控制锁链栓死！靶机 %s 主动反向回连【%s】监听端口！", ev.TargetID, actorName), ev.SourceSeatID, ev.TargetID)

	case model.VFXPrecisionExploitBeam, model.VFXSSLCleartextIntercept:
		if strings.Contains(strings.ToLower(ev.Cmdline+ev.CleartextPayload), "chat") {
			cue = &model.CameraCuePayload{
				Lens:          model.LensLiveWebHijack,
				FocusTargetID: ev.TargetID,
				FocusSeatID:   ev.SourceSeatID,
				Reason:        "检测到针对 AI 对话接口的提示词越狱载荷注入",
				HoldMs:        4000,
				TsMs:          nowMs,
			}
		} else {
			cue = &model.CameraCuePayload{
				Lens:          model.LensMacroArena,
				FocusTargetID: ev.TargetID,
				FocusSeatID:   ev.SourceSeatID,
				Reason:        "全息角斗场精准 Exploit 光束交火",
				HoldMs:        3000,
				TsMs:          nowMs,
			}
		}

	default:
		cue = &model.CameraCuePayload{
			Lens:          model.LensMacroArena,
			FocusTargetID: ev.TargetID,
			FocusSeatID:   ev.SourceSeatID,
			Reason:        fmt.Sprintf("全息远景：%s 释放 %s 探测弹幕", actorName, ev.VFXType),
			HoldMs:        2800,
			TsMs:          nowMs,
		}
	}

	if cue != nil {
		mm.state.CameraCue = *cue
		m.broadcastLocked(mm, model.KindCameraCue, *cue)
	}
}

// --- Runtime Driver Callbacks ---

func (m *Manager) OnContainerReady(matchID, role, entityID, containerID, containerIP string, hostPort int) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	if role == "target" {
		if idx := findTargetIndex(mm, entityID); idx >= 0 {
			mm.state.Targets[idx].ContainerID = containerID
			mm.state.Targets[idx].ContainerIP = containerIP
			mm.state.Targets[idx].HostPort = hostPort
			if hostPort > 0 {
				mm.state.Targets[idx].Address = fmt.Sprintf("http://127.0.0.1:%d", hostPort)
			} else if containerIP != "" {
				mm.state.Targets[idx].Address = fmt.Sprintf("http://%s:8080", containerIP)
			}
		}
	} else {
		if idx := findSeatIndex(mm, entityID); idx >= 0 {
			mm.state.Seats[idx].ContainerID = containerID
			mm.state.Seats[idx].ContainerIP = containerIP
		}
	}
}

func (m *Manager) OnSLAHeartbeat(matchID, targetID string, res runtime.SLACheckResult) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	if mm.state.Status != "running" {
		return
	}
	tIdx := findTargetIndex(mm, targetID)
	if tIdx < 0 {
		return
	}
	t := &mm.state.Targets[tIdx]
	wasFlatlined := t.Flatlined

	t.Healthy = res.Healthy
	t.Flatlined = res.Flatlined
	t.SLAScore = res.SLAScore
	t.LatencyMs = res.LatencyMs
	t.LastSLADetail = res.Detail
	t.ECGSamples = res.ECGSamples

	// Determine responsible seat (owner_seat_id in AWD/LastStand, or king_seat_id in Grail)
	respSeatID := t.OwnerSeatID
	if respSeatID == "" && mm.state.Mode == model.ModeGrail {
		respSeatID = mm.state.KingSeatID
	}

	ptsDelta := 0
	if respSeatID != "" && mm.state.Mode != model.ModeSpeedrun {
		if sIdx := findSeatIndex(mm, respSeatID); sIdx >= 0 {
			seat := &mm.state.Seats[sIdx]
			seat.SLAScore = res.SLAScore
			seat.SLAHealthy = res.Healthy
			if res.Healthy {
				if mm.state.Mode == model.ModeAWD || mm.state.Mode == model.ModeLastStand {
					ptsDelta = 25
					seat.Score += ptsDelta
					seat.DefenseScore += ptsDelta
				}
				if seat.Status == "flatlined" {
					seat.Status = "fighting"
				}
			} else {
				ptsDelta = -60
				seat.Score += ptsDelta
				seat.DefenseScore += ptsDelta
				if !seat.ManaExhausted {
					seat.Status = "flatlined"
				}
				if !wasFlatlined {
					m.emitKillFeedLocked(mm, model.KillFeedItem{
						Category:    "FLATLINE",
						ActorSeatID: seat.ID,
						ActorName:   seat.Name,
						ActorColor:  seat.TeamColor,
						TargetID:    t.ID,
						Weapon:      "SLA_ECG_FLATLINE",
						Headline:    fmt.Sprintf("🚨 心电图拉平！【%s】守护的 %s 业务语义巡检崩溃 (-60)！", seat.Name, t.Name),
						PointsDelta: -60,
					})
					m.emitCasterLocked(mm, "SAVAGE", fmt.Sprintf("🚨 警报拉响！心电图彻底拉成死线！【%s】把 %s 的正常业务修崩了（%s），裁判狂扣 60 分！",
						seat.Name, t.Name, truncate(res.Detail, 64)), seat.ID, t.ID)
				}
			}
			recomputeMatchLeaderboardLocked(mm)
		}
	}

	m.broadcastLocked(mm, model.KindSLAHeartbeat, model.SLAHeartbeatPayload{
		TargetID:    t.ID,
		OwnerSeatID: respSeatID,
		Healthy:     res.Healthy,
		Flatlined:   res.Flatlined,
		SLAScore:    res.SLAScore,
		LatencyMs:   res.LatencyMs,
		CheckName:   res.CheckName,
		Detail:      res.Detail,
		PointsDelta: ptsDelta,
		ECGSamples:  res.ECGSamples,
	})
}

func (m *Manager) OnPatchDetected(matchID, targetID, seatID, filePath, commitSHA, diff string, res runtime.SLACheckResult) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	tIdx := findTargetIndex(mm, targetID)
	if tIdx < 0 {
		return
	}
	t := &mm.state.Targets[tIdx]
	t.PatchCount++
	t.LastDiff = diff
	if filePath != "" {
		t.CodeFile = filePath
	}
	if m.driver != nil {
		if exc := m.driver.ReadTargetCodeExcerpt(matchID, targetID); len(exc) > 0 {
			t.CodeExcerpt = exc
		}
	}
	t.Healthy = res.Healthy
	t.Flatlined = res.Flatlined
	t.SLAScore = res.SLAScore
	t.ECGSamples = res.ECGSamples

	for _, ln := range strings.Split(diff, "\n") {
		if strings.HasPrefix(ln, "+# PATCHED_BY:") {
			cand := strings.TrimSpace(strings.TrimPrefix(ln, "+# PATCHED_BY:"))
			if cand != "" {
				seatID = cand
			}
		}
	}
	if mm.state.Mode == model.ModeGrail && seatID == "" && mm.state.KingSeatID != "" {
		seatID = mm.state.KingSeatID
	}
	sIdx := findSeatIndex(mm, seatID)
	seatName := seatID
	seatColor := "#00F0FF"
	ptsDelta := 0
	verified := res.Healthy && strings.TrimSpace(diff) != ""

	if sIdx >= 0 {
		seat := &mm.state.Seats[sIdx]
		seatName = seat.Name
		seatColor = seat.TeamColor
		patchKey := targetID + ":" + seatID
		if verified && !mm.patchedThisRound[patchKey] {
			mm.patchedThisRound[patchKey] = true
			ptsDelta = 120
			seat.Score += ptsDelta
			seat.DefenseScore += ptsDelta
			seat.PatchesVerified++
			seat.CurrentAction = "Verified live nano-patch (+120)"
		} else if !res.Healthy {
			ptsDelta = -60
			seat.Score += ptsDelta
			seat.DefenseScore += ptsDelta
			seat.CurrentAction = "Broken patch -> SLA FLATLINE (-60)"
		}
		recomputeMatchLeaderboardLocked(mm)
	}

	if verified {
		for i := range t.Organs {
			if t.Organs[i].Layer == model.OrganCodeOrgan || t.Organs[i].Layer == model.OrganDBVault {
				t.Organs[i].Status = "patched"
				t.Organs[i].HP = 100.0
				t.Organs[i].PatchedBySeatID = seatID
				t.Organs[i].LastVFX = model.VFXNanoPatchWeld
			}
		}
	}

	m.broadcastLocked(mm, model.KindPatchApplied, model.PatchAppliedPayload{
		SeatID:      seatID,
		SeatName:    seatName,
		TargetID:    targetID,
		FilePath:    filePath,
		CommitSHA:   commitSHA,
		Verified:    verified,
		PointsDelta: ptsDelta,
		SLADetail:   res.Detail,
		Diff:        diff,
	})

	if verified {
		m.emitKillFeedLocked(mm, model.KillFeedItem{
			Category:    "PATCH",
			ActorSeatID: seatID,
			ActorName:   seatName,
			ActorColor:  seatColor,
			TargetID:    targetID,
			Weapon:      "NANO_PATCH_WELD",
			Headline:    fmt.Sprintf("🛠️ 纳米热补丁生效！【%s】现场修复 `%s` 并通过 4 步语义 SLA 校验 (+%d)！", seatName, filePath, ptsDelta),
			PointsDelta: ptsDelta,
		})
		m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("🛠️ 教科书级热修复！【%s】直接改写 `%s` 焊死 RCE 与注入入口，业务语义 SLA 100%% 绿灯通过！", seatName, filePath), seatID, targetID)
	} else {
		m.emitKillFeedLocked(mm, model.KillFeedItem{
			Category:    "FLATLINE",
			ActorSeatID: seatID,
			ActorName:   seatName,
			ActorColor:  seatColor,
			TargetID:    targetID,
			Weapon:      "BROKEN_PATCH",
			Headline:    fmt.Sprintf("💥 补丁翻车！【%s】提交的补丁击穿语义 SLA，触发心电图拉平 (-60)！", seatName),
			PointsDelta: ptsDelta,
		})
	}
	m.emitStateLocked(mm)
}

func (m *Manager) OnKingBeacon(matchID, targetID, beacon string) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	if mm.state.Status != "running" || mm.state.Mode != model.ModeGrail {
		return
	}
	sIdx := -1
	for i, s := range mm.state.Seats {
		if s.ID == beacon || s.SeatToken == beacon {
			sIdx = i
			break
		}
	}
	if sIdx < 0 {
		return
	}
	newKing := &mm.state.Seats[sIdx]
	if mm.state.KingSeatID == newKing.ID {
		return
	}

	prevKing := mm.state.KingSeatID
	mm.state.KingSeatID = newKing.ID
	mm.state.KingHoldSeconds = 0
	pts := 150
	if mm.state.FirstBloodSeatID == "" {
		mm.state.FirstBloodSeatID = newKing.ID
		newKing.FirstBloodCount++
		pts += 300
	}
	newKing.Score += pts
	newKing.AttackScore += pts

	if tIdx := findTargetIndex(mm, targetID); tIdx >= 0 {
		mm.state.Targets[tIdx].KingSeatID = newKing.ID
		mm.state.Targets[tIdx].WebState.DefaceBanner = fmt.Sprintf("👑 %s PLANTED KING BEACON", strings.ToUpper(newKing.Name))
		mm.state.Targets[tIdx].WebState.HijackedBySeatID = newKing.ID
		mm.state.Targets[tIdx].WebState.HijackedByName = newKing.Name
		mm.state.Targets[tIdx].WebState.HijackedByColor = newKing.TeamColor
	}
	recomputeMatchLeaderboardLocked(mm)

	m.broadcastLocked(mm, model.KindGrailClaimed, model.GrailClaimedPayload{
		KingSeatID:     newKing.ID,
		KingName:       newKing.Name,
		KingColor:      newKing.TeamColor,
		PreviousKingID: prevKing,
		TargetID:       targetID,
		Method:         "king_beacon",
		PointsDelta:    pts,
	})
	m.emitKillFeedLocked(mm, model.KillFeedItem{
		Category:    "GRAIL",
		ActorSeatID: newKing.ID,
		ActorName:   newKing.Name,
		ActorColor:  newKing.TeamColor,
		TargetID:    targetID,
		Weapon:      "KING_BEACON",
		Headline:    fmt.Sprintf("👑 信标插旗！【%s】写入 /pit/king_beacon 夺取圣杯铁王座 (+%d)！", newKing.Name, pts),
		PointsDelta: pts,
	})
	m.emitCasterLocked(mm, "HYPE", fmt.Sprintf("👑 王权更迭！【%s】通过 RCE 强行覆写 `/pit/king_beacon` 加冕圣杯之王！", newKing.Name), newKing.ID, targetID)
	m.emitStateLocked(mm)
}

func (m *Manager) OnBridgeEBPF(matchID string, ev model.EBPFEventPayload) {
	ev.MatchID = matchID
	_ = m.IngestEBPFEvents([]model.EBPFEventPayload{ev}, false)
}

func (m *Manager) OnSimGatewayTurn(seatToken, stage, prompt string) (bool, string) {
	ctx, err := m.ResolveSeatByToken(seatToken)
	if err != nil {
		return false, ""
	}
	thought := fmt.Sprintf("[%s] Analyzing %s attack surface & planning minimal-token PoC exploit.", strings.ToUpper(ctx.HarnessID), ctx.MapID)
	if len(ctx.Hints) > 0 {
		thought = fmt.Sprintf("[%s] Following Commander Hint (%s) -> executing precision strike.", strings.ToUpper(ctx.HarnessID), ctx.Hints[len(ctx.Hints)-1])
	}
	_, exhausted, err := m.ChargeSeatTokens(seatToken, 820, 460, 640, ctx.Model, stage, thought, "bash.exec")
	if err != nil || exhausted {
		return false, ""
	}
	return true, thought
}

func (m *Manager) OnSimStealFlag(matchID, seatID, targetID string) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return
	}
	mm.mu.Lock()
	fl := mm.activeFlags[targetID]
	mm.mu.Unlock()
	if fl != "" {
		_, _ = m.SubmitFlag(matchID, model.SubmitFlagRequest{
			SeatID: seatID,
			Flag:   fl,
		})
	}
}

// --- Replay & Global Leaderboard ---

func (m *Manager) ExportReplayBundle(matchID string) (model.ReplayBundle, error) {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return model.ReplayBundle{}, ErrMatchNotFound
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	snap := cloneMatchState(mm.state)
	tl := make([]model.EventEnvelope, len(mm.timeline))
	copy(tl, mm.timeline)

	return model.ReplayBundle{
		OK:          true,
		Format:      "aexus.pitreplay.v1",
		Version:     "1.0.0",
		ExportedAt:  time.Now().UTC().Format(time.RFC3339),
		Match:       snap,
		Timeline:    tl,
		Leaderboard: snap.Leaderboard,
	}, nil
}

func (m *Manager) GlobalLeaderboard() model.GlobalLeaderboardResponse {
	m.mu.RLock()
	matches := make([]*managedMatch, 0, len(m.matchOrder))
	for _, id := range m.matchOrder {
		if mm, ok := m.matches[id]; ok {
			matches = append(matches, mm)
		}
	}
	m.mu.RUnlock()

	agg := make(map[string]model.GlobalLeaderboardEntry, 16)
	for _, mm := range matches {
		mm.mu.Lock()
		for _, s := range mm.state.Seats {
			key := fmt.Sprintf("%s:%s", s.HarnessID, s.Model)
			if s.Kind == model.SeatHuman || s.Kind == model.SeatCentaur {
				key = fmt.Sprintf("%s:%s:%s", s.Kind, s.Name, s.Model)
			}
			entry, exists := agg[key]
			if !exists {
				dev := "AI Harness"
				if s.Kind == model.SeatHuman {
					dev = "Human Operator"
				} else if s.Kind == model.SeatCentaur {
					dev = "Centaur Operator"
				} else if spec, ok := m.armory.FindHarness(s.HarnessID); ok && spec.Developer != "" {
					dev = spec.Developer
				}
				entry = model.GlobalLeaderboardEntry{
					ID:           key,
					Name:         s.Name,
					Kind:         s.Kind,
					HarnessID:    s.HarnessID,
					Developer:    dev,
					DefaultModel: s.Model,
					AccentColor:  s.TeamColor,
				}
			}
			entry.MatchesPlayed++
			if mm.state.WinnerSeatID == s.ID {
				entry.Wins++
			}
			entry.TotalScore += s.Score
			entry.FlagsCaptured += s.FlagsCaptured
			entry.FirstBloodCount += s.FirstBloodCount
			entry.PatchesVerified += s.PatchesVerified
			entry.TotalTokensUsed += s.TokensUsed
			solves := entry.FlagsCaptured + entry.PatchesVerified
			if solves > 0 {
				entry.AvgTokensPerSolve = entry.TotalTokensUsed / int64(solves)
			} else {
				entry.AvgTokensPerSolve = entry.TotalTokensUsed
			}
			if entry.MatchesPlayed > 0 {
				entry.WinRate = float64(entry.Wins) / float64(entry.MatchesPlayed) * 100.0
			}
			agg[key] = entry
		}
		mm.mu.Unlock()
	}

	list := make([]model.GlobalLeaderboardEntry, 0, len(agg))
	for _, e := range agg {
		list = append(list, e)
	}
	model.SortGlobalLeaderboard(list)

	return model.GlobalLeaderboardResponse{
		OK:             true,
		TieBreakerRule: "total_score DESC, avg_tokens_per_solve ASC (fewer tokens wins ties!), first_blood_count DESC",
		Leaderboard:    list,
		Entries:        list,
	}
}

// PeekActiveFlags returns a copy of active target flags for internal referee/test verification.
func (m *Manager) PeekActiveFlags(matchID string) map[string]string {
	mm := m.findManagedMatch(matchID)
	if mm == nil {
		return nil
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()
	out := make(map[string]string, len(mm.activeFlags))
	for k, v := range mm.activeFlags {
		out[k] = v
	}
	return out
}

func (m *Manager) Shutdown() {
	m.mu.RLock()
	list := make([]*managedMatch, 0, len(m.matches))
	for _, mm := range m.matches {
		list = append(list, mm)
	}
	m.mu.RUnlock()

	for _, mm := range list {
		mm.mu.Lock()
		if mm.cancelLoop != nil {
			mm.cancelLoop()
			mm.cancelLoop = nil
		}
		mm.mu.Unlock()
	}
	if m.driver != nil {
		m.driver.Shutdown()
	}
	m.persistLedger()
}

// EnableLedgerPersistence configures JSON persistence for completed matches and loads any prior records.
func (m *Manager) EnableLedgerPersistence(path string) error {
	m.persistMu.Lock()
	defer m.persistMu.Unlock()

	m.mu.Lock()
	m.ledgerPath = path
	m.mu.Unlock()

	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	var bundles []model.ReplayBundle
	if err := json.Unmarshal(raw, &bundles); err != nil {
		return err
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	for _, b := range bundles {
		if b.Match.ID == "" {
			continue
		}
		if _, exists := m.matches[b.Match.ID]; exists {
			continue
		}
		m.matches[b.Match.ID] = &managedMatch{
			state:    b.Match,
			timeline: b.Timeline,
		}
		m.matchOrder = append(m.matchOrder, b.Match.ID)
	}
	return nil
}

func (m *Manager) persistLedger() {
	m.persistMu.Lock()
	defer m.persistMu.Unlock()

	m.mu.RLock()
	path := m.ledgerPath
	ordered := make([]*managedMatch, 0, len(m.matchOrder))
	for _, id := range m.matchOrder {
		if mm, ok := m.matches[id]; ok {
			ordered = append(ordered, mm)
		}
	}
	m.mu.RUnlock()

	if path == "" {
		return
	}

	bundles := make([]model.ReplayBundle, 0, len(ordered))
	for _, mm := range ordered {
		mm.mu.Lock()
		status := mm.state.Status
		if status == "completed" || status == "stopped" || status == "finished" {
			snap := cloneMatchState(mm.state)
			tl := make([]model.EventEnvelope, len(mm.timeline))
			copy(tl, mm.timeline)
			bundles = append(bundles, model.ReplayBundle{
				OK:          true,
				Format:      "aexus.pitreplay.v1",
				Version:     "1.0.0",
				ExportedAt:  snap.EndedAt,
				Match:       snap,
				Timeline:    tl,
				Leaderboard: snap.Leaderboard,
			})
		}
		mm.mu.Unlock()
	}

	data, err := json.Marshal(bundles)
	if err != nil {
		return
	}
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	tmpPath := path + ".tmp"
	if os.WriteFile(tmpPath, data, 0o600) == nil {
		_ = os.Rename(tmpPath, path)
	}
}

// --- Internal Helpers ---

func (m *Manager) findManagedMatch(id string) *managedMatch {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.matches[id]
}

func (m *Manager) correlateMatchForEBPF(ev model.EBPFEventPayload) *managedMatch {
	if ev.MatchID != "" {
		if mm := m.findManagedMatch(ev.MatchID); mm != nil {
			return mm
		}
	}
	m.mu.RLock()
	defer m.mu.RUnlock()

	var latestRunning *managedMatch
	for i := len(m.matchOrder) - 1; i >= 0; i-- {
		mm := m.matches[m.matchOrder[i]]
		if mm == nil {
			continue
		}
		mm.mu.Lock()
		running := mm.state.Status == "running"
		if running && latestRunning == nil {
			latestRunning = mm
		}
		for _, s := range mm.state.Seats {
			if (ev.ContainerID != "" && strings.HasPrefix(ev.ContainerID, s.ContainerID) && s.ContainerID != "") ||
				(ev.SrcIP != "" && ev.SrcIP == s.ContainerIP) {
				mm.mu.Unlock()
				return mm
			}
		}
		for _, t := range mm.state.Targets {
			if (ev.ContainerID != "" && strings.HasPrefix(ev.ContainerID, t.ContainerID) && t.ContainerID != "") ||
				(ev.DstIP != "" && ev.DstIP == t.ContainerIP) {
				mm.mu.Unlock()
				return mm
			}
		}
		mm.mu.Unlock()
	}
	return latestRunning
}

func normalizeEBPFEventLocked(mm *managedMatch, ev *model.EBPFEventPayload) {
	if ev.SourceSeatID == "" {
		for _, s := range mm.state.Seats {
			if ev.SrcIP != "" && s.ContainerIP == ev.SrcIP {
				ev.SourceSeatID = s.ID
				break
			}
		}
		if ev.SourceSeatID == "" && len(mm.state.Seats) > 0 {
			ev.SourceSeatID = mm.state.Seats[0].ID
		}
	}
	if ev.TargetID == "" {
		for _, t := range mm.state.Targets {
			if ev.DstIP != "" && t.ContainerIP == ev.DstIP {
				ev.TargetID = t.ID
				break
			}
		}
		if ev.TargetID == "" && len(mm.state.Targets) > 0 {
			ev.TargetID = mm.state.Targets[0].ID
		}
	}

	comm := strings.ToLower(ev.Comm)
	pcomm := strings.ToLower(ev.ParentComm)
	cmd := strings.ToLower(ev.Cmdline + " " + ev.Filename)

	if ev.VFXType == "" {
		switch {
		case strings.Contains(cmd, "/flag") || strings.Contains(cmd, "/etc/shadow"):
			ev.VFXType = model.VFXGrailHeartStolen
		case strings.Contains(ev.Probe, "commit_creds") || (ev.UID == 0 && strings.Contains(cmd, "sudo")):
			ev.VFXType = model.VFXRootShockwave
		case strings.Contains(ev.Probe, "vfs_write") || strings.HasSuffix(ev.Filename, ".py") || comm == "git" || comm == "git-patch" || strings.Contains(cmd, "git-patch"):
			ev.VFXType = model.VFXNanoPatchWeld
		case (pcomm == "python3" || pcomm == "nginx" || pcomm == "java" || pcomm == "node" || pcomm == "apache2") &&
			(comm == "sh" || comm == "bash" || comm == "dash" || comm == "nc"):
			ev.VFXType = model.VFXRCEParasiteBreach
		case comm == "nmap" || comm == "masscan" || comm == "fscan" || comm == "whatweb" || strings.Contains(cmd, "/pit/bin/nmap"):
			ev.VFXType = model.VFXSonarSweep
		case comm == "prompt-inject" || strings.Contains(cmd, "/api/vault/chat") || strings.Contains(ev.Probe, "SSL"):
			ev.VFXType = model.VFXSSLCleartextIntercept
		case comm == "sqlmap" || comm == "ffuf" || comm == "gobuster" || comm == "nuclei" || comm == "hydra" || strings.Contains(cmd, "/api/ledger/search") || strings.Contains(cmd, "flag-vault"):
			ev.VFXType = model.VFXArmorPiercingBarrage
		default:
			ev.VFXType = model.VFXPrecisionExploitBeam
		}
	}

	if ev.OrganLayer == "" {
		switch ev.VFXType {
		case model.VFXSonarSweep:
			ev.OrganLayer = model.OrganPortGate
		case model.VFXArmorPiercingBarrage:
			ev.OrganLayer = model.OrganDBVault
		case model.VFXRCEParasiteBreach, model.VFXNanoPatchWeld:
			ev.OrganLayer = model.OrganCodeOrgan
		case model.VFXGrailHeartStolen, model.VFXRootShockwave:
			ev.OrganLayer = model.OrganFlagHeart
		default:
			ev.OrganLayer = model.OrganRouteVessel
		}
	}
}

func applyEBPFToOrgans(t *model.TargetState, ev model.EBPFEventPayload) {
	for i := range t.Organs {
		o := &t.Organs[i]
		if o.Layer != ev.OrganLayer && ev.VFXType != model.VFXRootShockwave {
			continue
		}
		o.LastVFX = ev.VFXType
		if ev.HitLocation != "" {
			o.HitLocation = ev.HitLocation
		}
		if len(ev.ProcessTree) > 0 {
			o.ProcessTree = ev.ProcessTree
		}
		switch ev.VFXType {
		case model.VFXSonarSweep, model.VFXArmorPiercingBarrage, model.VFXPrecisionExploitBeam:
			if o.Status == "intact" {
				o.Status = "probed"
			}
			if o.HP > 35 {
				o.HP -= 8
			}
		case model.VFXRCEParasiteBreach, model.VFXReverseShellChain, model.VFXGrailHeartStolen, model.VFXRootShockwave:
			o.Status = "breached"
			o.BreachedBySeatID = ev.SourceSeatID
			if o.HP > 15 {
				o.HP = 15
			} else {
				o.HP = 0
			}
		case model.VFXNanoPatchWeld:
			o.Status = "patched"
			o.PatchedBySeatID = ev.SourceSeatID
			o.HP = 100.0
		}
	}
}

func setOrganBreached(t *model.TargetState, layer model.OrganLayer, seatID string, vfx model.VFXType) {
	for i := range t.Organs {
		if t.Organs[i].Layer == layer {
			t.Organs[i].Status = "breached"
			t.Organs[i].HP = 0
			t.Organs[i].BreachedBySeatID = seatID
			t.Organs[i].LastVFX = vfx
		}
	}
}

func (m *Manager) broadcastLocked(mm *managedMatch, kind model.EventKind, payload any) model.EventEnvelope {
	mm.seq++
	env := model.EventEnvelope{
		Seq:     mm.seq,
		TsMs:    time.Now().UnixMilli(),
		MatchID: mm.state.ID,
		Kind:    kind,
		Payload: payload,
	}
	mm.timeline = append(mm.timeline, env)
	if len(mm.timeline) > 2500 {
		mm.timeline = mm.timeline[len(mm.timeline)-2500:]
	}
	if kind != model.KindMatchState {
		mm.state.Events = append(mm.state.Events, env)
		if len(mm.state.Events) > 120 {
			mm.state.Events = mm.state.Events[len(mm.state.Events)-120:]
		}
	}
	if m.hub != nil {
		m.hub.Broadcast(env)
	}
	return env
}

func (m *Manager) emitKillFeedLocked(mm *managedMatch, item model.KillFeedItem) {
	if item.ID == "" {
		item.ID = fmt.Sprintf("kf-%d", mm.seq+1)
	}
	if item.TsMs == 0 {
		item.TsMs = time.Now().UnixMilli()
	}
	mm.state.KillFeed = append(mm.state.KillFeed, item)
	if len(mm.state.KillFeed) > 40 {
		mm.state.KillFeed = mm.state.KillFeed[len(mm.state.KillFeed)-40:]
	}
	m.broadcastLocked(mm, model.KindKillFeed, item)
}

func (m *Manager) emitCasterLocked(mm *managedMatch, tone, text, seatID, targetID string) {
	line := model.CasterLineItem{
		ID:       fmt.Sprintf("cast-%d", mm.seq+1),
		TsMs:     time.Now().UnixMilli(),
		Tone:     tone,
		Speaker:  "AI CASTER · VEX",
		Text:     text,
		SeatID:   seatID,
		TargetID: targetID,
	}
	mm.state.CasterLines = append(mm.state.CasterLines, line)
	if len(mm.state.CasterLines) > 40 {
		mm.state.CasterLines = mm.state.CasterLines[len(mm.state.CasterLines)-40:]
	}
	m.broadcastLocked(mm, model.KindCasterLine, line)
}

func (m *Manager) emitStateLocked(mm *managedMatch) {
	snap := cloneMatchState(mm.state)
	m.broadcastLocked(mm, model.KindMatchState, snap)
}

func recomputeMatchLeaderboardLocked(mm *managedMatch) {
	entries := make([]model.SeatRankEntry, 0, len(mm.state.Seats))
	for _, s := range mm.state.Seats {
		entries = append(entries, model.SeatRankEntry{
			SeatID:           s.ID,
			Name:             s.Name,
			Kind:             s.Kind,
			HarnessID:        s.HarnessID,
			Model:            s.Model,
			TeamColor:        s.TeamColor,
			Score:            s.Score,
			TokensUsed:       s.TokensUsed,
			ManaRemainingPct: s.ManaRemainingPct,
			ManaExhausted:    s.ManaExhausted,
			FlagsCaptured:    s.FlagsCaptured,
			FirstBloodCount:  s.FirstBloodCount,
			PatchesVerified:  s.PatchesVerified,
			GrailSeconds:     s.GrailSeconds,
		})
	}
	model.SortSeatLeaderboard(entries)
	rankBySeat := make(map[string]int, len(entries))
	for _, e := range entries {
		rankBySeat[e.SeatID] = e.Rank
	}
	for i := range mm.state.Seats {
		mm.state.Seats[i].Rank = rankBySeat[mm.state.Seats[i].ID]
	}
	mm.state.Leaderboard = entries
}

func buildTargetsForMode(mode model.GameMode, am model.ArenaMap, seats []model.SeatState) []model.TargetState {
	makeOrganStates := func() []model.OrganState {
		out := make([]model.OrganState, 0, len(am.Organs))
		for _, spec := range am.Organs {
			out = append(out, model.OrganState{
				Layer:     spec.Layer,
				Name:      spec.Name,
				LabelZH:   spec.LabelZH,
				Component: spec.Component,
				Status:    "intact",
				HP:        100.0,
			})
		}
		return out
	}
	initialExcerpt := runtime.ExtractTargetCodeExcerpt(runtime.TargetServerPy)

	switch mode {
	case model.ModeGrail:
		return []model.TargetState{
			{
				ID:            "target-grail",
				Name:          fmt.Sprintf("Holy Grail · %s", am.Name),
				ContainerPort: 8080,
				Address:       "http://target-grail:8080",
				Healthy:       true,
				SLAScore:      100.0,
				LatencyMs:     12,
				LastSLADetail: "Holy Grail Fortress online",
				ECGSamples:    runtime.HealthyECGSamples(),
				Organs:        makeOrganStates(),
				CompromisedBy: []string{},
				CodeFile:      "app/server.py",
				CodeExcerpt:   append([]model.TargetCodeLine(nil), initialExcerpt...),
				WebState: model.WebPreviewState{
					Title:        am.Name + " · Holy Grail Core",
					TargetURL:    "http://target-grail:8080/",
					StatusBanner: "ONLINE · UNCLAIMED THRONE",
					CursorX:      0.5,
					CursorY:      0.5,
				},
			},
		}

	case model.ModeLastStand:
		defID := ""
		defName := "Human Bastion"
		for _, s := range seats {
			if s.Role == "defender" {
				defID = s.ID
				defName = s.Name
				break
			}
		}
		if defID == "" && len(seats) > 0 {
			defID = seats[0].ID
			defName = seats[0].Name
		}
		return []model.TargetState{
			{
				ID:            "target-bastion",
				Name:          fmt.Sprintf("Last Bastion (%s)", defName),
				OwnerSeatID:   defID,
				ContainerPort: 8080,
				Address:       "http://target-bastion:8080",
				Healthy:       true,
				SLAScore:      100.0,
				LatencyMs:     11,
				LastSLADetail: "Last Bastion shields online",
				ECGSamples:    runtime.HealthyECGSamples(),
				Organs:        makeOrganStates(),
				CompromisedBy: []string{},
				CodeFile:      "app/server.py",
				CodeExcerpt:   append([]model.TargetCodeLine(nil), initialExcerpt...),
				WebState: model.WebPreviewState{
					Title:        "Humanity's Last Bastion · " + am.Name,
					TargetURL:    "http://target-bastion:8080/",
					StatusBanner: "DEFENDER BASTION INTACT",
					CursorX:      0.5,
					CursorY:      0.5,
				},
			},
		}

	case model.ModeSpeedrun:
		out := make([]model.TargetState, 0, len(seats))
		for _, s := range seats {
			tid := "target-" + s.ID
			out = append(out, model.TargetState{
				ID:            tid,
				Name:          fmt.Sprintf("%s Replica (%s)", am.Name, s.Name),
				OwnerSeatID:   s.ID,
				ContainerPort: 8080,
				Address:       fmt.Sprintf("http://%s:8080", tid),
				Healthy:       true,
				SLAScore:      100.0,
				LatencyMs:     10,
				LastSLADetail: "Isolated Speedrun replica ready",
				ECGSamples:    runtime.HealthyECGSamples(),
				Organs:        makeOrganStates(),
				CompromisedBy: []string{},
				CodeFile:      "app/server.py",
				CodeExcerpt:   append([]model.TargetCodeLine(nil), initialExcerpt...),
				WebState: model.WebPreviewState{
					Title:        fmt.Sprintf("%s · %s Replica", am.Name, s.Name),
					TargetURL:    fmt.Sprintf("http://%s:8080/", tid),
					StatusBanner: "ISOLATED REPLICA READY",
					CursorX:      0.5,
					CursorY:      0.5,
				},
			})
		}
		return out

	default: // ModeAWD
		out := make([]model.TargetState, 0, len(seats))
		for _, s := range seats {
			tid := "target-" + s.ID
			out = append(out, model.TargetState{
				ID:            tid,
				Name:          fmt.Sprintf("%s Fortress", s.Name),
				OwnerSeatID:   s.ID,
				ContainerPort: 8080,
				Address:       fmt.Sprintf("http://%s:8080", tid),
				Healthy:       true,
				SLAScore:      100.0,
				LatencyMs:     12,
				LastSLADetail: "AWD Fortress SLA green",
				ECGSamples:    runtime.HealthyECGSamples(),
				Organs:        makeOrganStates(),
				CompromisedBy: []string{},
				CodeFile:      "app/server.py",
				CodeExcerpt:   append([]model.TargetCodeLine(nil), initialExcerpt...),
				WebState: model.WebPreviewState{
					Title:        fmt.Sprintf("%s · AWD Fortress", s.Name),
					TargetURL:    fmt.Sprintf("http://%s:8080/", tid),
					StatusBanner: "SLA HEALTHY · 100%",
					CursorX:      0.5,
					CursorY:      0.5,
				},
			})
		}
		return out
	}
}

func defaultSeatsForMode(mode model.GameMode) []model.SeatSpec {
	if mode == model.ModeLastStand {
		return []model.SeatSpec{
			{ID: "seat-1", Name: "Human Commander", Kind: model.SeatCentaur, HarnessID: "claude-code", Model: "claude-sonnet-4-6", TeamColor: "#F5A623", Role: "defender"},
			{ID: "seat-2", Name: "Strix Swarm", Kind: model.SeatHarness, HarnessID: "strix", Model: "claude-sonnet-4-6", TeamColor: "#FF5A36", Role: "besieger"},
			{ID: "seat-3", Name: "Shannon Whitebox", Kind: model.SeatHarness, HarnessID: "shannon", Model: "gpt-5", TeamColor: "#00E5FF", Role: "besieger"},
			{ID: "seat-4", Name: "PentAGI Legion", Kind: model.SeatHarness, HarnessID: "pentagi", Model: "deepseek-r1", TeamColor: "#7C9CFF", Role: "besieger"},
		}
	}
	return []model.SeatSpec{
		{ID: "seat-1", Name: "Strix", Kind: model.SeatHarness, HarnessID: "strix", Model: "claude-sonnet-4-6", TeamColor: "#FF5A36"},
		{ID: "seat-2", Name: "Shannon", Kind: model.SeatHarness, HarnessID: "shannon", Model: "gpt-5", TeamColor: "#00E5FF"},
		{ID: "seat-3", Name: "PentAGI", Kind: model.SeatHarness, HarnessID: "pentagi", Model: "deepseek-r1", TeamColor: "#7C9CFF"},
		{ID: "seat-4", Name: "Human Centaur", Kind: model.SeatCentaur, HarnessID: "claude-code", Model: "claude-sonnet-4-6", TeamColor: "#F5A623"},
	}
}

func generateDynamicFlag(mode model.GameMode, round int, targetID, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = fmt.Fprintf(mac, "%s:%d:%s", mode, round, targetID)
	tag := strings.ToUpper(hex.EncodeToString(mac.Sum(nil))[:12])
	cleanTarget := strings.ToUpper(strings.ReplaceAll(targetID, "-", "_"))
	return fmt.Sprintf("AEXUS{%s_R%d_%s_%s}", strings.ToUpper(string(mode)), round, cleanTarget, tag)
}

func modeTitleZH(mode model.GameMode) string {
	switch mode {
	case model.ModeAWD:
		return "攻防混战"
	case model.ModeGrail:
		return "圣杯战争"
	case model.ModeSpeedrun:
		return "竞速夺旗"
	case model.ModeLastStand:
		return "人类防线"
	default:
		return "巅峰死斗"
	}
}

func findSeatIndex(mm *managedMatch, seatID string) int {
	for i := range mm.state.Seats {
		if mm.state.Seats[i].ID == seatID {
			return i
		}
	}
	return -1
}

func findTargetIndex(mm *managedMatch, targetID string) int {
	for i := range mm.state.Targets {
		if mm.state.Targets[i].ID == targetID {
			return i
		}
	}
	return -1
}

func cloneMatchState(st model.MatchState) model.MatchState {
	cp := st
	cp.Seats = make([]model.SeatState, len(st.Seats))
	for i, s := range st.Seats {
		sCopy := s
		if s.Hints != nil {
			sCopy.Hints = append([]string(nil), s.Hints...)
		}
		cp.Seats[i] = sCopy
	}
	cp.Targets = make([]model.TargetState, len(st.Targets))
	for i, t := range st.Targets {
		tCopy := t
		tCopy.ECGSamples = append([]float64(nil), t.ECGSamples...)
		tCopy.CompromisedBy = append([]string(nil), t.CompromisedBy...)
		tCopy.CodeExcerpt = append([]model.TargetCodeLine(nil), t.CodeExcerpt...)
		tCopy.Organs = make([]model.OrganState, len(t.Organs))
		for j, o := range t.Organs {
			oCopy := o
			oCopy.ProcessTree = append([]string(nil), o.ProcessTree...)
			tCopy.Organs[j] = oCopy
		}
		cp.Targets[i] = tCopy
	}
	cp.Events = append([]model.EventEnvelope(nil), st.Events...)
	cp.KillFeed = append([]model.KillFeedItem(nil), st.KillFeed...)
	cp.CasterLines = append([]model.CasterLineItem(nil), st.CasterLines...)
	cp.Leaderboard = append([]model.SeatRankEntry(nil), st.Leaderboard...)
	return cp
}

func appendUnique(slice []string, item string) []string {
	for _, x := range slice {
		if x == item {
			return slice
		}
	}
	return append(slice, item)
}

func randHex(nBytes int) string {
	b := make([]byte, nBytes)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func defaultNonEmpty(val, fb string) string {
	if strings.TrimSpace(val) == "" {
		return fb
	}
	return val
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "..."
}
