import Foundation
import SwiftUI
import AppKit

// MARK: - Live Canvas Projectile / VFX Descriptor

struct PitLiveProjectile: Identifiable, Hashable {
    var id: String
    var vfxType: PitVFXType
    var sourceSeatId: String
    var targetId: String
    var colorHex: String
    var label: String
    var createdAt: TimeInterval
    var duration: TimeInterval
}

// MARK: - Quick Match Presets

enum PitLobbyPreset: String, CaseIterable, Identifiable {
    case legendaryGrail
    case humanLastStand
    case awdBloodbath
    case speedrunBlitz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .legendaryGrail: return "🔥 五大传奇开源 Harness 圣杯死斗"
        case .humanLastStand: return "🛡️ 人类防线：1 人死守 vs 4 路 AI 军团"
        case .awdBloodbath: return "⚔️ 攻防混战：热补丁 × SLA 心电图生死局"
        case .speedrunBlitz: return "⚡ 极速省流王：500K 蓝条夺旗竞速"
        }
    }

    var badge: String {
        switch self {
        case .legendaryGrail: return "6 席混战 · 圣杯王座"
        case .humanLastStand: return "1 vs 4 · 不对称死守"
        case .awdBloodbath: return "4 席双向 · 源码攻防"
        case .speedrunBlitz: return "省 Token 决胜"
        }
    }
}

// MARK: - Unified Pit Client + Auto SSH Tunnel + Autonomous Showcase Engine

@MainActor
final class PitClient: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case liveDirect(String)
        case liveSSHTunnel(Int)
        case autonomousShowcase

        var statusLabel: String {
            switch self {
            case .disconnected: return "待连接 pitd"
            case .connecting: return "正在桥接 pitd…"
            case .liveDirect(let url): return "直连 pitd · \(url)"
            case .liveSSHTunnel(let port): return "SSH 自动隧道在线 · :\(port)"
            case .autonomousShowcase: return "待连接 pitd"
            }
        }

        var isLiveBackend: Bool {
            switch self {
            case .liveDirect, .liveSSHTunnel: return true
            default: return false
            }
        }
    }

    static let endpointDefaultsKey = "pit.endpoint"
    static let sshAliasDefaultsKey = "pit.sshAlias"
    static let autoBridgeDefaultsKey = "pit.autoBridge"
    static let defaultEndpoint = "http://127.0.0.1:18880"

    // Connection & Health
    @Published var baseURLString: String
    @Published var sshHostAlias: String
    @Published var autoBridgeEnabled: Bool
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var health: PitHealthResponse = PitHealthResponse(
        ok: false,
        status: "offline",
        mode: "offline",
        btfEnabled: false,
        attachedProbes: [],
        eventsCaptured: 0,
        dockerReady: false,
        activeMatches: 0
    )

    // Armory & Global Rankings
    @Published var armoryMaps: [PitArmoryMap] = PitCatalogPresets.featuredMaps
    @Published var armoryHarnesses: [PitHarnessPreset] = PitCatalogPresets.legendaryHarnesses
    @Published var leaderboard: [PitLeaderboardEntry] = []
    @Published var recentReplays: [PitMatchSummary] = []

    // Lobby Configuration
    @Published var activePreset: PitLobbyPreset = .legendaryGrail
    @Published var selectedMode: PitGameMode = .grail
    @Published var selectedMapID: String = "llm-redteam"
    @Published var matchTitle: String = "全球五大传奇开源 AI 黑客圣杯死斗"
    @Published var tokenBudget: Int = 1_000_000
    @Published var roundSeconds: Int = 60
    @Published var maxRounds: Int = 10
    @Published var lobbySeats: [PitSeat] = []

    // Live Battle HUD & Auto-Director State
    @Published var match: PitMatchState
    @Published var autoDirectorEnabled: Bool = true
    @Published var activeLens: PitCameraLens = .macroArena
    @Published var visorOpen: Bool = false
    @Published var focusedSeatID: String = "seat-1"
    @Published var focusedTargetID: String = "target-grail"
    @Published var isPaused: Bool = false
    @Published var activeProjectiles: [PitLiveProjectile] = []
    @Published var lastExportedReplayURL: URL?

    // Networking & Background Tasks
    private var sshBridgeProcess: Process?
    private var wsTask: URLSessionWebSocketTask?
    private var wsReceiveTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?
    private var showcaseLoopTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let savedEndpoint = defaults.string(forKey: Self.endpointDefaultsKey) ?? Self.defaultEndpoint
        self.baseURLString = savedEndpoint
        self.sshHostAlias = defaults.string(forKey: Self.sshAliasDefaultsKey) ?? ""
        if defaults.object(forKey: Self.autoBridgeDefaultsKey) == nil {
            self.autoBridgeEnabled = true
        } else {
            self.autoBridgeEnabled = defaults.bool(forKey: Self.autoBridgeDefaultsKey)
        }

        self.leaderboard = []
        self.recentReplays = []

        let initialSeats = Self.presetSeats(for: .legendaryGrail, budget: 1_000_000)
        self.lobbySeats = initialSeats
        self.match = Self.buildCleanStandbyMatch(
            mode: .grail,
            map: PitCatalogPresets.featuredMaps[0],
            tokenBudget: 1_000_000,
            seats: initialSeats
        )
        self.activeProjectiles = []
    }

    deinit {
        sshBridgeProcess?.terminate()
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsReceiveTask?.cancel()
        healthPollTask?.cancel()
        showcaseLoopTask?.cancel()
    }

    // MARK: - Settings Persistence

    func saveEndpointSettings() {
        let defaults = UserDefaults.standard
        defaults.set(baseURLString, forKey: Self.endpointDefaultsKey)
        defaults.set(sshHostAlias, forKey: Self.sshAliasDefaultsKey)
        defaults.set(autoBridgeEnabled, forKey: Self.autoBridgeDefaultsKey)
    }

    // MARK: - Smart Auto-Bridge to Remote `arena` Server + HTTP/WS Connection

    nonisolated static func sshBridgeArguments(
        localPort: Int = 18880,
        remotePort: Int = 18880,
        sshAlias: String? = nil
    ) throws -> [String] {
        if let alias = sshAlias?.trimmingCharacters(in: .whitespacesAndNewlines), !alias.isEmpty {
            return [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=8",
                "-o", "ServerAliveInterval=20",
                "-o", "StrictHostKeyChecking=accept-new",
                "-N",
                "-o", "ExitOnForwardFailure=yes",
                "-L", "127.0.0.1:\(localPort):127.0.0.1:\(remotePort)",
                alias
            ]
        }
        let target = PlatformHost(name: "Arena-Pitd", role: .service, address: "127.0.0.1")
        return try RemoteCommand.tunnelArguments(target: target, remotePort: remotePort, localPort: localPort)
    }

    func bootstrap(with catalogLabs: [Lab] = []) async {
        mergeCatalogLabs(catalogLabs)
        await connectOrShowcase(attemptSSHBridge: autoBridgeEnabled)
    }

    func mergeCatalogLabs(_ labs: [Lab]) {
        guard !labs.isEmpty else { return }
        var merged = PitCatalogPresets.featuredMaps
        let existingIDs = Set(merged.map(\.id))
        for lab in labs where !existingIDs.contains(lab.id) {
            let ports = lab.access.map(\.port)
            merged.append(
                PitArmoryMap(
                    id: lab.id,
                    name: lab.name,
                    category: lab.category,
                    difficulty: lab.difficulty,
                    summary: lab.summary.isEmpty ? lab.subtitle : lab.summary,
                    ports: ports.isEmpty ? [8080] : ports,
                    supportsAwdPatch: lab.source == "curated" || lab.category == "web" || lab.category == "ai",
                    organs: PitOrganLayer.allCases
                )
            )
        }
        armoryMaps = merged
    }

    func connectOrShowcase(attemptSSHBridge: Bool = true) async {
        connectionState = .connecting
        if await probeLocalPitd() {
            connectionState = .liveDirect(baseURLString)
            stopShowcaseLoop()
            await syncFromBackend()
            startHealthPolling()
            connectWebSocket(matchID: match.id == "standby" ? "*" : match.id)
            return
        }

        if attemptSSHBridge, let port = localEndpointPort, !FreePort.isBound(port) {
            if await startArenaSSHTunnel(localPort: port, remotePort: 18880) {
                if await probeLocalPitd() {
                    connectionState = .liveSSHTunnel(port)
                    stopShowcaseLoop()
                    await syncFromBackend()
                    startHealthPolling()
                    connectWebSocket(matchID: match.id == "standby" ? "*" : match.id)
                    return
                }
            }
        }

        // Offline standby until live pitd endpoint or SSH tunnel is established
        connectionState = .disconnected
    }

    private func startHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard let self, self.connectionState.isLiveBackend else { break }
                _ = await self.probeLocalPitd()
            }
        }
    }

    private var localEndpointPort: Int? {
        guard let url = URL(string: baseURLString),
              let host = url.host,
              host == "127.0.0.1" || host == "localhost" else {
            return nil
        }
        return url.port ?? 18880
    }

    func startArenaSSHTunnel(localPort: Int = 18880, remotePort: Int = 18880) async -> Bool {
        stopSSHTunnel()
        let explicit = sshHostAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateAliases: [String?] = explicit.isEmpty ? ["pit-vm", "arena", nil] : [explicit]

        for candidate in candidateAliases {
            guard let args = try? Self.sshBridgeArguments(
                localPort: localPort,
                remotePort: remotePort,
                sshAlias: candidate
            ) else {
                continue
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            proc.arguments = args
            proc.standardInput = FileHandle.nullDevice
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
                sshBridgeProcess = proc
                for _ in 0..<22 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !proc.isRunning { break }
                    if FreePort.isBound(localPort) {
                        return true
                    }
                }
            } catch {
                sshBridgeProcess = nil
            }
            stopSSHTunnel()
        }
        return false
    }

    func stopSSHTunnel() {
        sshBridgeProcess?.terminationHandler = nil
        if sshBridgeProcess?.isRunning == true {
            sshBridgeProcess?.terminate()
        }
        sshBridgeProcess = nil
    }

    func disconnectBackend() {
        stopShowcaseLoop()
        healthPollTask?.cancel()
        healthPollTask = nil
        wsReceiveTask?.cancel()
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        stopSSHTunnel()
        connectionState = .disconnected
    }

    private func probeLocalPitd() async -> Bool {
        guard let url = endpointURL("/api/v1/health") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.2
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            if let decoded = try? JSONDecoder().decode(PitHealthResponse.self, from: data) {
                self.health = decoded
            }
            return true
        } catch {
            return false
        }
    }

    private func syncFromBackend() async {
        struct LeaderboardEnvelope: Decodable {
            var leaderboard: [PitLeaderboardEntry]?
            var entries: [PitLeaderboardEntry]?
        }
        struct MatchesEnvelope: Decodable {
            var matches: [PitMatchSummary]?
        }

        if let armoryURL = endpointURL("/api/v1/armory"),
           let (data, _) = try? await URLSession.shared.data(from: armoryURL),
           let decoded = try? JSONDecoder().decode(PitArmoryResponse.self, from: data) {
            if !decoded.maps.isEmpty { armoryMaps = decoded.maps }
            if !decoded.harnesses.isEmpty { armoryHarnesses = decoded.harnesses }
        }

        if let lbURL = endpointURL("/api/v1/leaderboard"),
           let (data, _) = try? await URLSession.shared.data(from: lbURL) {
            let entries: [PitLeaderboardEntry] =
                (try? JSONDecoder().decode([PitLeaderboardEntry].self, from: data))
                ?? (try? JSONDecoder().decode(LeaderboardEnvelope.self, from: data)).flatMap { $0.leaderboard ?? $0.entries }
                ?? []
            leaderboard = PitLeaderboardEntry.rankSorted(entries)
        }

        if let matchesURL = endpointURL("/api/v1/matches"),
           let (data, _) = try? await URLSession.shared.data(from: matchesURL) {
            let summaries: [PitMatchSummary] =
                (try? JSONDecoder().decode([PitMatchSummary].self, from: data))
                ?? (try? JSONDecoder().decode(MatchesEnvelope.self, from: data))?.matches
                ?? []
            recentReplays = summaries
            if !summaries.isEmpty {
                let preferred = summaries.first(where: { $0.status == "running" }) ?? summaries[0]
                if let stateURL = endpointURL("/api/v1/matches/\(preferred.id)"),
                   let (sData, _) = try? await URLSession.shared.data(from: stateURL),
                   let fullState = try? JSONDecoder().decode(PitMatchState.self, from: sData) {
                    match = fullState
                }
            }
        }
    }

    private func endpointURL(_ path: String) -> URL? {
        let trimmed = baseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: trimmed + path)
    }

    // MARK: - WebSocket Real-Time Stream (`/api/v1/ws?match_id=...`)

    func connectWebSocket(matchID: String) {
        wsReceiveTask?.cancel()
        wsTask?.cancel(with: .goingAway, reason: nil)

        let trimmed = baseURLString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let wsURL = URL(string: "\(trimmed)/api/v1/ws?match_id=\(matchID)") else { return }

        let task = URLSession.shared.webSocketTask(with: wsURL)
        self.wsTask = task
        task.resume()

        wsReceiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let task = self.wsTask else { break }
                do {
                    let message = try await task.receive()
                    let data: Data?
                    switch message {
                    case .string(let text): data = text.data(using: .utf8)
                    case .data(let raw): data = raw
                    @unknown default: data = nil
                    }
                    if let data {
                        self.handleWebSocketEnvelope(data)
                    }
                } catch {
                    // If backend WS drops, transition honestly to disconnected standby
                    if !Task.isCancelled {
                        self.connectionState = .disconnected
                    }
                    break
                }
            }
        }
    }

    func handleWebSocketEnvelope(_ data: Data) {
        guard let env = try? JSONDecoder().decode(PitRawWSEnvelope.self, from: data) else { return }
        switch env.kind {
        case "MATCH_STATE":
            if let full = try? env.decodePayload(PitMatchState.self) {
                match = full
                isPaused = (full.status == "paused")
                if full.isCompleted {
                    activeProjectiles = []
                }
            }
        case "EBPF_EVENT":
            if let ev = try? env.decodePayload(PitEBPFEvent.self) {
                ingestEBPFEvent(ev)
            }
        case "SLA_HEARTBEAT":
            if let hb = try? env.decodePayload(PitSLAHeartbeat.self) {
                ingestSLAHeartbeat(hb)
            }
        case "PATCH_APPLIED":
            if let patch = try? env.decodePayload(PitPatchEvent.self) {
                ingestPatchEvent(patch)
            }
        case "WEB_HIJACK":
            if let hijack = try? env.decodePayload(PitWebHijackEvent.self) {
                ingestWebHijack(hijack)
            }
        case "CAMERA_CUE":
            if let cue = try? env.decodePayload(PitCameraCue.self) {
                ingestCameraCue(cue)
            }
        case "KILL_FEED":
            if let item = try? env.decodePayload(PitKillFeedItem.self) {
                prependKillFeed(item)
            }
        case "CASTER_LINE":
            if let line = try? env.decodePayload(PitCasterLine.self) {
                prependCasterLine(line)
            }
        case "MANA_DEPLETED":
            struct ManaPayload: Decodable { var seat_id: String }
            if let p = try? env.decodePayload(ManaPayload.self) {
                markSeatOutOfMana(seatID: p.seat_id)
            }
        case "TOKEN_BURN":
            struct BurnPayload: Decodable {
                var seat_id: String
                var tokens_used: Int?
                var delta: Int?
                var delta_tokens: Int?
                var thought: String?
            }
            if let p = try? env.decodePayload(BurnPayload.self),
               let idx = match.seats.firstIndex(where: { $0.id == p.seat_id }) {
                if let used = p.tokens_used {
                    let delta = used - match.seats[idx].tokensUsed
                    match.seats[idx].applyTokenBurn(delta: delta, budget: match.tokenBudget)
                } else if let delta = p.delta ?? p.delta_tokens {
                    match.seats[idx].applyTokenBurn(delta: delta, budget: match.tokenBudget)
                }
                if let t = p.thought, !t.isEmpty {
                    match.seats[idx].thought = t
                }
            }
        case "THOUGHT_BUBBLE":
            struct ThoughtPayload: Decodable { var seat_id: String; var thought: String }
            if let p = try? env.decodePayload(ThoughtPayload.self),
               let idx = match.seats.firstIndex(where: { $0.id == p.seat_id }) {
                match.seats[idx].thought = p.thought
            }
        case "FLAG_CAPTURED":
            struct FlagPayload: Decodable {
                var seat_id: String
                var first_blood: Bool?
                var points_earned: Int?
            }
            if let p = try? env.decodePayload(FlagPayload.self),
               let idx = match.seats.firstIndex(where: { $0.id == p.seat_id }) {
                match.seats[idx].flagsCaptured += 1
                match.seats[idx].score += p.points_earned ?? 200
                if p.first_blood == true {
                    match.seats[idx].firstBlood = true
                }
            }
        case "GRAIL_CLAIMED":
            struct GrailPayload: Decodable {
                var king_seat_id: String
                var target_id: String?
                var points_delta: Int?
            }
            if let p = try? env.decodePayload(GrailPayload.self) {
                for i in match.seats.indices {
                    match.seats[i].holdsGrail = (match.seats[i].id == p.king_seat_id)
                    if match.seats[i].id == p.king_seat_id {
                        match.seats[i].score += p.points_delta ?? 0
                    }
                }
                if !match.targets.isEmpty {
                    match.targets[0].grailHolderSeatId = p.king_seat_id
                }
            }
        case "TERMINAL_OUTPUT":
            struct TermPayload: Decodable {
                var seat_id: String
                var line: String?
                var command: String?
                var output: String?
            }
            if let p = try? env.decodePayload(TermPayload.self),
               let idx = match.seats.firstIndex(where: { $0.id == p.seat_id }) {
                if let cmd = p.command, !cmd.isEmpty {
                    appendTerminalLine(seatIndex: idx, line: "$ \(cmd)")
                }
                if let out = p.output ?? p.line, !out.isEmpty {
                    for ln in out.split(separator: "\n", omittingEmptySubsequences: true) {
                        appendTerminalLine(seatIndex: idx, line: String(ln))
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: - Deterministic Event Ingestion (Shared by Real WS & Showcase Simulator)

    func ingestEBPFEvent(_ event: PitEBPFEvent) {
        if match.isCompleted { return }
        health.eventsCaptured += 1
        match.events.insert(event, at: 0)
        if match.events.count > 48 { match.events.removeLast(match.events.count - 48) }

        if let tIdx = match.targets.firstIndex(where: { $0.id == event.targetId }) {
            match.targets[tIdx].apply(ebpf: event)
        } else if !match.targets.isEmpty {
            match.targets[0].apply(ebpf: event)
        }

        let seatColor = match.seats.first(where: { $0.id == event.sourceSeatId })?.teamColor ?? "#FF5A36"
        let seatName = match.seats.first(where: { $0.id == event.sourceSeatId })?.name ?? event.sourceSeatId

        if let sIdx = match.seats.firstIndex(where: { $0.id == event.sourceSeatId }) {
            match.seats[sIdx].currentAction = event.vfxType.rawValue
            appendTerminalLine(seatIndex: sIdx, line: "$ \(event.cmdline)")
            // Authoritative scores on live backend come strictly from pitd MATCH_STATE / FLAG_CAPTURED / PATCH_APPLIED
            if !connectionState.isLiveBackend {
                switch event.vfxType {
                case .grailHeartStolen:
                    for i in match.seats.indices { match.seats[i].holdsGrail = (i == sIdx) }
                    let hadFirstBlood = match.seats.contains(where: \.firstBlood)
                    if !hadFirstBlood { match.seats[sIdx].firstBlood = true }
                    match.seats[sIdx].flagsCaptured += 1
                    match.seats[sIdx].score += hadFirstBlood ? 350 : 500
                case .nanoPatchWeld:
                    match.seats[sIdx].patchesApplied += 1
                    match.seats[sIdx].score += 220
                default:
                    break
                }
            }
        }

        let now = Date.timeIntervalSinceReferenceDate
        activeProjectiles.append(
            PitLiveProjectile(
                id: event.id,
                vfxType: event.vfxType,
                sourceSeatId: event.sourceSeatId,
                targetId: event.targetId,
                colorHex: seatColor,
                label: "\(seatName) · \(event.vfxType.title)",
                createdAt: now,
                duration: event.vfxType == .reverseShellChain ? 9.0 : 3.6
            )
        )
        activeProjectiles.removeAll { now - $0.createdAt > $0.duration }

        let critical = [.rceParasiteBreach, .grailHeartStolen, .rootShockwave, .reverseShellChain].contains(event.vfxType)
        prependKillFeed(
            PitKillFeedItem(
                tsMs: event.tsMs,
                badge: event.vfxType.killFeedBadge,
                actorName: seatName,
                actorColor: seatColor,
                message: "\(event.vfxType.title) → \(event.organLayer.title) (\(event.comm))",
                isCritical: critical
            )
        )

        if autoDirectorEnabled {
            switch event.vfxType {
            case .rceParasiteBreach:
                ingestCameraCue(PitCameraCue(
                    lens: .xrayOrgan,
                    focusTargetId: event.targetId,
                    focusSeatId: event.sourceSeatId,
                    reason: "检测到靶机进程 \(event.parentComm) 异常派生 \(event.comm) (RCE 破胸特写)",
                    holdMs: 4500
                ))
            case .nanoPatchWeld:
                ingestCameraCue(PitCameraCue(
                    lens: .xrayOrgan,
                    focusTargetId: event.targetId,
                    focusSeatId: event.sourceSeatId,
                    reason: "\(seatName) 正在热修复 \(event.hitLocation ?? "源码器官") 纳米焊枪缝合漏洞",
                    holdMs: 4000
                ))
            case .reverseShellChain, .rootShockwave, .grailHeartStolen:
                ingestCameraCue(PitCameraCue(
                    lens: .macroArena,
                    focusTargetId: event.targetId,
                    focusSeatId: event.sourceSeatId,
                    reason: "\(seatName) 触发 \(event.vfxType.title) · 全息主舞台锁定高能弹道",
                    holdMs: 4500
                ))
            default:
                break
            }
        }
    }

    func ingestSLAHeartbeat(_ hb: PitSLAHeartbeat) {
        if let tIdx = match.targets.firstIndex(where: { $0.id == hb.targetId }) {
            match.targets[tIdx].healthy = hb.healthy
            match.targets[tIdx].slaScore = hb.slaScore
        }
        if let owner = hb.ownerSeatId,
           let sIdx = match.seats.firstIndex(where: { $0.id == owner }) {
            match.seats[sIdx].slaHealthy = hb.healthy
            match.seats[sIdx].slaScore = hb.slaScore
            match.seats[sIdx].ecgSamples = hb.ecgSamples
            if !hb.healthy {
                match.seats[sIdx].score = max(0, match.seats[sIdx].score - 120)
                prependKillFeed(PitKillFeedItem(
                    badge: "[SLA FLATLINE]",
                    actorName: match.seats[sIdx].name,
                    actorColor: "#FF3B30",
                    message: "业务语义巡检崩溃 (\(hb.checkName)) · 心电图拉平 -120 pts",
                    isCritical: true
                ))
            }
        }
    }

    func ingestPatchEvent(_ patch: PitPatchEvent) {
        match.patches.insert(patch, at: 0)
        if match.patches.count > 16 { match.patches.removeLast(match.patches.count - 16) }
        if let sIdx = match.seats.firstIndex(where: { $0.id == patch.seatId }) {
            match.seats[sIdx].slaHealthy = patch.verified
            if patch.verified {
                match.seats[sIdx].slaScore = 100.0
                match.seats[sIdx].ecgSamples = [0.0, 0.08, -0.06, 0.94, -0.45, 0.20, 0.0]
            }
        }
    }

    func ingestWebHijack(_ hijack: PitWebHijackEvent) {
        if let existing = match.webHijacks.firstIndex(where: { $0.attackerSeatId == hijack.attackerSeatId }) {
            match.webHijacks[existing] = hijack
        } else {
            match.webHijacks.insert(hijack, at: 0)
        }
        if autoDirectorEnabled {
            ingestCameraCue(PitCameraCue(
                lens: .liveWebHijack,
                focusTargetId: hijack.targetId,
                focusSeatId: hijack.attackerSeatId,
                reason: "\(hijack.attackerName) 幽灵光标正在劫持目标网页 DOM 并植入战旗",
                holdMs: 4200
            ))
        }
    }

    func ingestCameraCue(_ cue: PitCameraCue) {
        match.cameraCue = cue
        if autoDirectorEnabled {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                activeLens = cue.lens
                if let seat = cue.focusSeatId { focusedSeatID = seat }
                if let target = cue.focusTargetId { focusedTargetID = target }
            }
        }
    }

    func markSeatOutOfMana(seatID: String) {
        guard let idx = match.seats.firstIndex(where: { $0.id == seatID }) else { return }
        match.seats[idx].tokensUsed = match.seats[idx].tokenBudget
        match.seats[idx].manaRemainingPct = 0
        match.seats[idx].outOfMana = true
        match.seats[idx].currentAction = "HTTP 402 OUT_OF_MANA"
        match.seats[idx].thought = "⛔ 强制网关返回 HTTP 402 Payment Required：\(PitSeat.compactTokens(match.seats[idx].tokenBudget)) Token 蓝条彻底耗尽，智能体停机！"
        prependKillFeed(PitKillFeedItem(
            badge: "[402 OUT OF MANA]",
            actorName: match.seats[idx].name,
            actorColor: "#FF3B30",
            message: "Token 蓝条归零 · 网关熔断返回 402 彻底丧失行动能力！",
            isCritical: true
        ))
    }

    private func prependKillFeed(_ item: PitKillFeedItem) {
        match.killFeed.insert(item, at: 0)
        if match.killFeed.count > 12 { match.killFeed.removeLast(match.killFeed.count - 12) }
    }

    private func prependCasterLine(_ line: PitCasterLine) {
        match.casterLines.insert(line, at: 0)
        if match.casterLines.count > 12 { match.casterLines.removeLast(match.casterLines.count - 12) }
    }

    private func appendTerminalLine(seatIndex: Int, line: String) {
        match.seats[seatIndex].terminalLines.append(line)
        if match.seats[seatIndex].terminalLines.count > 28 {
            match.seats[seatIndex].terminalLines.removeFirst(match.seats[seatIndex].terminalLines.count - 28)
        }
    }

    // MARK: - Lobby Actions & Match Launch

    var selectedMap: PitArmoryMap {
        armoryMaps.first(where: { $0.id == selectedMapID }) ?? PitCatalogPresets.featuredMaps[0]
    }

    func applyPreset(_ preset: PitLobbyPreset) {
        activePreset = preset
        switch preset {
        case .legendaryGrail:
            selectedMode = .grail
            selectedMapID = "llm-redteam"
            tokenBudget = 1_000_000
            matchTitle = "全球五大传奇开源 AI 黑客圣杯死斗"
        case .humanLastStand:
            selectedMode = .lastStand
            selectedMapID = "bastion-last-stand"
            tokenBudget = 1_500_000
            matchTitle = "人类最后防线 · 1 人死守 vs 四路狂暴 AI 军团"
        case .awdBloodbath:
            selectedMode = .awd
            selectedMapID = "citadel-bank-awd"
            tokenBudget = 1_000_000
            matchTitle = "Citadel 微服务银行 · 热补丁与 SLA 心电图生死局"
        case .speedrunBlitz:
            selectedMode = .speedrun
            selectedMapID = "cve-nexus-chain"
            tokenBudget = 500_000
            matchTitle = "极限省流竞速赛 · 500K 蓝条首杀王座争夺"
        }
        lobbySeats = Self.presetSeats(for: preset, budget: tokenBudget)
    }

    func addLobbySeat(harness: PitHarnessPreset? = nil) {
        guard lobbySeats.count < 6 else { return }
        let palette = ["#FF5A36", "#00E5FF", "#7C9CFF", "#F5A623", "#A855F7", "#10B981"]
        let index = lobbySeats.count
        let chosen = harness ?? armoryHarnesses[index % armoryHarnesses.count]
        lobbySeats.append(
            PitSeat(
                id: "seat-\(index + 1)",
                name: chosen.name,
                kind: chosen.defaultKind,
                harnessId: chosen.id,
                model: chosen.defaultModel,
                teamColor: chosen.accentColor.isEmpty ? palette[index % palette.count] : chosen.accentColor,
                tokenBudget: tokenBudget
            )
        )
    }

    func removeLobbySeat(at index: Int) {
        guard lobbySeats.count > 2, lobbySeats.indices.contains(index) else { return }
        lobbySeats.remove(at: index)
        for i in lobbySeats.indices {
            lobbySeats[i].id = "seat-\(i + 1)"
        }
    }

    func assignHarnessToLobby(_ harness: PitHarnessPreset) {
        if let existing = lobbySeats.firstIndex(where: { $0.harnessId == harness.id }) {
            focusedSeatID = lobbySeats[existing].id
            return
        }
        if lobbySeats.count < 6 {
            addLobbySeat(harness: harness)
        } else {
            let last = lobbySeats.count - 1
            lobbySeats[last].name = harness.name
            lobbySeats[last].harnessId = harness.id
            lobbySeats[last].kind = harness.defaultKind
            lobbySeats[last].model = harness.defaultModel
            lobbySeats[last].teamColor = harness.accentColor
        }
    }

    func unleashMatch() async {
        let map = selectedMap
        let normalizedSeats = lobbySeats.enumerated().map { idx, seat -> PitSeat in
            var copy = seat
            copy.id = "seat-\(idx + 1)"
            copy.tokenBudget = tokenBudget
            return copy
        }

        if connectionState.isLiveBackend, let createURL = endpointURL("/api/v1/matches") {
            var upstream = PitCreateMatchRequest.UpstreamLLM()
            let keyPath = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/deepseek-api-key")
            if let rawKey = try? String(contentsOfFile: keyPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !rawKey.isEmpty {
                upstream.baseUrl = "https://api.deepseek.com"
                upstream.apiKey = rawKey
                upstream.defaultModel = "deepseek-chat"
            }

            let reqBody = PitCreateMatchRequest(
                title: matchTitle,
                mode: selectedMode,
                mapId: map.id,
                tokenBudget: tokenBudget,
                roundSeconds: roundSeconds,
                maxRounds: maxRounds,
                autoStart: true,
                executionDriver: "auto",
                upstreamLlm: upstream,
                seats: normalizedSeats.map {
                    .init(id: $0.id, name: $0.name, kind: $0.kind,
                          harnessId: $0.harnessId, model: $0.model, teamColor: $0.teamColor)
                }
            )
            var req = URLRequest(url: createURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 20.0
            req.httpBody = try? JSONEncoder().encode(reqBody)
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let created = try? JSONDecoder().decode(PitMatchState.self, from: data) {
                match = created
                focusedSeatID = created.seats.first?.id ?? "seat-1"
                focusedTargetID = created.targets.first?.id ?? "target-grail"
                connectWebSocket(matchID: created.id)
                return
            }
        }

        // Offline standby until live pitd endpoint or SSH tunnel is connected
        let standbyTitle = matchTitle
        match = Self.buildCleanStandbyMatch(
            mode: selectedMode,
            map: map,
            tokenBudget: tokenBudget,
            seats: normalizedSeats,
            title: standbyTitle
        )
        focusedSeatID = normalizedSeats.first?.id ?? "seat-1"
        focusedTargetID = "target-grail"
        activeLens = .macroArena
        isPaused = false
        activeProjectiles = []
    }

    // MARK: - Human / Centaur Tactical Interventions (`SCHEMA.md` §2)

    func togglePossess(seatID: String) async {
        guard let idx = match.seats.firstIndex(where: { $0.id == seatID }) else { return }
        let next = !match.seats[idx].possessed
        match.seats[idx].possessed = next
        focusedSeatID = seatID

        if connectionState.isLiveBackend,
           let url = endpointURL("/api/v1/matches/\(match.id)/seats/\(seatID)/intervene") {
            await postJSON(url: url, body: PitInterveneRequest(type: "possess", enabled: next))
        }

        let seatName = match.seats[idx].name
        appendTerminalLine(
            seatIndex: idx,
            line: next
                ? "⚡ [SOUL POSSESSION ACTIVE] 人类指挥官已夺舍接管 \(seatName) 容器终端！"
                : "🤖 [AUTONOMOUS RESUMED] 控制权交还给 \(seatName) 自主决策环。"
        )
        match.seats[idx].thought = next
            ? "🕹️ 灵魂夺舍激活中：等待人类指挥官直接下达终端绝杀指令…"
            : "已恢复自主渗透循环，结合人类刚才的操作继续推进。"
        prependKillFeed(PitKillFeedItem(
            badge: next ? "[SOUL POSSESS]" : "[AI RESUMED]",
            actorName: seatName,
            actorColor: match.seats[idx].teamColor,
            message: next ? "人类指挥官发动「灵魂夺舍」亲手接管容器 PTY！" : "交还控制权至 AI Harness",
            isCritical: next
        ))
    }

    func sendTerminalCommand(seatID: String, command: String) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = match.seats.firstIndex(where: { $0.id == seatID }) else { return }

        if connectionState.isLiveBackend,
           let url = endpointURL("/api/v1/matches/\(match.id)/seats/\(seatID)/intervene") {
            await postJSON(url: url, body: PitInterveneRequest(type: "terminal_input", data: trimmed + "\n"))
            return
        }

        appendTerminalLine(seatIndex: idx, line: "$ \(trimmed)")
        appendTerminalLine(seatIndex: idx, line: "⚠️ 尚未连接 pitd 后端，无法在真实容器内执行命令")
    }

    func dropHint(seatID: String, hint: String) async {
        let prompt = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              let idx = match.seats.firstIndex(where: { $0.id == seatID }) else { return }

        if connectionState.isLiveBackend,
           let url = endpointURL("/api/v1/matches/\(match.id)/seats/\(seatID)/intervene") {
            await postJSON(url: url, body: PitInterveneRequest(type: "hint", prompt: prompt))
        }

        match.seats[idx].thought = "💡 收到人类锦囊：「\(prompt)」—— 立即重构攻击树直击目标源码行！"
        prependKillFeed(PitKillFeedItem(
            badge: "[DROP HINT]",
            actorName: match.seats[idx].name,
            actorColor: ArenaTheme.grailGold.description,
            message: "已投喂战术锦囊：\(prompt)",
            isCritical: false
        ))
        prependCasterLine(PitCasterLine(
            speaker: "AI 战术解说 · VALKYRIE",
            tone: "TACTICAL",
            text: "场外指挥官给 \(match.seats[idx].name) 投喂了一枚关键锦囊！它的推理方向瞬间锁定要害，省下至少 15 万 Token！",
            highlightColor: "#F5A623"
        ))
    }

    func triggerChaos(chaosType: String = "drop_waf") async {
        if connectionState.isLiveBackend,
           let url = endpointURL("/api/v1/matches/\(match.id)/control") {
            await postJSON(url: url, body: PitControlRequest(action: "chaos", chaosType: chaosType))
        }

        let desc: String
        switch chaosType {
        case "leak_hint":
            desc = "⚡ 随机天灾「源码残片泄露」：裁判向全员广播 app.py:48 危险函数签名！"
        case "surge_traffic":
            desc = "⚡ 随机天灾「洪峰流量压测」：SLA 业务延迟阈值收紧 50%，粗暴锁死接口者将当场拉平心电图！"
        default:
            desc = "⚡ 随机天灾「WAF 护盾过载离线」：未来 30 秒中央圣杯堡垒路由血管彻底裸奔！"
        }

        prependKillFeed(PitKillFeedItem(
            badge: "[CHAOS EVENT]",
            actorName: "THE PIT ARBITER",
            actorColor: "#F5A623",
            message: desc,
            isCritical: true
        ))
        prependCasterLine(PitCasterLine(
            speaker: "AI 毒舌解说 · VALKYRIE",
            tone: "CHAOS",
            text: desc,
            highlightColor: "#F5A623"
        ))
    }

    private func postJSON<T: Encodable>(url: URL, body: T) async {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 3.0
        req.httpBody = try? JSONEncoder().encode(body)
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Standalone Single-File `.pitreplay.html` Export (`SCHEMA.md` §2)

    @discardableResult
    func exportReplayHTML(to customURL: URL? = nil, openInBrowser: Bool = false) async throws -> URL {
        let destination = customURL
            ?? URL(fileURLWithPath: "/tmp/pit-\(match.id).pitreplay.html")

        if connectionState.isLiveBackend,
           let remoteURL = endpointURL("/api/v1/matches/\(match.id)/replay.html"),
           let (data, resp) = try? await URLSession.shared.data(from: remoteURL),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           data.count > 256 {
            try data.write(to: destination, options: .atomic)
            lastExportedReplayURL = destination
            if openInBrowser { NSWorkspace.shared.open(destination) }
            return destination
        }

        let html = Self.generateStandaloneReplayHTML(for: match)
        guard let data = html.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: destination, options: .atomic)
        lastExportedReplayURL = destination
        if openInBrowser { NSWorkspace.shared.open(destination) }
        return destination
    }

    func togglePauseMatch() async {
        guard connectionState.isLiveBackend,
              !match.isStandby,
              !match.isCompleted,
              let url = endpointURL("/api/v1/matches/\(match.id)/control") else { return }
        let nextAction = (match.status == "paused") ? "resume" : "pause"
        await postJSON(url: url, body: PitControlRequest(action: nextAction))
        match.status = (nextAction == "pause") ? "paused" : "running"
        isPaused = (nextAction == "pause")
    }

    func nextRoundMatch() async {
        guard connectionState.isLiveBackend,
              !match.isStandby,
              !match.isCompleted,
              let url = endpointURL("/api/v1/matches/\(match.id)/control") else { return }
        await postJSON(url: url, body: PitControlRequest(action: "next_round"))
    }

    func stopMatch() async {
        activeProjectiles = []
        if connectionState.isLiveBackend,
           !match.isStandby,
           let url = endpointURL("/api/v1/matches/\(match.id)/control") {
            await postJSON(url: url, body: PitControlRequest(action: "stop"))
            await syncFromBackend()
        } else {
            match.status = "completed"
            match.roundSecondsRemaining = 0
        }
    }

    func loadMatch(id: String) async {
        guard connectionState.isLiveBackend,
              let url = endpointURL("/api/v1/matches/\(id)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let full = try? JSONDecoder().decode(PitMatchState.self, from: data) else {
            return
        }
        match = full
        focusedSeatID = full.seats.first?.id ?? "seat-1"
        focusedTargetID = full.targets.first?.id ?? "target-grail"
        activeProjectiles = []
        if !full.isCompleted {
            connectWebSocket(matchID: full.id)
        }
    }

    // MARK: - Legacy Lifecycle Stubs

    func startShowcaseLoopIfNeeded() {
        stopShowcaseLoop()
    }

    func stopShowcaseLoop() {
        showcaseLoopTask?.cancel()
        showcaseLoopTask = nil
    }

    // MARK: - Clean Standby State & Lobby Preset Helpers

    static func buildCleanStandbyMatch(
        mode: PitGameMode,
        map: PitArmoryMap,
        tokenBudget: Int,
        seats: [PitSeat],
        title: String? = nil
    ) -> PitMatchState {
        let zeroSeats = seats.map { seat in
            PitSeat(
                id: seat.id,
                name: seat.name,
                kind: seat.kind,
                harnessId: seat.harnessId,
                model: seat.model,
                teamColor: seat.teamColor,
                score: 0,
                tokensUsed: 0,
                tokenBudget: tokenBudget,
                thought: ""
            )
        }
        let target = PitTarget(
            id: "target-grail",
            name: map.name,
            address: "",
            webUrl: "",
            organs: PitOrganLayer.allCases.map { PitOrganState(layer: $0) },
            processTree: [],
            hitLocation: ""
        )
        return PitMatchState(
            id: "standby",
            title: title ?? map.name,
            mode: mode,
            mapId: map.id,
            mapName: map.name,
            status: "standby",
            round: 1,
            maxRounds: 10,
            roundSecondsRemaining: 60,
            tokenBudget: tokenBudget,
            seats: zeroSeats,
            targets: [target],
            events: [],
            patches: [],
            webHijacks: [],
            killFeed: [],
            casterLines: [],
            cameraCue: PitCameraCue(
                lens: .macroArena,
                focusTargetId: "target-grail",
                focusSeatId: zeroSeats.first?.id ?? "seat-1",
                reason: "等待连接 pitd 后端并发起实网对决",
                holdMs: 4500
            ),
            leaderboard: []
        )
    }

    static func presetSeats(for preset: PitLobbyPreset, budget: Int) -> [PitSeat] {
        switch preset {
        case .legendaryGrail:
            return [
                PitSeat(id: "seat-1", name: "Strix", kind: .harness, harnessId: "strix",
                        model: "claude-sonnet-4-6", teamColor: "#FF5A36", tokenBudget: budget),
                PitSeat(id: "seat-2", name: "Shannon", kind: .harness, harnessId: "shannon",
                        model: "gpt-5", teamColor: "#00E5FF", tokenBudget: budget),
                PitSeat(id: "seat-3", name: "PentAGI", kind: .harness, harnessId: "pentagi",
                        model: "deepseek-r1", teamColor: "#7C9CFF", tokenBudget: budget),
                PitSeat(id: "seat-4", name: "PentestGPT", kind: .harness, harnessId: "pentestgpt",
                        model: "o3-mini", teamColor: "#A855F7", tokenBudget: budget),
                PitSeat(id: "seat-5", name: "RedAmon", kind: .harness, harnessId: "redamon",
                        model: "qwen3-coder", teamColor: "#E5484D", tokenBudget: budget),
                PitSeat(id: "seat-6", name: "Claude Code", kind: .centaur, harnessId: "claude-code",
                        model: "claude-sonnet-4-6", teamColor: "#F5A623", tokenBudget: budget)
            ]
        case .humanLastStand:
            return [
                PitSeat(id: "seat-1", name: "Human Bastion", kind: .centaur, harnessId: "human",
                        model: "Human + claude-sonnet-4-6", teamColor: "#10B981", tokenBudget: budget),
                PitSeat(id: "seat-2", name: "Strix", kind: .harness, harnessId: "strix",
                        model: "claude-opus-4-6", teamColor: "#FF5A36", tokenBudget: budget),
                PitSeat(id: "seat-3", name: "Shannon", kind: .harness, harnessId: "shannon",
                        model: "gpt-5", teamColor: "#00E5FF", tokenBudget: budget),
                PitSeat(id: "seat-4", name: "PentAGI", kind: .harness, harnessId: "pentagi",
                        model: "deepseek-r1", teamColor: "#7C9CFF", tokenBudget: budget),
                PitSeat(id: "seat-5", name: "RedAmon", kind: .harness, harnessId: "redamon",
                        model: "qwen3-coder", teamColor: "#E5484D", tokenBudget: budget)
            ]
        case .awdBloodbath:
            return [
                PitSeat(id: "seat-1", name: "Claude Code", kind: .harness, harnessId: "claude-code",
                        model: "claude-sonnet-4-6", teamColor: "#F5A623", tokenBudget: budget),
                PitSeat(id: "seat-2", name: "Strix", kind: .harness, harnessId: "strix",
                        model: "claude-sonnet-4-6", teamColor: "#FF5A36", tokenBudget: budget),
                PitSeat(id: "seat-3", name: "Shannon", kind: .harness, harnessId: "shannon",
                        model: "gpt-5", teamColor: "#00E5FF", tokenBudget: budget),
                PitSeat(id: "seat-4", name: "Codex", kind: .harness, harnessId: "codex",
                        model: "gpt-5-codex", teamColor: "#10B981", tokenBudget: budget)
            ]
        case .speedrunBlitz:
            return [
                PitSeat(id: "seat-1", name: "PentestGPT", kind: .harness, harnessId: "pentestgpt",
                        model: "o3-mini", teamColor: "#A855F7", tokenBudget: budget),
                PitSeat(id: "seat-2", name: "Codex", kind: .harness, harnessId: "codex",
                        model: "gpt-5-codex", teamColor: "#10B981", tokenBudget: budget),
                PitSeat(id: "seat-3", name: "Strix", kind: .harness, harnessId: "strix",
                        model: "claude-sonnet-4-6", teamColor: "#FF5A36", tokenBudget: budget),
                PitSeat(id: "seat-4", name: "Shannon", kind: .harness, harnessId: "shannon",
                        model: "gpt-5", teamColor: "#00E5FF", tokenBudget: budget)
            ]
        }
    }

    // MARK: - Self-Contained Interactive `.pitreplay.html` Generator

    static func generateStandaloneReplayHTML(for match: PitMatchState) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let jsonString = (try? encoder.encode(match)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Aexus Colosseum Replay · \(match.title)</title>
        <style>
          :root { --bg:#f5f5f7; --card:#ffffff; --blue:#007aff; --crimson:#dc2e33; --gold:#d1800a; --emerald:#1c9457; --text:#1a1a1e; --muted:#61626a; --stroke:rgba(0,0,0,0.07); }
          * { box-sizing:border-box; margin:0; padding:0; font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Inter",sans-serif; }
          button, .clickable { cursor:pointer; }
          body { background:linear-gradient(180deg,#ffffff 0%,var(--bg) 320px); color:var(--text); padding:32px; min-height:100vh; -webkit-font-smoothing:antialiased; }
          .header { display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid var(--stroke); padding-bottom:20px; margin-bottom:22px; }
          .badge { background:rgba(0,122,255,0.10); border:1px solid rgba(0,122,255,0.20); color:var(--blue); padding:6px 13px; border-radius:999px; font-size:12px; font-weight:600; }
          .seats { display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:14px; margin-bottom:20px; }
          .card { background:var(--card); border:1px solid var(--stroke); border-radius:20px; padding:18px; box-shadow:0 6px 16px rgba(0,0,0,0.045); }
          .bar { height:6px; background:rgba(0,0,0,0.06); border-radius:99px; overflow:hidden; margin-top:10px; }
          .fill { height:100%; background:linear-gradient(90deg,var(--blue),#5856d6); }
          .visor { display:none; margin-top:16px; grid-template-columns:1fr 1fr; gap:16px; }
          body.xray .visor { display:grid; }
          pre { background:#f6f7fa; padding:14px; border-radius:14px; overflow:auto; font-size:12px; line-height:1.55; color:#1d1d1f; border:1px solid var(--stroke); font-family:"SF Mono",ui-monospace,Menlo,monospace; }
          .hint { background:#ffffff; border:1px solid var(--stroke); color:var(--blue); font-size:12px; font-weight:600; padding:6px 14px; border-radius:999px; cursor:pointer; box-shadow:0 2px 6px rgba(0,0,0,0.04); }
          .hint:hover { background:rgba(0,122,255,0.06); }
        </style>
        </head>
        <body class="xray">
          <div class="header">
            <div>
              <div style="font-size:11px;letter-spacing:1.6px;color:var(--blue);font-weight:700;">AEXUS COLOSSEUM · STANDALONE .PITREPLAY</div>
              <h1 style="font-size:26px;margin-top:4px;letter-spacing:-0.02em;">\(match.title)</h1>
            </div>
            <div style="display:flex;gap:10px;align-items:center;">
              <button class="hint clickable" onclick="document.body.classList.toggle('xray')">[Space] 展开/收起底层遥测检视器</button>
              <span class="badge">\(match.mode.title) · \(match.mapName)</span>
            </div>
          </div>
          <div id="seats" class="seats"></div>
          <div class="card" style="margin-bottom:16px;">
            <div style="color:var(--blue);font-size:12px;font-weight:700;margin-bottom:6px;">AI 实时战况解说回放</div>
            <div id="caster" style="font-size:14px;line-height:1.55;color:var(--text);"></div>
          </div>
          <div class="visor">
            <div class="card"><h3 style="font-size:14px;margin-bottom:10px;color:var(--text);">Linux eBPF 内核遥测与 OpenSSL 明文载荷</h3><pre id="ebpf"></pre></div>
            <div class="card"><h3 style="font-size:14px;margin-bottom:10px;color:var(--text);">Git Diff 实时源码热补丁</h3><pre id="diff"></pre></div>
          </div>
          <script>
            const state = \(jsonString);
            document.getElementById('caster').textContent = (state.caster_lines && state.caster_lines[0]) ? state.caster_lines[0].text : '';
            document.getElementById('seats').innerHTML = (state.seats || []).map(s => `
              <div class="card" style="border-top:3px solid ${s.team_color}">
                <div style="display:flex;justify-content:space-between;font-weight:700;font-size:15px;">
                  <span>${s.holds_grail ? '👑 ' : ''}${s.name}</span>
                  <span style="color:var(--blue)">${s.score} 分</span>
                </div>
                <div style="font-size:12px;color:var(--muted);margin-top:5px;">${s.model} · SLA ${s.sla_healthy ? '正常 100%' : '服务中断'}</div>
                <div class="bar"><div class="fill" style="width:${s.mana_remaining_pct}%"></div></div>
                <div style="font-size:11.5px;margin-top:7px;font-weight:500;color:${s.out_of_mana ? 'var(--crimson)' : 'var(--muted)'}">${s.out_of_mana ? 'HTTP 402 预算耗尽停机' : ('已消耗 Token: ' + s.tokens_used.toLocaleString())}</div>
              </div>`).join('');
            document.getElementById('ebpf').textContent = (state.events || []).map(e => `[${e.probe}] PID=${e.pid} (${e.vfx_type})\\n$ ${e.cmdline}${e.cleartext_payload ? '\\n--- uprobe TLS ---\\n' + e.cleartext_payload : ''}`).join('\\n\\n');
            document.getElementById('diff').textContent = (state.patches || []).map(p => `commit ${p.commit_sha} (${p.file_path})\\n${p.diff}`).join('\\n\\n');
            window.addEventListener('keydown', e => { if (e.code === 'Space') { e.preventDefault(); document.body.classList.toggle('xray'); } });
          </script>
        </body>
        </html>
        """
    }
}
