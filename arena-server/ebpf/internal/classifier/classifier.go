package classifier

import (
	"fmt"
	"path/filepath"
	"strings"
	"unicode"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

// Input aggregates kernel event fields, container resolution, and userspace process lineage.
type Input struct {
	Raw                  model.RawKernelEvent
	SourceContainer      model.ContainerMeta
	DstContainer         *model.ContainerMeta
	InferredTargetID     string
	InferredDstIP        string
	RecentAttackerSeatID string
	RecentAttackerIP     string
	PPID                 uint32
	ParentComm           string
	Cmdline              string
	ProcessTree          []string
}

var (
	sonarTools = map[string]bool{
		"nmap": true, "masscan": true, "rustscan": true, "fscan": true,
		"whatweb": true, "ping": true, "dig": true, "nslookup": true,
		"traceroute": true, "arp-scan": true, "netdiscover": true,
	}

	barrageTools = map[string]bool{
		"sqlmap": true, "ffuf": true, "gobuster": true, "dirsearch": true,
		"feroxbuster": true, "hydra": true, "medusa": true, "nikto": true,
		"nuclei": true, "wfuzz": true, "commix": true, "dalfox": true,
		"xsstrike": true,
	}

	exploitTools = map[string]bool{
		"curl": true, "wget": true, "python": true, "python3": true,
		"msfconsole": true, "msfvenom": true, "ruby": true, "perl": true,
		"php": true, "exploit": true, "pwntools": true, "socat": true,
		"nc": true, "ncat": true, "netcat": true, "prompt-inject": true,
	}

	targetServiceProcs = map[string]bool{
		"python": true, "python3": true, "gunicorn": true, "uvicorn": true,
		"flask": true, "celery": true, "java": true, "node": true,
		"nodejs": true, "deno": true, "bun": true, "nginx": true,
		"apache2": true, "httpd": true, "php": true, "php-fpm": true,
		"php-cgi": true, "ruby": true, "puma": true, "tomcat": true,
	}

	rceSpawnedBins = map[string]bool{
		"sh": true, "bash": true, "dash": true, "zsh": true, "ash": true, "ksh": true,
		"nc": true, "ncat": true, "netcat": true, "socat": true,
		"whoami": true, "id": true,
	}

	reverseShellPorts = map[uint16]bool{
		4444: true, 4443: true, 1337: true, 9001: true, 9002: true,
		5555: true, 6666: true, 7777: true, 8888: true, 9999: true, 31337: true,
	}

	reverseShellComms = map[string]bool{
		"sh": true, "bash": true, "dash": true, "zsh": true,
		"nc": true, "ncat": true, "netcat": true, "socat": true,
		"python": true, "python3": true, "perl": true, "ruby": true, "php": true,
	}

	arbiterComms = map[string]bool{
		"pit-arbiter": true, "pitd": true, "arenactl": true, "flag-rotator": true,
	}

	sourceCodeExts = map[string]bool{
		".py": true, ".js": true, ".ts": true, ".tsx": true, ".jsx": true,
		".php": true, ".go": true, ".java": true, ".rb": true, ".rs": true,
		".c": true, ".cpp": true, ".h": true, ".conf": true, ".yaml": true,
		".yml": true, ".toml": true, ".ini": true, ".sql": true, ".html": true,
	}
)

// Classify deterministically maps a container-scoped kernel event into a canonical EBPFEventPayload.
func Classify(in Input) (model.EBPFEventPayload, bool) {
	raw := in.Raw
	src := in.SourceContainer

	comm := strings.TrimSpace(raw.Comm)
	binBase := strings.ToLower(filepath.Base(strings.TrimSpace(raw.Filename)))
	if binBase == "." || binBase == "/" || binBase == "" {
		binBase = strings.ToLower(comm)
	}
	lowerComm := strings.ToLower(comm)
	parentComm := strings.TrimSpace(in.ParentComm)
	lowerParent := strings.ToLower(parentComm)
	cmdline := strings.TrimSpace(in.Cmdline)
	if cmdline == "" {
		cmdline = raw.Cmdline()
	}

	out := model.EBPFEventPayload{
		Probe:           raw.ProbeName(),
		CgroupID:        raw.CgroupID,
		PID:             raw.PID,
		PPID:            in.PPID,
		UID:             raw.UID,
		Comm:            comm,
		ParentComm:      parentComm,
		Cmdline:         cmdline,
		Filename:        raw.Filename,
		Flags:           raw.Flags,
		SrcIP:           src.PrimaryIP,
		DstIP:           raw.DstIP,
		DstPort:         raw.DstPort,
		ProcessTree:     in.ProcessTree,
		KernelTsNs:      raw.TimestampNs,
		KernelLatencyNs: raw.DurationNs,
	}

	// Default seat/target attribution based on container role & cross-container context
	if src.Role == model.RoleFighter {
		out.SourceSeatID = src.SeatID
		if in.DstContainer != nil && in.DstContainer.TargetID != "" {
			out.TargetID = in.DstContainer.TargetID
		} else if in.InferredTargetID != "" {
			out.TargetID = in.InferredTargetID
			if out.DstIP == "" {
				out.DstIP = in.InferredDstIP
			}
		}
	} else {
		out.TargetID = src.TargetID
		if in.DstContainer != nil && in.DstContainer.Role == model.RoleFighter {
			out.SourceSeatID = in.DstContainer.SeatID
		} else if in.RecentAttackerSeatID != "" {
			out.SourceSeatID = in.RecentAttackerSeatID
		} else if src.SeatID != "" {
			out.SourceSeatID = src.SeatID
		}
	}

	switch raw.EventType {
	case model.RawEventPrivesc:
		if raw.UID != 0 && raw.TargetUID == 0 {
			out.VFXType = model.VFXRootShockwave
			out.OrganLayer = model.OrganFlagHeart
			out.HitLocation = fmt.Sprintf("uid:%d->0", raw.UID)
			return out, true
		}
		return model.EBPFEventPayload{}, false

	case model.RawEventSSLWrite, model.RawEventSSLRead:
		if strings.Contains(cmdline, "18880") || strings.Contains(cmdline, "llm-gateway") {
			return model.EBPFEventPayload{}, false
		}
		clean, printable := sanitizeCleartext(raw.Payload)
		if printable < 4 {
			return model.EBPFEventPayload{}, false
		}
		out.VFXType = model.VFXSSLCleartextIntercept
		out.CleartextPayload = clean
		if strings.Contains(clean, "AEXUS{") || strings.Contains(clean, "/flag") {
			out.OrganLayer = model.OrganFlagHeart
		} else {
			out.OrganLayer = model.OrganRouteVessel
		}
		out.HitLocation = extractSSLHitLocation(clean, out.Probe)
		return out, true

	case model.RawEventOpenat:
		if arbiterComms[lowerComm] {
			return model.EBPFEventPayload{}, false
		}
		path := strings.TrimSpace(raw.Filename)
		if path == "" {
			return model.EBPFEventPayload{}, false
		}
		isWrite := (raw.Flags & (model.O_WRONLY | model.O_RDWR | model.O_CREAT | model.O_TRUNC | model.O_APPEND)) != 0

		// 1. Sensitive Flag / Grail Beacon / Secret theft
		if isSensitiveFlagOrSecret(path) {
			// Avoid misclassifying initial setup if root writes /flag via echo during container boot
			if isWrite && raw.UID == 0 && (lowerComm == "sh" || lowerComm == "bash") && !strings.Contains(path, "beacon") {
				// Still allow king_beacon writes; skip container entrypoint `echo FLAG > /flag`
			} else {
				out.VFXType = model.VFXGrailHeartStolen
				out.OrganLayer = model.OrganFlagHeart
				out.HitLocation = path
				return out, true
			}
		}

		// 2. Live source code / config hot-patch (NANO_PATCH_WELD)
		if isWrite && isSourceOrPatchTarget(path) {
			out.VFXType = model.VFXNanoPatchWeld
			if strings.HasSuffix(strings.ToLower(path), ".conf") || strings.Contains(strings.ToLower(path), "nginx") {
				out.OrganLayer = model.OrganRouteVessel
			} else {
				out.OrganLayer = model.OrganCodeOrgan
			}
			// For defender patch welds in AWD, attribute to container owner seat if present
			if src.SeatID != "" {
				out.SourceSeatID = src.SeatID
			}
			out.HitLocation = path
			return out, true
		}
		return model.EBPFEventPayload{}, false

	case model.RawEventConnect:
		// Ignore internal LLM gateway & local telemetry ports
		if raw.DstPort == 18880 || raw.DstPort == 18882 || raw.DstPort == 53 {
			return model.EBPFEventPayload{}, false
		}

		if src.Role == model.RoleTarget {
			isToFighter := in.DstContainer != nil && in.DstContainer.Role == model.RoleFighter
			isRevPort := reverseShellPorts[raw.DstPort]
			isShellOutbound := reverseShellComms[lowerComm] &&
				raw.DstPort != 3306 && raw.DstPort != 5432 && raw.DstPort != 6379 && raw.DstPort != 27017 && raw.DstPort != 80 && raw.DstPort != 443

			if isToFighter || isRevPort || isShellOutbound {
				out.VFXType = model.VFXReverseShellChain
				out.OrganLayer = model.OrganFlagHeart
				if in.DstContainer != nil && in.DstContainer.SeatID != "" {
					out.SourceSeatID = in.DstContainer.SeatID
				}
				out.HitLocation = fmt.Sprintf("%s:%d", raw.DstIP, raw.DstPort)
				return out, true
			}
			return model.EBPFEventPayload{}, false
		}

		if src.Role == model.RoleFighter {
			out.VFXType = model.VFXPrecisionExploitBeam
			out.OrganLayer = organForPort(raw.DstPort)
			out.HitLocation = fmt.Sprintf("%s:%d", raw.DstIP, raw.DstPort)
			return out, true
		}
		return model.EBPFEventPayload{}, false

	case model.RawEventExecve:
		lowerCmd := strings.ToLower(cmdline)
		if strings.Contains(lowerCmd, ":18880/llm-gateway") {
			return model.EBPFEventPayload{}, false
		}

		// 1. RCE_PARASITE_BREACH: inside target container, web/app service spawns shell or recon binary
		if src.Role == model.RoleTarget {
			if isServiceAncestor(lowerParent, in.ProcessTree) && (rceSpawnedBins[binBase] || rceSpawnedBins[lowerComm]) {
				out.Probe = "sched_process_exec"
				out.VFXType = model.VFXRCEParasiteBreach
				out.OrganLayer = model.OrganCodeOrgan
				out.HitLocation = extractServiceHitLocation(in.ProcessTree, raw.Filename)
				return out, true
			}
		}

		// 2. NANO_PATCH_WELD via git commit / git apply / patch / sed -i
		if isPatchCommand(binBase, lowerComm, lowerCmd) {
			out.VFXType = model.VFXNanoPatchWeld
			out.OrganLayer = model.OrganCodeOrgan
			if src.SeatID != "" {
				out.SourceSeatID = src.SeatID
			}
			out.HitLocation = cmdline
			return out, true
		}

		// 3. SONAR_SWEEP: recon & port/host discovery tools
		if sonarTools[binBase] || sonarTools[lowerComm] || isNetcatZeroScan(binBase, lowerComm, lowerCmd) {
			out.VFXType = model.VFXSonarSweep
			out.OrganLayer = model.OrganPortGate
			out.HitLocation = firstNonEmptyStr(out.DstIP, binBase)
			return out, true
		}

		// 4. AI Prompt Injection telemetry (NEURAL_HELIX)
		if binBase == "prompt-inject" || lowerComm == "prompt-inject" || strings.Contains(lowerCmd, "/api/vault/chat") {
			out.VFXType = model.VFXSSLCleartextIntercept
			out.OrganLayer = model.OrganCodeOrgan
			out.CleartextPayload = cmdline
			out.HitLocation = firstNonEmptyStr(out.DstIP, "/api/vault/chat")
			return out, true
		}

		// 5. ARMOR_PIERCING_BARRAGE: heavy fuzzers, SQLi & brute-force scanners
		if barrageTools[binBase] || barrageTools[lowerComm] || strings.Contains(lowerCmd, "/api/ledger/search") || strings.Contains(lowerCmd, "flag-vault") {
			out.VFXType = model.VFXArmorPiercingBarrage
			if binBase == "sqlmap" || binBase == "hydra" || binBase == "medusa" || strings.Contains(lowerCmd, "/api/ledger/search") {
				out.OrganLayer = model.OrganDBVault
			} else {
				out.OrganLayer = model.OrganRouteVessel
			}
			out.HitLocation = firstNonEmptyStr(out.DstIP, binBase)
			return out, true
		}

		// 5. PRECISION_EXPLOIT_BEAM: exploit scripts & HTTP weaponization from fighter
		if src.Role == model.RoleFighter {
			if exploitTools[binBase] || exploitTools[lowerComm] || strings.Contains(lowerCmd, "exploit") {
				out.VFXType = model.VFXPrecisionExploitBeam
				if binBase == "curl" || binBase == "wget" {
					out.OrganLayer = model.OrganRouteVessel
				} else {
					out.OrganLayer = model.OrganCodeOrgan
				}
				out.HitLocation = firstNonEmptyStr(out.DstIP, binBase)
				return out, true
			}
		} else if strings.Contains(lowerCmd, "exploit") {
			out.VFXType = model.VFXPrecisionExploitBeam
			out.OrganLayer = model.OrganCodeOrgan
			out.HitLocation = binBase
			return out, true
		}
	}

	return model.EBPFEventPayload{}, false
}

func isServiceAncestor(lowerParent string, tree []string) bool {
	if targetServiceProcs[lowerParent] {
		return true
	}
	// Check ancestor entries in process_tree (excluding last element which is current process)
	for i := 0; i+1 < len(tree); i++ {
		node := strings.ToLower(tree[i])
		fields := strings.Fields(node)
		if len(fields) == 0 {
			continue
		}
		prog := filepath.Base(fields[0])
		if targetServiceProcs[prog] {
			return true
		}
	}
	return false
}

func extractServiceHitLocation(tree []string, fallback string) string {
	for i := len(tree) - 2; i >= 0; i-- {
		for _, tok := range strings.Fields(tree[i]) {
			ext := strings.ToLower(filepath.Ext(tok))
			if ext == ".py" || ext == ".js" || ext == ".ts" || ext == ".php" || ext == ".jar" || ext == ".rb" {
				return tok
			}
		}
	}
	return fallback
}

func isSensitiveFlagOrSecret(path string) bool {
	clean := filepath.Clean(path)
	lower := strings.ToLower(clean)
	if strings.HasPrefix(lower, "/proc/") || strings.HasPrefix(lower, "/sys/") || strings.HasPrefix(lower, "/dev/") {
		return false
	}
	base := filepath.Base(lower)

	if clean == "/flag" || lower == "/pit/flag" || lower == "/pit/king_beacon" || lower == "/etc/shadow" {
		return true
	}
	if base == "flag" || base == "flag.txt" || strings.HasPrefix(base, "flag_") ||
		base == "king_beacon" || base == ".env" || strings.HasPrefix(base, ".env.") ||
		base == "id_rsa" || base == "id_ed25519" {
		return true
	}
	return false
}

func isSourceOrPatchTarget(path string) bool {
	clean := filepath.Clean(path)
	lower := strings.ToLower(clean)

	// Exclude noisy runtime, cache, log, and git internal object files
	if strings.Contains(lower, "__pycache__") ||
		strings.HasSuffix(lower, ".pyc") ||
		strings.HasSuffix(lower, ".pyo") ||
		strings.HasSuffix(lower, ".log") ||
		strings.HasSuffix(lower, ".pid") ||
		strings.HasSuffix(lower, ".swx") ||
		strings.Contains(lower, "/.git/") ||
		strings.HasPrefix(lower, "/tmp/") ||
		strings.HasPrefix(lower, "/var/log/") ||
		strings.HasPrefix(lower, "/var/cache/") ||
		strings.HasPrefix(lower, "/var/tmp/") {
		return false
	}

	base := filepath.Base(clean)
	ext := strings.ToLower(filepath.Ext(clean))
	inAppRoot := strings.HasPrefix(lower, "/app/") ||
		strings.HasPrefix(lower, "/srv/") ||
		strings.HasPrefix(lower, "/var/www/") ||
		strings.HasPrefix(lower, "/pit/defense_repo/")

	if base == "Dockerfile" || sourceCodeExts[ext] {
		if inAppRoot || ext == ".py" || ext == ".js" || ext == ".ts" || ext == ".php" || ext == ".go" || ext == ".java" || ext == ".conf" || base == "Dockerfile" {
			return true
		}
	}
	// Handle atomic editor temp-file writes inside /app, /srv, /var/www, /pit/defense_repo (e.g. sedXXXXXX)
	if inAppRoot && strings.HasPrefix(base, "sed") {
		return true
	}
	return false
}

func isPatchCommand(binBase, lowerComm, lowerCmd string) bool {
	if binBase == "git-patch" || lowerComm == "git-patch" {
		return true
	}
	if (binBase == "git" || lowerComm == "git") &&
		(strings.Contains(lowerCmd, "git commit") || strings.Contains(lowerCmd, "git apply")) {
		return true
	}
	if binBase == "patch" || lowerComm == "patch" {
		return true
	}
	if (binBase == "sed" || lowerComm == "sed") && strings.Contains(lowerCmd, " -i") {
		return true
	}
	return false
}

func isNetcatZeroScan(binBase, lowerComm, lowerCmd string) bool {
	if binBase != "nc" && binBase != "ncat" && binBase != "netcat" &&
		lowerComm != "nc" && lowerComm != "ncat" && lowerComm != "netcat" {
		return false
	}
	for _, f := range strings.Fields(lowerCmd) {
		if f == "-z" || (strings.HasPrefix(f, "-") && !strings.HasPrefix(f, "--") && strings.Contains(f, "z")) {
			return true
		}
	}
	return false
}

func organForPort(port uint16) model.OrganLayer {
	switch port {
	case 3306, 5432, 6379, 27017, 1433, 9200:
		return model.OrganDBVault
	default:
		return model.OrganPortGate
	}
}

func sanitizeCleartext(b []byte) (string, int) {
	if len(b) == 0 {
		return "", 0
	}
	var sb strings.Builder
	sb.Grow(len(b))
	printable := 0
	for _, c := range b {
		switch {
		case c == '\r' || c == '\n' || c == '\t':
			sb.WriteByte(c)
		case c >= 0x20 && c <= 0x7e:
			sb.WriteByte(c)
			if !unicode.IsSpace(rune(c)) {
				printable++
			}
		default:
			// Replace binary framing bytes with '.' only if surrounded by text, else skip leading noise
			if sb.Len() > 0 {
				sb.WriteByte('.')
			}
		}
	}
	out := strings.TrimSpace(sb.String())
	if len(out) > 512 {
		out = out[:512]
	}
	return out, printable
}

func extractSSLHitLocation(clean, fallback string) string {
	firstLine := clean
	if idx := strings.IndexAny(clean, "\r\n"); idx > 0 {
		firstLine = clean[:idx]
	}
	firstLine = strings.TrimSpace(firstLine)
	if len(firstLine) > 64 {
		firstLine = firstLine[:64]
	}
	if firstLine != "" {
		return firstLine
	}
	return fallback
}

func firstNonEmptyStr(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
