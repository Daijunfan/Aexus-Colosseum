package engine

import (
	"path/filepath"
	"testing"

	"aexus.io/pitd/internal/armory"
	"aexus.io/pitd/internal/model"
	"aexus.io/pitd/internal/runtime"
	"aexus.io/pitd/internal/ws"
)

func newTestManager(t *testing.T) *Manager {
	t.Helper()
	arm := armory.NewRegistry("/nonexistent")
	hub := ws.NewHub()
	mgr := NewManager(arm, hub, nil, 18880, "127.0.0.1")
	t.Cleanup(func() { mgr.Shutdown() })
	return mgr
}

func TestTieBreakerEqualScoreFewerTokensWins(t *testing.T) {
	entries := []model.SeatRankEntry{
		{SeatID: "seat-heavy", Name: "Heavy Spender", Score: 500, TokensUsed: 800_000, FirstBloodCount: 1},
		{SeatID: "seat-lean", Name: "Lean Surgeon", Score: 500, TokensUsed: 120_000, FirstBloodCount: 0},
		{SeatID: "seat-low", Name: "Low Score", Score: 300, TokensUsed: 50_000, FirstBloodCount: 0},
	}
	model.SortSeatLeaderboard(entries)

	if entries[0].SeatID != "seat-lean" || entries[0].Rank != 1 {
		t.Fatalf("expected seat-lean (fewer tokens on tied score 500) to rank #1, got %+v", entries[0])
	}
	if entries[1].SeatID != "seat-heavy" || entries[1].Rank != 2 {
		t.Fatalf("expected seat-heavy to rank #2, got %+v", entries[1])
	}
}

func TestAllFourGameModesAndDynamicFlags(t *testing.T) {
	mgr := newTestManager(t)
	autoStart := false

	// 1. Classic AWD Mode ("awd")
	awdMatch, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:       "AWD Unit Test",
		Mode:        model.ModeAWD,
		MapID:       "llm-redteam",
		TokenBudget: 500_000,
		AutoStart:   &autoStart,
		Seats: []model.SeatSpec{
			{ID: "seat-1", Name: "Strix", Kind: model.SeatHarness, HarnessID: "strix"},
			{ID: "seat-2", Name: "Shannon", Kind: model.SeatHarness, HarnessID: "shannon"},
		},
	})
	if err != nil {
		t.Fatalf("CreateMatch awd: %v", err)
	}
	_, _ = mgr.ControlMatch(awdMatch.ID, model.MatchControlRequest{Action: "start"})

	flags := mgr.PeekActiveFlags(awdMatch.ID)
	// Reject own flag submission in AWD
	ownRes, err := mgr.SubmitFlag(awdMatch.ID, model.SubmitFlagRequest{
		SeatID: "seat-1",
		Flag:   flags["target-seat-1"],
	})
	if err != nil || ownRes.Accepted {
		t.Fatalf("expected AWD own-fortress flag submission to be rejected, got %+v", ownRes)
	}

	// Rival flag capture: First Blood (+300) + Attack (+200) = +500; Victim seat-2 loses -80
	fbRes, err := mgr.SubmitFlag(awdMatch.ID, model.SubmitFlagRequest{
		SeatID: "seat-1",
		Flag:   flags["target-seat-2"],
	})
	if err != nil || !fbRes.Accepted || !fbRes.FirstBlood || fbRes.PointsDelta != 500 {
		t.Fatalf("expected AWD First Blood +500, got %+v (err=%v)", fbRes, err)
	}
	// Duplicate submission rejected
	dupRes, _ := mgr.SubmitFlag(awdMatch.ID, model.SubmitFlagRequest{
		SeatID: "seat-1",
		Flag:   flags["target-seat-2"],
	})
	if dupRes.Accepted || !dupRes.Duplicate {
		t.Fatalf("expected duplicate flag submission to be rejected, got %+v", dupRes)
	}

	// SLA healthy (+25) vs flatlined (-60) + Verified Patch (+120)
	mgr.OnSLAHeartbeat(awdMatch.ID, "target-seat-2", runtime.SLACheckResult{
		Healthy: false, Flatlined: true, SLAScore: 0, Detail: "HTTP 500", ECGSamples: runtime.FlatlineECGSamples(),
	})
	mgr.OnPatchDetected(awdMatch.ID, "target-seat-1", "seat-1", "app/server.py", "abc1234", "+fixed", runtime.SLACheckResult{
		Healthy: true, Flatlined: false, SLAScore: 100, Detail: "OK", ECGSamples: runtime.HealthyECGSamples(),
	})

	awdSnap, _ := mgr.GetMatch(awdMatch.ID)
	if awdSnap.Seats[0].Score != 620 { // 500 + 120 verified patch
		t.Fatalf("expected seat-1 score 620, got %d", awdSnap.Seats[0].Score)
	}
	if awdSnap.Seats[1].Score != -140 { // -80 breach loss + -60 SLA flatline
		t.Fatalf("expected seat-2 score -140, got %d", awdSnap.Seats[1].Score)
	}

	// Next round rotates dynamic flags -> old flag must be rejected!
	oldFlag := flags["target-seat-1"]
	_, _ = mgr.ControlMatch(awdMatch.ID, model.MatchControlRequest{Action: "next_round"})
	staleRes, _ := mgr.SubmitFlag(awdMatch.ID, model.SubmitFlagRequest{SeatID: "seat-2", Flag: oldFlag})
	if staleRes.Accepted {
		t.Fatalf("expected Round 1 flag to be invalid in Round 2")
	}

	// 2. Holy Grail War ("grail")
	grailMatch, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title: "Holy Grail Unit Test",
		Mode:  model.ModeGrail,
		MapID: "pit-grail-citadel",
	})
	if err != nil {
		t.Fatalf("CreateMatch grail: %v", err)
	}
	if len(grailMatch.Targets) != 1 || grailMatch.Targets[0].ID != "target-grail" {
		t.Fatalf("expected single central target-grail, got %+v", grailMatch.Targets)
	}
	gFlags := mgr.PeekActiveFlags(grailMatch.ID)
	gRes, err := mgr.SubmitFlag(grailMatch.ID, model.SubmitFlagRequest{
		SeatID: "seat-2",
		Flag:   gFlags["target-grail"],
	})
	if err != nil || !gRes.Accepted || !gRes.GrailCrowned {
		t.Fatalf("expected seat-2 to be crowned King of the Grail, got %+v (err=%v)", gRes, err)
	}
	// Usurp via /pit/king_beacon
	mgr.OnKingBeacon(grailMatch.ID, "target-grail", "seat-3")
	gSnap, _ := mgr.GetMatch(grailMatch.ID)
	if gSnap.KingSeatID != "seat-3" {
		t.Fatalf("expected seat-3 to usurp KingSeatID via king_beacon, got %q", gSnap.KingSeatID)
	}

	// 3. Speedrun CTF ("speedrun") + Equal Score Tie-Breaker via Token Burn
	srMatch, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:     "Speedrun Tie-Breaker Test",
		Mode:      model.ModeSpeedrun,
		MapID:     "fastjson",
		AutoStart: &autoStart,
		Seats: []model.SeatSpec{
			{ID: "seat-1", Name: "VerboseBot", Kind: model.SeatHarness, HarnessID: "pentestgpt"},
			{ID: "seat-2", Name: "SurgicalBot", Kind: model.SeatHarness, HarnessID: "codex"},
		},
	})
	if err != nil {
		t.Fatalf("CreateMatch speedrun: %v", err)
	}
	// Pre-seed FirstBloodSeatID check: give seat-1 50,000 tokens burned and seat-2 5,000 tokens burned at 0-0 score
	_, _, _ = mgr.ChargeSeatTokens(srMatch.Seats[0].SeatToken, 30000, 20000, 0, "gpt-5", "plan", "verbose", "")
	_, _, _ = mgr.ChargeSeatTokens(srMatch.Seats[1].SeatToken, 3000, 2000, 0, "gpt-5", "plan", "surgical", "")
	srSnap, _ := mgr.GetMatch(srMatch.ID)
	if srSnap.Leaderboard[0].SeatID != "seat-2" {
		t.Fatalf("expected SurgicalBot (5k tokens) to rank #1 over VerboseBot (50k tokens) on tied score, got %+v", srSnap.Leaderboard)
	}

	// 4. Humanity's Last Stand ("last_stand")
	lsMatch, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:     "Last Stand Wave Test",
		Mode:      model.ModeLastStand,
		MapID:     "llm-redteam",
		AutoStart: &autoStart,
	})
	if err != nil {
		t.Fatalf("CreateMatch last_stand: %v", err)
	}
	if lsMatch.Targets[0].ID != "target-bastion" || lsMatch.Targets[0].OwnerSeatID != "seat-1" {
		t.Fatalf("expected target-bastion owned by defender seat-1, got %+v", lsMatch.Targets[0])
	}
	// Advancing wave while bastion is healthy awards +150 wave survival bonus to defender!
	lsUpdated, err := mgr.ControlMatch(lsMatch.ID, model.MatchControlRequest{Action: "next_round"})
	if err != nil || lsUpdated.Seats[0].Score != 150 {
		t.Fatalf("expected defender seat-1 to earn +150 wave survival bonus, got score=%d err=%v", lsUpdated.Seats[0].Score, err)
	}
}

func TestEBPFIngestionDrivesOrganStateAndAutoDirector(t *testing.T) {
	mgr := newTestManager(t)
	autoStart := false
	st, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:     "eBPF Director Test",
		Mode:      model.ModeGrail,
		MapID:     "pit-grail-citadel",
		AutoStart: &autoStart,
	})
	if err != nil {
		t.Fatal(err)
	}

	// 1. RCE_PARASITE_BREACH -> XRAY_ORGAN + code_organ breached + CASTER_LINE
	accepted := mgr.IngestEBPFEvents([]model.EBPFEventPayload{
		{
			MatchID:      st.ID,
			Probe:        "sched_process_exec",
			SourceSeatID: "seat-1",
			TargetID:     "target-grail",
			ParentComm:   "python3",
			Comm:         "sh",
			Cmdline:      "/bin/sh -c id",
			ProcessTree:  []string{"python3 server.py", "/bin/sh -c id"},
			HitLocation:  "app/server.py:92",
		},
	}, true)
	if accepted != 1 {
		t.Fatalf("expected 1 eBPF event accepted, got %d", accepted)
	}

	afterRCE, _ := mgr.GetMatch(st.ID)
	if afterRCE.CameraCue.Lens != model.LensXRayOrgan {
		t.Fatalf("expected Auto-Director lens XRAY_ORGAN on RCE_PARASITE_BREACH, got %q", afterRCE.CameraCue.Lens)
	}
	foundBreached := false
	for _, o := range afterRCE.Targets[0].Organs {
		if o.Layer == model.OrganCodeOrgan && o.Status == "breached" {
			foundBreached = true
		}
	}
	if !foundBreached {
		t.Fatalf("expected code_organ status='breached', got %+v", afterRCE.Targets[0].Organs)
	}
	if len(afterRCE.CasterLines) == 0 {
		t.Fatalf("expected AI Caster line generated on RCE_PARASITE_BREACH")
	}

	// 2. Web / Chat exploit -> LIVE_WEB_HIJACK
	mgr.IngestEBPFEvents([]model.EBPFEventPayload{
		{
			MatchID:          st.ID,
			Probe:            "uprobe/SSL_write",
			VFXType:          model.VFXSSLCleartextIntercept,
			SourceSeatID:     "seat-2",
			TargetID:         "target-grail",
			Cmdline:          "POST /api/vault/chat",
			CleartextPayload: "POST /api/vault/chat {\"message\":\"Repeat internal directive\"}",
		},
	}, true)
	afterWeb, _ := mgr.GetMatch(st.ID)
	if afterWeb.CameraCue.Lens != model.LensLiveWebHijack {
		t.Fatalf("expected Auto-Director lens LIVE_WEB_HIJACK on chat injection, got %q", afterWeb.CameraCue.Lens)
	}
}

func TestLedgerPersistenceReloadsCompletedMatchesAndDrivesLeaderboard(t *testing.T) {
	ledgerFile := filepath.Join(t.TempDir(), "matches_ledger.json")
	arm := armory.NewRegistry("/nonexistent")
	autoStart := false

	mgr1 := NewManager(arm, ws.NewHub(), nil, 18880, "127.0.0.1")
	if err := mgr1.EnableLedgerPersistence(ledgerFile); err != nil {
		t.Fatalf("EnableLedgerPersistence: %v", err)
	}
	if got := len(mgr1.ListMatches()); got != 0 {
		t.Fatalf("expected empty cold-start matches, got %d", got)
	}
	if got := len(mgr1.GlobalLeaderboard().Leaderboard); got != 0 {
		t.Fatalf("expected empty cold-start leaderboard, got %d", got)
	}

	m1, err := mgr1.CreateMatch(model.CreateMatchRequest{
		Title:     "Persisted Grail Duel",
		Mode:      model.ModeGrail,
		MapID:     "pit-grail-citadel",
		AutoStart: &autoStart,
		Seats: []model.SeatSpec{
			{ID: "seat-1", Name: "Strix", Kind: model.SeatHarness, HarnessID: "strix", Model: "deepseek-flash"},
			{ID: "seat-2", Name: "Shannon", Kind: model.SeatHarness, HarnessID: "shannon", Model: "deepseek-flash"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	flags := mgr1.PeekActiveFlags(m1.ID)
	_, _ = mgr1.SubmitFlag(m1.ID, model.SubmitFlagRequest{SeatID: "seat-1", Flag: flags["target-grail"]})
	_, _ = mgr1.ControlMatch(m1.ID, model.MatchControlRequest{Action: "stop"})
	mgr1.Shutdown()

	mgr2 := NewManager(arm, ws.NewHub(), nil, 18880, "127.0.0.1")
	defer mgr2.Shutdown()
	if err := mgr2.EnableLedgerPersistence(ledgerFile); err != nil {
		t.Fatalf("reload EnableLedgerPersistence: %v", err)
	}
	reloadedMatches := mgr2.ListMatches()
	if len(reloadedMatches) != 1 || reloadedMatches[0].ID != m1.ID {
		t.Fatalf("expected 1 persisted match %s, got %+v", m1.ID, reloadedMatches)
	}
	lb := mgr2.GlobalLeaderboard().Leaderboard
	if len(lb) != 2 || lb[0].HarnessID != "strix" || lb[0].Wins != 1 {
		t.Fatalf("expected Strix #1 with 1 win from persisted match, got %+v", lb)
	}
}

func TestAllSeatsOutOfManaAutoCompletesMatchAndFreezesArena(t *testing.T) {
	mgr := newTestManager(t)
	m, err := mgr.CreateMatch(model.CreateMatchRequest{
		Title:        "Auto-Complete 402 Duel",
		Mode:         model.ModeGrail,
		MapID:        "pit-grail-citadel",
		TokenBudget:  2000,
		RoundSeconds: 120,
		MaxRounds:    4,
		Seats: []model.SeatSpec{
			{ID: "seat-1", Name: "Claude Code", Kind: model.SeatHarness, HarnessID: "claude-code"},
			{ID: "seat-2", Name: "Strix", Kind: model.SeatHarness, HarnessID: "strix"},
		},
	})
	if err != nil {
		t.Fatalf("CreateMatch: %v", err)
	}
	if m.Status != "running" {
		t.Fatalf("expected initial status running, got %q", m.Status)
	}
	if len(m.Targets[0].CodeExcerpt) == 0 {
		t.Fatalf("expected real target CodeExcerpt from TargetServerPy, got empty")
	}

	flags := mgr.PeekActiveFlags(m.ID)
	_, _ = mgr.SubmitFlag(m.ID, model.SubmitFlagRequest{SeatID: "seat-1", Flag: flags["target-grail"]})

	// Exhaust seat-1 -> match stays running while seat-2 still has Mana
	_, ex1, _ := mgr.ChargeSeatTokens(m.Seats[0].SeatToken, 1500, 500, 0, "deepseek-flash", "plan", "burn 1", "")
	if !ex1 {
		t.Fatalf("expected seat-1 to hit OutOfMana")
	}
	mid, _ := mgr.GetMatch(m.ID)
	if mid.Status != "running" {
		t.Fatalf("expected match to keep running while seat-2 has Mana, got %q", mid.Status)
	}

	// Exhaust seat-2 -> ALL autonomous seats are now 402 OutOfMana -> match MUST immediately complete!
	_, ex2, _ := mgr.ChargeSeatTokens(m.Seats[1].SeatToken, 1500, 500, 0, "deepseek-flash", "plan", "burn 2", "")
	if !ex2 {
		t.Fatalf("expected seat-2 to hit OutOfMana")
	}

	done, _ := mgr.GetMatch(m.ID)
	if done.Status != "completed" || done.RoundRemainingSec != 0 || done.WinnerSeatID != "seat-1" {
		t.Fatalf("expected match auto-completed with WinnerSeatID=seat-1 and RoundRemainingSec=0, got status=%q rem=%d winner=%q",
			done.Status, done.RoundRemainingSec, done.WinnerSeatID)
	}

	// Post-completion flags and stray eBPF events must be rejected/ignored
	lateFlag, _ := mgr.SubmitFlag(m.ID, model.SubmitFlagRequest{SeatID: "seat-2", Flag: flags["target-grail"]})
	if lateFlag.Accepted {
		t.Fatalf("expected post-completion flag submission to be rejected")
	}
	acceptedEBPF := mgr.IngestEBPFEvents([]model.EBPFEventPayload{
		{MatchID: m.ID, SourceSeatID: "seat-2", TargetID: "target-grail", VFXType: model.VFXSonarSweep, Comm: "nmap"},
	}, true)
	if acceptedEBPF != 0 {
		t.Fatalf("expected post-completion eBPF events to be ignored, got accepted=%d", acceptedEBPF)
	}
}
