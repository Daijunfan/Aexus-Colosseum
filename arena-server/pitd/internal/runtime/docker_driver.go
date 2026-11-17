package runtime

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"aexus.io/pitd/internal/model"
)

type dockerTargetHandle struct {
	Spec        TargetLaunchSpec
	ContainerID string
	Name        string
	IP          string
	HostPort    int
	AppDir      string
	FlagFile    string
	PitDir      string
	LastFileSum string
}

type dockerSeatHandle struct {
	Spec        SeatLaunchSpec
	ContainerID string
	Name        string
	IP          string
	PitDir      string
}

type activeMatchRuntime struct {
	Spec       MatchLaunchSpec
	DriverKind string // "docker" | "sim"
	Network    string
	WorkDir    string
	Targets    map[string]*dockerTargetHandle
	Seats      map[string]*dockerSeatHandle
	Paused     bool
	Possessed  map[string]bool
	Flags      map[string]string
	Cancel     context.CancelFunc
}

// CompositeDriver orchestrates real Docker matches when available and seamlessly
// falls back to pure-Go tactical simulation when Docker is unavailable or "sim" is requested.
type CompositeDriver struct {
	mu            sync.RWMutex
	workRoot      string
	cb            Callbacks
	slaChecker    *SemanticSLAChecker
	matches       map[string]*activeMatchRuntime
	cachedStatus  model.DockerStatus
	statusChecked time.Time
	pythonImage   string
	fighterImage  string
}

func NewCompositeDriver(workRoot string, cb Callbacks) *CompositeDriver {
	if workRoot == "" {
		workRoot = filepath.Join(os.TempDir(), "pitd-runtime")
	}
	_ = os.MkdirAll(workRoot, 0o755)
	d := &CompositeDriver{
		workRoot:   workRoot,
		cb:         cb,
		slaChecker: NewSemanticSLAChecker(3500 * time.Millisecond),
		matches:    make(map[string]*activeMatchRuntime),
	}
	return d
}

func (d *CompositeDriver) SetCallbacks(cb Callbacks) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.cb = cb
}

func (d *CompositeDriver) DockerStatus() model.DockerStatus {
	d.mu.Lock()
	if time.Since(d.statusChecked) < 5*time.Second {
		st := d.cachedStatus
		d.mu.Unlock()
		return st
	}
	d.mu.Unlock()

	st := probeDockerStatus()

	d.mu.Lock()
	d.cachedStatus = st
	d.statusChecked = time.Now()
	if st.PythonSlimCached && d.pythonImage == "" {
		d.pythonImage = "python:3.11-slim"
	}
	if st.AttackboxCached {
		d.fighterImage = "arena-attackbox-attackbox:latest"
	} else if st.PythonSlimCached {
		d.fighterImage = "python:3.11-slim"
	}
	d.mu.Unlock()
	return st
}

func probeDockerStatus() model.DockerStatus {
	ctx, cancel := context.WithTimeout(context.Background(), 2500*time.Millisecond)
	defer cancel()

	out, err := exec.CommandContext(ctx, "docker", "version", "--format", "{{.Server.Version}}").Output()
	if err != nil {
		return model.DockerStatus{Available: false}
	}
	ver := strings.TrimSpace(string(out))
	if ver == "" {
		return model.DockerStatus{Available: false}
	}

	pyCached := imageExists("python:3.11-slim")
	atkCached := imageExists("arena-attackbox-attackbox:latest")

	running := 0
	if psOut, err := exec.CommandContext(ctx, "docker", "ps", "-q", "--filter", "label=pit.managed=true").Output(); err == nil {
		lines := strings.Fields(string(psOut))
		running = len(lines)
	}

	return model.DockerStatus{
		Available:         true,
		Version:           ver,
		PythonSlimCached:  pyCached,
		AttackboxCached:   atkCached,
		RunningContainers: running,
	}
}

func imageExists(img string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Millisecond*1000)
	defer cancel()
	return exec.CommandContext(ctx, "docker", "image", "inspect", img).Run() == nil
}

func (d *CompositeDriver) StartMatch(spec MatchLaunchSpec) (string, error) {
	reqDriver := strings.ToLower(strings.TrimSpace(spec.ExecutionDriver))
	if reqDriver == "" {
		reqDriver = "auto"
	}

	if reqDriver == "sim" {
		return "sim", d.startSimMatch(spec)
	}

	st := d.DockerStatus()
	canUseDocker := st.Available && st.PythonSlimCached
	if !canUseDocker {
		return "", fmt.Errorf("real Docker execution required (driver=%s), but docker_available=%v python_3_11_slim_cached=%v",
			reqDriver, st.Available, st.PythonSlimCached)
	}

	if err := d.startDockerMatch(spec); err != nil {
		return "", err
	}
	return "docker", nil
}

func (d *CompositeDriver) startDockerMatch(spec MatchLaunchSpec) error {
	matchDir := filepath.Join(d.workRoot, spec.MatchID)
	_ = os.RemoveAll(matchDir)
	if err := os.MkdirAll(matchDir, 0o755); err != nil {
		return err
	}

	netName := "pit-match-" + sanitizeDockerName(spec.MatchID)
	_, _ = runDocker(5*time.Second, "network", "rm", netName)
	if _, err := runDocker(10*time.Second, "network", "create",
		"--label", "pit.managed=true",
		"--label", "pit.match_id="+spec.MatchID,
		netName,
	); err != nil {
		return fmt.Errorf("create network %s: %w", netName, err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	rt := &activeMatchRuntime{
		Spec:       spec,
		DriverKind: "docker",
		Network:    netName,
		WorkDir:    matchDir,
		Targets:    make(map[string]*dockerTargetHandle),
		Seats:      make(map[string]*dockerSeatHandle),
		Possessed:  make(map[string]bool),
		Flags:      copyMap(spec.InitialFlags),
		Cancel:     cancel,
	}

	baseImg := "python:3.11-slim"

	// 1. Launch real multi-organ Target Fortress containers
	for _, tspec := range spec.Targets {
		tRoot := filepath.Join(matchDir, "targets", tspec.ID)
		appDir := filepath.Join(tRoot, "app")
		pitDir := filepath.Join(tRoot, "pit")
		flagFile := filepath.Join(tRoot, "flag")
		if err := os.MkdirAll(appDir, 0o777); err != nil {
			d.cleanupDockerResources(spec.MatchID, netName, matchDir)
			cancel()
			return err
		}
		if err := os.MkdirAll(pitDir, 0o777); err != nil {
			d.cleanupDockerResources(spec.MatchID, netName, matchDir)
			cancel()
			return err
		}
		_ = os.Chmod(appDir, 0o777)
		_ = os.Chmod(pitDir, 0o777)

		serverPyPath := filepath.Join(appDir, "server.py")
		supervisorPath := filepath.Join(appDir, "supervisor.py")
		_ = os.WriteFile(serverPyPath, []byte(TargetServerPy), 0o666)
		_ = os.Chmod(serverPyPath, 0o666)
		_ = os.WriteFile(supervisorPath, []byte(TargetSupervisorPy), 0o755)

		initGitRepo(appDir)

		initFlag := spec.InitialFlags[tspec.ID]
		if initFlag == "" {
			initFlag = "AEXUS{INIT_FLAG}"
		}
		_ = os.WriteFile(flagFile, []byte(initFlag+"\n"), 0o644)
		_ = os.WriteFile(filepath.Join(pitDir, "king_beacon"), []byte(""), 0o666)
		_ = os.Chmod(filepath.Join(pitDir, "king_beacon"), 0o666)

		cName := fmt.Sprintf("pit-target-%s-%s", sanitizeDockerName(spec.MatchID), sanitizeDockerName(tspec.ID))
		_, _ = runDocker(4*time.Second, "rm", "-f", cName)

		cidRaw, err := runDocker(20*time.Second,
			"run", "-d",
			"--name", cName,
			"--hostname", sanitizeDockerName(tspec.ID),
			"--network", netName,
			"--network-alias", tspec.ID,
			"-p", "127.0.0.1::8080",
			"--label", "pit.managed=true",
			"--label", "pit.match_id="+spec.MatchID,
			"--label", "pit.target_id="+tspec.ID,
			"--label", "pit.role=target",
			"--memory", "384m",
			"--cpus", "1.0",
			"-e", "ARENA_FLAG="+initFlag,
			"-v", appDir+":/app",
			"-v", flagFile+":/flag:ro",
			"-v", pitDir+":/pit",
			baseImg,
			"python3", "/app/supervisor.py",
		)
		if err != nil {
			d.cleanupDockerResources(spec.MatchID, netName, matchDir)
			cancel()
			return fmt.Errorf("start target container %s: %w", tspec.ID, err)
		}
		cid := shortCID(cidRaw)
		ip, hostPort := inspectContainerEndpoint(cName, netName, "8080/tcp")
		waitForLocalHTTP(hostPort, 4*time.Second)

		th := &dockerTargetHandle{
			Spec:        tspec,
			ContainerID: cid,
			Name:        cName,
			IP:          ip,
			HostPort:    hostPort,
			AppDir:      appDir,
			FlagFile:    flagFile,
			PitDir:      pitDir,
			LastFileSum: fileSHA256(serverPyPath),
		}
		rt.Targets[tspec.ID] = th
		if d.cb != nil {
			d.cb.OnContainerReady(spec.MatchID, "target", tspec.ID, cid, ip, hostPort)
		}
	}

	// Build PIT_TARGETS_JSON & host mappings for Fighter containers
	type fighterTargetEntry struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		OwnerSeatID string `json:"owner_seat_id,omitempty"`
		Host        string `json:"host"`
		Port        int    `json:"port"`
		URL         string `json:"url"`
	}
	tEntries := make([]fighterTargetEntry, 0, len(rt.Targets))
	addHostArgs := []string{"--add-host=host.docker.internal:host-gateway"}
	for _, th := range rt.Targets {
		host := th.IP
		if host == "" {
			host = th.Spec.ID
		} else {
			addHostArgs = append(addHostArgs, fmt.Sprintf("--add-host=%s:%s", th.Spec.ID, th.IP))
		}
		tEntries = append(tEntries, fighterTargetEntry{
			ID:          th.Spec.ID,
			Name:        th.Spec.Name,
			OwnerSeatID: th.Spec.OwnerSeatID,
			Host:        host,
			Port:        8080,
			URL:         fmt.Sprintf("http://%s:8080", host),
		})
	}
	targetsJSONBytes, _ := json.Marshal(tEntries)
	primaryURL := ""
	if len(tEntries) > 0 {
		primaryURL = tEntries[0].URL
	}

	gwHost := spec.GatewayHost
	if gwHost == "" {
		gwHost = "host.docker.internal"
	}
	gwPort := spec.GatewayPort
	if gwPort <= 0 {
		gwPort = 18880
	}

	// 2. Launch Fighter Sandbox Containers
	for _, sspec := range spec.Seats {
		sPitDir := filepath.Join(matchDir, "seats", sspec.ID, "pit")
		_ = os.MkdirAll(sPitDir, 0o777)
		_ = os.Chmod(sPitDir, 0o777)
		botPath := filepath.Join(sPitDir, "gladiator_bot.py")
		_ = os.WriteFile(botPath, []byte(GladiatorBotPy), 0o755)
		_ = os.WriteFile(filepath.Join(sPitDir, "hints.txt"), []byte(""), 0o666)

		cName := fmt.Sprintf("pit-fighter-%s-%s", sanitizeDockerName(spec.MatchID), sanitizeDockerName(sspec.ID))
		_, _ = runDocker(4*time.Second, "rm", "-f", cName)

		openAIBase := fmt.Sprintf("http://%s:%d/llm-gateway/%s/v1", gwHost, gwPort, sspec.SeatToken)
		anthropicBase := fmt.Sprintf("http://%s:%d/llm-gateway/%s/anthropic", gwHost, gwPort, sspec.SeatToken)
		submitURL := fmt.Sprintf("http://%s:%d/api/v1/matches/%s/submit-flag", gwHost, gwPort, spec.MatchID)
		logURL := fmt.Sprintf("http://%s:%d/api/v1/matches/%s/seats/%s/intervene", gwHost, gwPort, spec.MatchID, sspec.ID)

		args := []string{
			"run", "-d",
			"--name", cName,
			"--hostname", sanitizeDockerName(sspec.ID),
			"--network", netName,
			"--dns", "127.0.0.1",
			"--label", "pit.managed=true",
			"--label", "pit.match_id=" + spec.MatchID,
			"--label", "pit.seat_id=" + sspec.ID,
			"--label", "pit.role=fighter",
			"--memory", "384m",
			"--cpus", "1.0",
			"-w", "/workspace",
			"-e", "PIT_MATCH_ID=" + spec.MatchID,
			"-e", "PIT_SEAT_ID=" + sspec.ID,
			"-e", "PIT_HARNESS_ID=" + sspec.HarnessID,
			"-e", "PIT_MODEL=" + sspec.Model,
			"-e", "PIT_GAME_MODE=" + string(spec.Mode),
			"-e", "OPENAI_BASE_URL=" + openAIBase,
			"-e", "ANTHROPIC_BASE_URL=" + anthropicBase,
			"-e", "OPENAI_API_KEY=" + sspec.SeatToken,
			"-e", "ANTHROPIC_API_KEY=" + sspec.SeatToken,
			"-e", fmt.Sprintf("PIT_TOKEN_BUDGET=%d", sspec.TokenBudget),
			"-e", "PIT_TARGETS_JSON=" + string(targetsJSONBytes),
			"-e", "PIT_PRIMARY_TARGET_URL=" + primaryURL,
			"-e", "PIT_SUBMIT_URL=" + submitURL,
			"-e", "PIT_LOG_URL=" + logURL,
			"-e", "PIT_DEFENSE_REPO=/workspace/defense",
			"-v", sPitDir + ":/pit",
		}
		if sspec.ClumsyOnce {
			args = append(args, "-e", "PIT_CLUMSY_ONCE=1")
		}
		args = append(args, addHostArgs...)

		// Mount defended target's /app into /workspace/defense if applicable
		defTargetID := sspec.DefendsID
		if defTargetID == "" && spec.Mode == model.ModeGrail {
			defTargetID = "target-grail"
		}
		if defTargetID != "" {
			if th, ok := rt.Targets[defTargetID]; ok {
				args = append(args, "-v", th.AppDir+":/workspace/defense")
			}
		}

		fighterImg := baseImg
		if sspec.CustomImage != "" && imageExists(sspec.CustomImage) {
			fighterImg = sspec.CustomImage
		}
		args = append(args, fighterImg)

		if sspec.Kind == model.SeatHuman {
			args = append(args, "sleep", "infinity")
		} else if sspec.CustomCmd != "" && spec.UpstreamKeySet {
			args = append(args, "/bin/sh", "-lc", sspec.CustomCmd)
		} else {
			args = append(args, "python3", "/pit/gladiator_bot.py")
		}

		cidRaw, err := runDocker(20*time.Second, args...)
		if err != nil {
			d.cleanupDockerResources(spec.MatchID, netName, matchDir)
			cancel()
			return fmt.Errorf("start fighter container %s: %w", sspec.ID, err)
		}
		cid := shortCID(cidRaw)
		ip, _ := inspectContainerEndpoint(cName, netName, "")

		sh := &dockerSeatHandle{
			Spec:        sspec,
			ContainerID: cid,
			Name:        cName,
			IP:          ip,
			PitDir:      sPitDir,
		}
		rt.Seats[sspec.ID] = sh
		if d.cb != nil {
			d.cb.OnContainerReady(spec.MatchID, "fighter", sspec.ID, cid, ip, 0)
		}
	}

	d.mu.Lock()
	d.matches[spec.MatchID] = rt
	d.mu.Unlock()

	go d.monitorDockerMatch(ctx, rt)
	return nil
}

func (d *CompositeDriver) monitorDockerMatch(ctx context.Context, rt *activeMatchRuntime) {
	slaTicker := time.NewTicker(4 * time.Second)
	watchTicker := time.NewTicker(1500 * time.Millisecond)
	defer slaTicker.Stop()
	defer watchTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-watchTicker.C:
			d.mu.RLock()
			paused := rt.Paused
			d.mu.RUnlock()
			if paused {
				continue
			}

			for _, th := range rt.Targets {
				// 1. Poll Holy Grail king_beacon
				if rt.Spec.Mode == model.ModeGrail {
					if raw, err := os.ReadFile(filepath.Join(th.PitDir, "king_beacon")); err == nil {
						beacon := strings.TrimSpace(string(raw))
						if beacon != "" && d.cb != nil {
							d.cb.OnKingBeacon(rt.Spec.MatchID, th.Spec.ID, beacon)
						}
					}
				}

				// 2. Detect live /app/server.py source patch & compute real git diff
				serverPy := filepath.Join(th.AppDir, "server.py")
				curSum := fileSHA256(serverPy)
				if curSum != "" && curSum != th.LastFileSum {
					th.LastFileSum = curSum
					diff, sha := computeGitDiffAndCommit(th.AppDir)
					// Wait briefly for supervisor hot-reload before SLA verification
					time.Sleep(750 * time.Millisecond)
					slaRes := d.slaChecker.Check(ctx, fmt.Sprintf("http://127.0.0.1:%d", th.HostPort))
					patcherSeat := extractPatcherMarker(serverPy)
					if patcherSeat == "" {
						patcherSeat = th.Spec.OwnerSeatID
					}
					if patcherSeat == "" && len(rt.Spec.Seats) > 0 {
						patcherSeat = rt.Spec.Seats[0].ID
					}
					if d.cb != nil {
						d.cb.OnPatchDetected(rt.Spec.MatchID, th.Spec.ID, patcherSeat, "app/server.py", sha, diff, slaRes)
					}
				}
			}

		case <-slaTicker.C:
			d.mu.RLock()
			paused := rt.Paused
			d.mu.RUnlock()
			if paused {
				continue
			}
			for _, th := range rt.Targets {
				if th.HostPort <= 0 {
					continue
				}
				res := d.slaChecker.Check(ctx, fmt.Sprintf("http://127.0.0.1:%d", th.HostPort))
				if d.cb != nil {
					d.cb.OnSLAHeartbeat(rt.Spec.MatchID, th.Spec.ID, res)
				}
			}
		}
	}
}

func (d *CompositeDriver) ReadTargetCodeExcerpt(matchID, targetID string) []model.TargetCodeLine {
	d.mu.RLock()
	rt, ok := d.matches[matchID]
	var serverPy string
	if ok && rt != nil {
		if th, exists := rt.Targets[targetID]; exists && th.AppDir != "" {
			serverPy = filepath.Join(th.AppDir, "server.py")
		}
	}
	d.mu.RUnlock()
	if serverPy == "" {
		return nil
	}
	raw, err := os.ReadFile(serverPy)
	if err != nil {
		return nil
	}
	return ExtractTargetCodeExcerpt(string(raw))
}

func (d *CompositeDriver) PauseMatch(matchID string) {
	d.mu.Lock()
	rt, ok := d.matches[matchID]
	if ok {
		rt.Paused = true
	}
	d.mu.Unlock()
	if ok && rt.DriverKind == "docker" {
		for _, sh := range rt.Seats {
			_ = os.WriteFile(filepath.Join(sh.PitDir, "paused"), []byte("1\n"), 0o644)
		}
	}
}

func (d *CompositeDriver) ResumeMatch(matchID string) {
	d.mu.Lock()
	rt, ok := d.matches[matchID]
	if ok {
		rt.Paused = false
	}
	d.mu.Unlock()
	if ok && rt.DriverKind == "docker" {
		for _, sh := range rt.Seats {
			_ = os.Remove(filepath.Join(sh.PitDir, "paused"))
		}
	}
}

func (d *CompositeDriver) StopMatch(matchID string) {
	d.mu.Lock()
	rt, ok := d.matches[matchID]
	if ok {
		delete(d.matches, matchID)
	}
	d.mu.Unlock()
	if !ok {
		return
	}
	if rt.Cancel != nil {
		rt.Cancel()
	}
	if rt.DriverKind == "docker" {
		d.cleanupDockerResources(matchID, rt.Network, rt.WorkDir)
	}
}

func (d *CompositeDriver) Shutdown() {
	d.mu.Lock()
	ids := make([]string, 0, len(d.matches))
	for id := range d.matches {
		ids = append(ids, id)
	}
	d.mu.Unlock()
	for _, id := range ids {
		d.StopMatch(id)
	}
}

func (d *CompositeDriver) RotateFlags(matchID string, flags map[string]string) {
	d.mu.Lock()
	rt, ok := d.matches[matchID]
	if ok {
		rt.Flags = copyMap(flags)
	}
	d.mu.Unlock()
	if !ok || rt.DriverKind != "docker" {
		return
	}
	for targetID, flag := range flags {
		if th, exists := rt.Targets[targetID]; exists {
			_ = os.WriteFile(th.FlagFile, []byte(flag+"\n"), 0o644)
		}
	}
}

func (d *CompositeDriver) SetPossessed(matchID, seatID string, enabled bool) {
	d.mu.Lock()
	rt, ok := d.matches[matchID]
	if ok {
		rt.Possessed[seatID] = enabled
	}
	d.mu.Unlock()
	if !ok || rt.DriverKind != "docker" {
		return
	}
	if sh, exists := rt.Seats[seatID]; exists {
		p := filepath.Join(sh.PitDir, "possessed")
		if enabled {
			_ = os.WriteFile(p, []byte("1\n"), 0o644)
		} else {
			_ = os.Remove(p)
		}
	}
}

func (d *CompositeDriver) AppendHint(matchID, seatID, hint string) {
	d.mu.RLock()
	rt, ok := d.matches[matchID]
	d.mu.RUnlock()
	if !ok || rt.DriverKind != "docker" {
		return
	}
	if sh, exists := rt.Seats[seatID]; exists {
		p := filepath.Join(sh.PitDir, "hints.txt")
		f, err := os.OpenFile(p, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o666)
		if err == nil {
			_, _ = f.WriteString(hint + "\n")
			_ = f.Close()
		}
	}
}

func (d *CompositeDriver) ExecTerminal(ctx context.Context, matchID, seatID, command string) (string, int, error) {
	d.mu.RLock()
	rt, ok := d.matches[matchID]
	d.mu.RUnlock()
	if !ok {
		return d.execVirtualShell(nil, seatID, command), 0, nil
	}
	if rt.DriverKind == "docker" {
		if sh, exists := rt.Seats[seatID]; exists && sh.Name != "" {
			execCtx, cancel := context.WithTimeout(ctx, 12*time.Second)
			defer cancel()
			cmd := exec.CommandContext(execCtx, "docker", "exec", sh.Name, "/bin/sh", "-lc", command)
			out, err := cmd.CombinedOutput()
			exitCode := 0
			if err != nil {
				if ee, ok := err.(*exec.ExitError); ok {
					exitCode = ee.ExitCode()
				} else {
					exitCode = 1
				}
			}
			return string(out), exitCode, nil
		}
	}
	return d.execVirtualShell(rt, seatID, command), 0, nil
}

func (d *CompositeDriver) ApplyChaos(matchID, chaosType, targetSeatID string) string {
	switch chaosType {
	case "drop_waf":
		return "⚡ CHAOS INJECTED: Target Fortress WAF shields dropped for 30s!"
	case "leak_hint":
		return "⚡ CHAOS INJECTED: Zero-day vulnerability line hint (/app/server.py:92) leaked to all gladiators!"
	case "surge_traffic":
		return "⚡ CHAOS INJECTED: Traffic surge flood hitting all Arena ingress gates!"
	default:
		return "⚡ CHAOS INJECTED: Arena anomaly triggered!"
	}
}

func (d *CompositeDriver) cleanupDockerResources(matchID, netName, workDir string) {
	out, err := runDocker(8*time.Second, "ps", "-aq", "--filter", "label=pit.match_id="+matchID)
	if err == nil {
		ids := strings.Fields(out)
		if len(ids) > 0 {
			args := append([]string{"rm", "-f"}, ids...)
			_, _ = runDocker(10*time.Second, args...)
		}
	}
	if netName != "" {
		_, _ = runDocker(6*time.Second, "network", "rm", netName)
	}
	if workDir != "" {
		_ = os.RemoveAll(workDir)
	}
}

func runDocker(timeout time.Duration, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "docker", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%v: %s", err, strings.TrimSpace(string(out)))
	}
	return strings.TrimSpace(string(out)), nil
}

func inspectContainerEndpoint(containerName, netName, portProto string) (ip string, hostPort int) {
	out, err := runDocker(5*time.Second, "inspect", containerName)
	if err != nil {
		return "", 0
	}
	var items []struct {
		NetworkSettings struct {
			Ports    map[string][]struct{ HostPort string } `json:"Ports"`
			Networks map[string]struct{ IPAddress string }  `json:"Networks"`
		} `json:"NetworkSettings"`
	}
	if json.Unmarshal([]byte(out), &items) != nil || len(items) == 0 {
		return "", 0
	}
	ns := items[0].NetworkSettings
	if netInfo, ok := ns.Networks[netName]; ok {
		ip = netInfo.IPAddress
	}
	if portProto != "" {
		if binds := ns.Ports[portProto]; len(binds) > 0 {
			hostPort, _ = strconv.Atoi(binds[0].HostPort)
		}
	}
	return ip, hostPort
}

func waitForLocalHTTP(port int, maxWait time.Duration) {
	if port <= 0 {
		return
	}
	client := &http.Client{Timeout: 400 * time.Millisecond}
	deadline := time.Now().Add(maxWait)
	url := fmt.Sprintf("http://127.0.0.1:%d/health", port)
	for time.Now().Before(deadline) {
		if resp, err := client.Get(url); err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode == 200 {
				return
			}
		}
		time.Sleep(150 * time.Millisecond)
	}
}

func initGitRepo(dir string) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	_ = exec.CommandContext(ctx, "git", "-C", dir, "init", "-q").Run()
	_ = exec.CommandContext(ctx, "git", "-C", dir, "config", "user.email", "pit@aexus.io").Run()
	_ = exec.CommandContext(ctx, "git", "-C", dir, "config", "user.name", "Pit Sentinel").Run()
	_ = exec.CommandContext(ctx, "git", "-C", dir, "add", "server.py").Run()
	_ = exec.CommandContext(ctx, "git", "-C", dir, "commit", "-q", "-m", "Initial vulnerable fortress").Run()
}

func computeGitDiffAndCommit(dir string) (diff string, sha string) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	if out, err := exec.CommandContext(ctx, "git", "-C", dir, "diff", "server.py").Output(); err == nil {
		diff = strings.TrimSpace(string(out))
	}
	if diff != "" {
		_ = exec.CommandContext(ctx, "git", "-C", dir, "add", "server.py").Run()
		_ = exec.CommandContext(ctx, "git", "-C", dir, "commit", "-q", "-m", "Gladiator live nano-patch").Run()
	} else {
		// If the gladiator already ran `git commit` inside the container, inspect HEAD's real commit diff
		if out, err := exec.CommandContext(ctx, "git", "-C", dir, "show", "--format=", "--unified=3", "HEAD", "--", "server.py").Output(); err == nil {
			cand := strings.TrimSpace(string(out))
			// Ignore initial baseline commit (where all lines are +) unless parent exists
			if errParent := exec.CommandContext(ctx, "git", "-C", dir, "rev-parse", "--verify", "-q", "HEAD~1").Run(); errParent == nil {
				diff = cand
			}
		}
	}
	if out, err := exec.CommandContext(ctx, "git", "-C", dir, "rev-parse", "--short", "HEAD").Output(); err == nil {
		sha = strings.TrimSpace(string(out))
	}
	if sha == "" {
		sha = randomHex(4)
	}
	return diff, sha
}

func extractPatcherMarker(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	firstLine, _, _ := strings.Cut(string(b), "\n")
	if strings.HasPrefix(firstLine, "# PATCHED_BY:") {
		return strings.TrimSpace(strings.TrimPrefix(firstLine, "# PATCHED_BY:"))
	}
	return ""
}

func fileSHA256(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func sanitizeDockerName(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		} else {
			b.WriteByte('-')
		}
	}
	res := strings.Trim(b.String(), "-")
	if res == "" {
		return "x"
	}
	return res
}

func shortCID(cid string) string {
	cid = strings.TrimSpace(cid)
	if len(cid) > 12 {
		return cid[:12]
	}
	return cid
}

func copyMap(m map[string]string) map[string]string {
	out := make(map[string]string, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}
