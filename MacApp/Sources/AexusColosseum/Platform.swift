import Foundation
import SwiftUI

// MARK: - Modes

enum AppMode: String, CaseIterable, Identifiable {
    case pitArena
    case pitLive
    case training
    case workspace
    case events
    case hosts

    /// Alias for `.training` matching the Map & Harness Armory nomenclature.
    static let library: AppMode = .training

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pitArena: return "斗兽场大厅 (The Pit)"
        case .pitLive: return "战局主舞台 (Live HUD)"
        case .training: return "地图与军火素材库"
        case .workspace: return "单兵演练台"
        case .events: return "攻防赛事"
        case .hosts: return "主机与拓扑"
        }
    }

    var subtitle: String {
        switch self {
        case .pitArena: return "AI 智能体 × 人类黑客实网死斗大厅"
        case .pitLive: return "60fps 全息导播 · eBPF 内核透视目镜"
        case .training: return "100+ CTF/CVE 靶标 & 五大传奇 Harness"
        case .workspace: return "内嵌真终端 · 单题渗透与热修复调试"
        case .events: return "观察多主机对抗"
        case .hosts: return "绑定并验证你的主机"
        }
    }

    var symbol: String {
        switch self {
        case .pitArena: return "flame.fill"
        case .pitLive: return "waveform.path.ecg.rectangle.fill"
        case .training: return "square.stack.3d.up.fill"
        case .workspace: return "terminal.fill"
        case .events: return "flag.2.crossed.fill"
        case .hosts: return "server.rack"
        }
    }
}

// MARK: - Hosts

enum HostRole: String, Codable, CaseIterable, Identifiable {
    case attacker, target, observer, service

    var id: String { rawValue }

    var label: String {
        switch self {
        case .attacker: return "攻击机"
        case .target: return "靶机"
        case .observer: return "观察机"
        case .service: return "服务机"
        }
    }

    var symbol: String {
        switch self {
        case .attacker: return "bolt.shield.fill"
        case .target: return "shield.lefthalf.filled"
        case .observer: return "eye.fill"
        case .service: return "gearshape.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .attacker: return ArenaTheme.accent
        case .target: return ArenaTheme.ember
        case .observer: return ArenaTheme.success
        case .service: return ArenaTheme.gold
        }
    }
}

struct HostSSH: Codable, Hashable {
    var address: String?
    var port: Int = 22
    var user: String = "root"
    var key: String = ""
    var jump: String?

    init(port: Int = 22, user: String = "root", key: String = "", jump: String? = nil,
         address: String? = nil) {
        self.address = address
        self.port = port
        self.user = user
        self.key = key
        self.jump = jump
    }

    enum CodingKeys: String, CodingKey { case port, user, key, jump, address }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        address = try? c.decodeIfPresent(String.self, forKey: .address)
        port = (try? c.decodeIfPresent(Int.self, forKey: .port)) ?? 22
        user = (try? c.decodeIfPresent(String.self, forKey: .user)) ?? "root"
        // The server writes key/jump as null when they are not configured.
        key = (try? c.decodeIfPresent(String.self, forKey: .key)) ?? ""
        jump = try? c.decodeIfPresent(String.self, forKey: .jump)
    }
}

struct HostDocker: Codable, Hashable {
    var container: String = ""
    var host: String?
}

struct PlatformHost: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var role: HostRole
    var address: String
    var ports: [Int]
    var ssh: HostSSH?
    var clientSSH: HostSSH?
    var docker: HostDocker?
    var source: String?
    var tags: [String]
    var notes: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, role, address, ports, ssh, docker, source, tags, notes
        case createdAt = "created_at"
        case clientSSH = "client_ssh"
    }

    init(id: String = "", name: String, role: HostRole, address: String = "",
         ports: [Int] = [], ssh: HostSSH? = nil, docker: HostDocker? = nil,
         source: String? = "manual", tags: [String] = [], notes: String = "",
         createdAt: String? = nil, clientSSH: HostSSH? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.address = address
        self.ports = ports
        self.ssh = ssh
        self.clientSSH = clientSSH
        self.docker = docker
        self.source = source
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "未命名主机"
        role = (try? c.decodeIfPresent(HostRole.self, forKey: .role)) ?? .target
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        ports = (try? c.decodeIfPresent([Int].self, forKey: .ports)) ?? []
        ssh = try? c.decodeIfPresent(HostSSH.self, forKey: .ssh)
        clientSSH = try? c.decodeIfPresent(HostSSH.self, forKey: .clientSSH)
        docker = try? c.decodeIfPresent(HostDocker.self, forKey: .docker)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        notes = (try? c.decodeIfPresent(String.self, forKey: .notes)) ?? ""
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var displayAddress: String {
        if let container = docker?.container, !container.isEmpty { return "docker · \(container)" }
        if !address.isEmpty {
            if let first = ports.first { return "\(address):\(first)" }
            return address
        }
        return "未填写地址"
    }

    var transportLabel: String {
        if docker != nil { return "Arena 容器" }
        if ssh != nil { return "SSH" }
        return "TCP 探测"
    }
}

struct HostProbe: Codable, Identifiable, Hashable {
    var hostId: String
    var online: Bool
    var reachable: Bool
    var sshOk: Bool?
    var dockerOk: Bool?
    var latencyMs: Int?
    var checkedFrom: String?
    var detail: String?
    var error: String?

    var id: String { hostId }

    init(hostId: String = "", online: Bool = false, reachable: Bool = false,
         sshOk: Bool? = nil, dockerOk: Bool? = nil, latencyMs: Int? = nil,
         checkedFrom: String? = "mac", detail: String? = nil, error: String? = nil) {
        self.hostId = hostId
        self.online = online
        self.reachable = reachable
        self.sshOk = sshOk
        self.dockerOk = dockerOk
        self.latencyMs = latencyMs
        self.checkedFrom = checkedFrom
        self.detail = detail
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case online, reachable, detail, error
        case hostId = "host_id"
        case sshOk = "ssh_ok", dockerOk = "docker_ok"
        case latencyMs = "latency_ms", checkedFrom = "checked_from"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hostId = (try? c.decodeIfPresent(String.self, forKey: .hostId)) ?? ""
        online = (try? c.decodeIfPresent(Bool.self, forKey: .online)) ?? false
        reachable = (try? c.decodeIfPresent(Bool.self, forKey: .reachable)) ?? false
        sshOk = try? c.decodeIfPresent(Bool.self, forKey: .sshOk)
        dockerOk = try? c.decodeIfPresent(Bool.self, forKey: .dockerOk)
        latencyMs = try? c.decodeIfPresent(Int.self, forKey: .latencyMs)
        checkedFrom = try? c.decodeIfPresent(String.self, forKey: .checkedFrom)
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
        error = try? c.decodeIfPresent(String.self, forKey: .error)
    }
}

// MARK: - Topology

struct Topology: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var target: String
    var attacker: String
    var network: String?
    var status: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, target, attacker, network, status
        case createdAt = "created_at"
    }

    var ready: Bool { status == "ready" }
}

struct TopologyTest: Codable {
    var ok: Bool
    var status: String?
    var target: HostProbe?
    var attacker: HostProbe?
    var attackerToTarget: HostProbe?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case ok, status, target, attacker, error
        case attackerToTarget = "attacker_to_target"
    }
}

// MARK: - Events

struct EventTeam: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var target: String?
    var attacker: String?
    /// AWD topologies: every team can own several service and attacker hosts.
    /// Events created before AWD support only carry `target` / `attacker`.
    var services: [String]?
    var attackers: [String]?
    var verified: Bool?
    var verifiedAt: String?
    var verifiedDetail: String?

    enum CodingKeys: String, CodingKey {
        case id, name, target, attacker, services, attackers, verified
        case verifiedAt = "verified_at"
        case verifiedDetail = "verified_detail"
    }

    init(id: String = UUID().uuidString.prefix(8).lowercased(), name: String,
         target: String? = nil, attacker: String? = nil,
         services: [String]? = nil, attackers: [String]? = nil,
         verified: Bool? = nil, verifiedAt: String? = nil,
         verifiedDetail: String? = nil) {
        self.id = id
        self.name = name
        self.target = target
        self.attacker = attacker
        self.services = services
        self.attackers = attackers
        self.verified = verified
        self.verifiedAt = verifiedAt
        self.verifiedDetail = verifiedDetail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "未命名队伍"
        target = try? c.decodeIfPresent(String.self, forKey: .target)
        attacker = try? c.decodeIfPresent(String.self, forKey: .attacker)
        services = try? c.decodeIfPresent([String].self, forKey: .services)
        attackers = try? c.decodeIfPresent([String].self, forKey: .attackers)
        verified = try? c.decodeIfPresent(Bool.self, forKey: .verified)
        verifiedAt = try? c.decodeIfPresent(String.self, forKey: .verifiedAt)
        verifiedDetail = try? c.decodeIfPresent(String.self, forKey: .verifiedDetail)
    }

    /// All service hosts, falling back to the legacy single target.
    var allServices: [String] {
        if let services, !services.isEmpty { return services }
        return target.map { [$0] } ?? []
    }

    /// All attacker hosts, falling back to the legacy single attacker.
    var allAttackers: [String] {
        if let attackers, !attackers.isEmpty { return attackers }
        return attacker.map { [$0] } ?? []
    }

    var primaryService: String? { services?.first ?? target }
    var primaryAttacker: String? { attackers?.first ?? attacker }
}

// MARK: - AWD status

/// One container belonging to an AWD team (service or attacker machine).
struct AWDHostStatus: Codable, Identifiable, Hashable {
    var hostId: String
    var container: String?
    var state: String?
    var httpOk: Bool?
    var httpStatus: Int?
    var port: Int?

    var id: String { hostId }

    enum CodingKeys: String, CodingKey {
        case container, state, port
        case hostId = "host_id"
        case httpOk = "http_ok"
        case httpStatus = "http_status"
    }

    init(hostId: String = "", container: String? = nil, state: String? = nil,
         httpOk: Bool? = nil, httpStatus: Int? = nil, port: Int? = nil) {
        self.hostId = hostId
        self.container = container
        self.state = state
        self.httpOk = httpOk
        self.httpStatus = httpStatus
        self.port = port
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hostId = (try? c.decodeIfPresent(String.self, forKey: .hostId)) ?? ""
        container = try? c.decodeIfPresent(String.self, forKey: .container)
        state = try? c.decodeIfPresent(String.self, forKey: .state)
        httpOk = try? c.decodeIfPresent(Bool.self, forKey: .httpOk)
        httpStatus = try? c.decodeIfPresent(Int.self, forKey: .httpStatus)
        port = try? c.decodeIfPresent(Int.self, forKey: .port)
    }

    var running: Bool { state == "running" }
}

/// One AWD team with the state of each of its machines.
struct AWDTeamStatus: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var running: Bool
    var ready: Bool
    var verified: Bool
    var verifiedAt: String?
    var verifiedDetail: String?
    var services: [AWDHostStatus]
    var attackers: [AWDHostStatus]

    enum CodingKeys: String, CodingKey {
        case id, name, running, ready, verified, services, attackers
        case verifiedAt = "verified_at"
        case verifiedDetail = "verified_detail"
    }

    init(id: String = "", name: String = "", running: Bool = false, ready: Bool = false,
         verified: Bool = false, verifiedAt: String? = nil, verifiedDetail: String? = nil,
         services: [AWDHostStatus] = [], attackers: [AWDHostStatus] = []) {
        self.id = id
        self.name = name
        self.running = running
        self.ready = ready
        self.verified = verified
        self.verifiedAt = verifiedAt
        self.verifiedDetail = verifiedDetail
        self.services = services
        self.attackers = attackers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? id
        running = (try? c.decodeIfPresent(Bool.self, forKey: .running)) ?? false
        ready = (try? c.decodeIfPresent(Bool.self, forKey: .ready)) ?? false
        verified = (try? c.decodeIfPresent(Bool.self, forKey: .verified)) ?? false
        verifiedAt = try? c.decodeIfPresent(String.self, forKey: .verifiedAt)
        verifiedDetail = try? c.decodeIfPresent(String.self, forKey: .verifiedDetail)
        services = (try? c.decodeIfPresent([AWDHostStatus].self, forKey: .services)) ?? []
        attackers = (try? c.decodeIfPresent([AWDHostStatus].self, forKey: .attackers)) ?? []
    }
}

/// Per-team outcome of `arenactl awd verify`.
struct AWDVerifyResult: Codable, Identifiable, Hashable {
    var teamId: String
    var ok: Bool
    var detail: String?
    var services: [AWDHostStatus]
    var attackers: [AWDHostStatus]
    /// True when nothing was running, so the server kept the previous verdict.
    var untested: Bool?

    var id: String { teamId }

    enum CodingKeys: String, CodingKey {
        case ok, detail, services, attackers, untested
        case teamId = "team_id"
    }

    init(teamId: String = "", ok: Bool = false, detail: String? = nil,
         services: [AWDHostStatus] = [], attackers: [AWDHostStatus] = [],
         untested: Bool? = nil) {
        self.teamId = teamId
        self.ok = ok
        self.detail = detail
        self.services = services
        self.attackers = attackers
        self.untested = untested
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teamId = (try? c.decodeIfPresent(String.self, forKey: .teamId)) ?? ""
        ok = (try? c.decodeIfPresent(Bool.self, forKey: .ok)) ?? false
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
        services = (try? c.decodeIfPresent([AWDHostStatus].self, forKey: .services)) ?? []
        attackers = (try? c.decodeIfPresent([AWDHostStatus].self, forKey: .attackers)) ?? []
        untested = try? c.decodeIfPresent(Bool.self, forKey: .untested)
    }
}

struct AWDVerifyResponse: Codable {
    var ok: Bool
    var results: [AWDVerifyResult]
    var event: ArenaEvent?
    var error: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AWDVerifyResponse.CodingKeys.self)
        ok = (try? c.decodeIfPresent(Bool.self, forKey: .ok)) ?? false
        results = (try? c.decodeIfPresent([AWDVerifyResult].self, forKey: .results)) ?? []
        event = try? c.decodeIfPresent(ArenaEvent.self, forKey: .event)
        error = try? c.decodeIfPresent(String.self, forKey: .error)
    }

    enum CodingKeys: String, CodingKey { case ok, results, event, error }
}

struct AWDStatusResponse: Codable {
    var ok: Bool
    var teams: [AWDTeamStatus]
    var error: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AWDStatusResponse.CodingKeys.self)
        ok = (try? c.decodeIfPresent(Bool.self, forKey: .ok)) ?? false
        teams = (try? c.decodeIfPresent([AWDTeamStatus].self, forKey: .teams)) ?? []
        error = try? c.decodeIfPresent(String.self, forKey: .error)
    }

    enum CodingKeys: String, CodingKey { case ok, teams, error }
}

struct ArenaEvent: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var format: String
    var status: String
    var teams: [EventTeam]
    var hosts: [String]
    var observer: Bool
    var agents: Bool
    var invite: String?
    var createdAt: String?
    var startedAt: String?
    var endedAt: String?
    /// True for events whose service/attacker containers are created and
    /// managed by Arena itself (`Arena-awd-*`).
    var awd: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, format, status, teams, hosts, observer, agents, invite, awd
        case createdAt = "created_at", startedAt = "started_at", endedAt = "ended_at"
    }

    var running: Bool { status == "running" }
    var formatLabel: String {
        switch format {
        case "awd": return "AWD 攻防"
        case "koh": return "King of the Hill"
        default: return "自定义"
        }
    }
}

struct AgentHeartbeat: Codable, Identifiable, Hashable {
    var hostId: String
    var name: String?
    var role: String?
    var hostname: String?
    var lastSeen: String?
    var seen: String?
    var detail: String?
    var load: [Double]?
    var ageSeconds: Int?
    var fresh: Bool?

    var id: String { hostId }

    enum CodingKeys: String, CodingKey {
        case name, role, hostname, detail, seen, load, fresh
        case hostId = "host_id", lastSeen = "last_seen"
        case ageSeconds = "age_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hostId = (try? c.decodeIfPresent(String.self, forKey: .hostId)) ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        role = try? c.decodeIfPresent(String.self, forKey: .role)
        hostname = try? c.decodeIfPresent(String.self, forKey: .hostname)
        lastSeen = try? c.decodeIfPresent(String.self, forKey: .lastSeen)
        seen = try? c.decodeIfPresent(String.self, forKey: .seen)
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
        load = try? c.decodeIfPresent([Double].self, forKey: .load)
        ageSeconds = try? c.decodeIfPresent(Int.self, forKey: .ageSeconds)
        fresh = try? c.decodeIfPresent(Bool.self, forKey: .fresh)
    }

    var lastSeenLabel: String? {
        if let ageSeconds { return ageSeconds < 60 ? "\(ageSeconds) 秒前" : "\(ageSeconds / 60) 分钟前" }
        return lastSeen
    }
}

struct AgentActivity: Codable, Identifiable, Hashable {
    var hostId: String
    var kind: String?
    var summary: String
    var target: String?
    var detail: String?
    var at: String?
    var receivedAt: String?

    var id: String { "\(hostId)-\(receivedAt ?? at ?? "")-\(summary)" }

    enum CodingKeys: String, CodingKey {
        case kind, summary, target, detail, at
        case hostId = "host_id", receivedAt = "received_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hostId = (try? c.decodeIfPresent(String.self, forKey: .hostId)) ?? ""
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        summary = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        target = try? c.decodeIfPresent(String.self, forKey: .target)
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
        at = try? c.decodeIfPresent(String.self, forKey: .at)
        receivedAt = try? c.decodeIfPresent(String.self, forKey: .receivedAt)
    }
}

struct EventStatus: Codable {
    var ok: Bool
    var event: ArenaEvent?
    var hosts: [HostProbe]?
    var probes: [String: HostProbe]?
    var agents: [AgentHeartbeat]?
    var activities: [AgentActivity]?
    var error: String?
}

// MARK: - Responses

struct HostsResponse: Codable {
    var ok: Bool
    var hosts: [PlatformHost]?
    var error: String?
}

struct TopologiesResponse: Codable {
    var ok: Bool
    var topologies: [Topology]?
    var error: String?
}

struct EventsResponse: Codable {
    var ok: Bool
    var events: [ArenaEvent]?
    var error: String?
}

struct InviteResponse: Codable {
    var ok: Bool
    var invite: InvitePayload?
    var text: String?
    var error: String?
}

struct InvitePayload: Codable {
    var id: String?
    var name: String?
    var format: String?
    var status: String?
    var invite: String?
    var observer: Bool?
    var createdAt: String?
    var startedAt: String?
    var teams: [InviteTeam]?
    var notes: [String]?
    var hosts: [InviteHost]?
    var accessNote: String?

    enum CodingKeys: String, CodingKey {
        case id, name, format, status, invite, observer, teams, notes, hosts
        case createdAt = "created_at"
        case startedAt = "started_at"
        case accessNote = "access_note"
    }
}

struct InviteTeam: Codable, Identifiable {
    var id: String
    var name: String
    var target: InviteHost?
    var attacker: InviteHost?
    var services: [InviteHost]?
    var attackers: [InviteHost]?
}

struct InviteHost: Codable, Identifiable {
    var hostId: String?
    var name: String?
    var role: String?
    var address: String?
    var ports: [Int]?
    var team: String?
    var unknown: Bool?

    enum CodingKeys: String, CodingKey {
        case name, role, address, ports, team, unknown
        case hostId = "id"
    }

    var id: String { hostId ?? "\(team ?? "")-\(name ?? "")-\(address ?? "")" }
}

// MARK: - API

enum PlatformAPI {
    private static let decoder = JSONDecoder()

    static func hosts() async throws -> [PlatformHost] {
        let response: HostsResponse = try decode(try await SSH.arena("arenactl hosts list --json", timeout: 45))
        if !response.ok { throw SSHError.badResponse(response.error ?? "读取主机失败") }
        return response.hosts ?? []
    }

    static func addHost(_ host: PlatformHost) async throws -> PlatformHost? {
        let payload = try encode(host)
        let text = try await SSH.arena("arenactl hosts add \(quote(payload)) --json", timeout: 45)
        let response: HostMutationResponse = try decode(text)
        if !response.ok { throw SSHError.badResponse(response.error ?? "添加主机失败") }
        return response.host
    }

    static func updateHost(_ host: PlatformHost) async throws -> PlatformHost? {
        let payload = try encode(host)
        let text = try await SSH.arena("arenactl hosts update \(quote(payload)) --json", timeout: 45)
        let response: HostMutationResponse = try decode(text)
        if !response.ok { throw SSHError.badResponse(response.error ?? "更新主机失败") }
        return response.host
    }

    static func removeHost(_ id: String) async throws {
        let response: SimpleResponse = try decode(try await SSH.arena("arenactl hosts remove \(safe(id)) --json", timeout: 45))
        if !response.ok { throw SSHError.badResponse(response.error ?? "删除主机失败") }
    }

    static func probeHost(_ id: String) async throws -> HostProbe {
        let text = try await SSH.arena("arenactl hosts probe \(safe(id)) --json", timeout: 60)
        let response: ProbeResponse = try decode(text)
        if let probe = response.probe ?? response.host_probe { return probe }
        // `hosts probe` returns the probe fields at the top level.
        if response.ok {
            var probe: HostProbe = try decode(text)
            if probe.hostId.isEmpty { probe.hostId = id }
            return probe
        }
        throw SSHError.badResponse(response.error ?? "探测失败")
    }

    static func topologies() async throws -> [Topology] {
        let response: TopologiesResponse = try decode(try await SSH.arena("arenactl topologies list --json", timeout: 45))
        if !response.ok { throw SSHError.badResponse(response.error ?? "读取拓扑失败") }
        return response.topologies ?? []
    }

    static func addTopology(name: String, target: String, attacker: String) async throws -> Topology? {
        let payload = try encode(["name": name, "target": target, "attacker": attacker])
        let response: TopologyMutationResponse = try decode(
            try await SSH.arena("arenactl topologies add \(quote(payload)) --json", timeout: 45))
        if !response.ok { throw SSHError.badResponse(response.error ?? "创建拓扑失败") }
        return response.topology
    }

    static func removeTopology(_ id: String) async throws {
        let response: SimpleResponse = try decode(try await SSH.arena("arenactl topologies remove \(safe(id)) --json", timeout: 45))
        if !response.ok { throw SSHError.badResponse(response.error ?? "删除拓扑失败") }
    }

    static func testTopology(_ id: String) async throws -> TopologyTest {
        let response: TopologyTest = try decode(
            try await SSH.arena("arenactl topologies test \(safe(id)) --json", timeout: 90))
        if !response.ok { throw SSHError.badResponse(response.error ?? "拓扑检测失败") }
        return response
    }

    static func events() async throws -> [ArenaEvent] {
        let response: EventsResponse = try decode(try await SSH.arena("arenactl events list --json", timeout: 45))
        if !response.ok { throw SSHError.badResponse(response.error ?? "读取赛事失败") }
        return response.events ?? []
    }

    static func createEvent(_ event: ArenaEvent) async throws -> ArenaEvent? {
        let payload = try encode(event)
        let response: EventMutationResponse = try decode(
            try await SSH.arena("arenactl events create \(quote(payload)) --json", timeout: 60))
        if !response.ok { throw SSHError.badResponse(response.error ?? "创建赛事失败") }
        return response.event
    }

    static func removeEvent(_ id: String) async throws {
        let response: SimpleResponse = try decode(try await SSH.arena("arenactl events remove \(safe(id)) --json", timeout: 300))
        if !response.ok { throw SSHError.badResponse(response.error ?? "删除赛事失败") }
    }

    static func startEvent(_ id: String) async throws -> EventStatus {
        try decode(try await SSH.arena("arenactl events start \(safe(id)) --json", timeout: 120))
    }

    static func stopEvent(_ id: String) async throws -> EventStatus {
        try decode(try await SSH.arena("arenactl events stop \(safe(id)) --json", timeout: 120))
    }

    static func eventStatus(_ id: String) async throws -> EventStatus {
        let status: EventStatus = try decode(
            try await SSH.arena("arenactl events status \(safe(id)) --json", timeout: 120))
        if !status.ok { throw SSHError.badResponse(status.error ?? "读取赛事状态失败") }
        return status
    }

    static func invite(_ id: String) async throws -> InviteResponse {
        try decode(try await SSH.arena("arenactl events invite \(safe(id)) --json", timeout: 45))
    }

    // MARK: AWD arena

    /// Create a self-contained AWD arena.  The server provisions up to five
    /// teams, each with its own service and attacker containers, and registers
    /// every container as a host.  Nothing is started by this call.
    static func awdCreate(name: String, teams: Int, services: Int, attackers: Int) async throws -> AWDCreateResponse {
        let payload = try encode(AWDCreatePayload(name: name, teams: teams,
                                                  services: services, attackers: attackers))
        let response: AWDCreateResponse = try decode(
            try await SSH.arena("arenactl awd create \(quote(payload)) --json", timeout: 240))
        if !response.ok { throw SSHError.badResponse(response.error ?? "生成 Arena 演练失败") }
        return response
    }

    /// Start the selected teams (all teams when `teamIDs` is empty).
    /// The response may be a partial success: some machines started while
    /// others failed, so callers get the per-host errors instead of a throw.
    static func awdStart(eventID: String, teamIDs: [String]) async throws -> AWDActionResponse {
        let command = "arenactl awd start \(safe(eventID))\(awdTeamsFlag(teamIDs)) --json"
        return try decode(try await SSH.arena(command, timeout: 300))
    }

    /// Stop the selected teams (all teams when `teamIDs` is empty).
    static func awdStop(eventID: String, teamIDs: [String]) async throws -> AWDActionResponse {
        let command = "arenactl awd stop \(safe(eventID))\(awdTeamsFlag(teamIDs)) --json"
        return try decode(try await SSH.arena(command, timeout: 300))
    }

    /// Probe every service and attacker container and return per-team results.
    static func awdVerify(eventID: String, teamIDs: [String]) async throws -> [AWDVerifyResult] {
        let command = "arenactl awd verify \(safe(eventID))\(awdTeamsFlag(teamIDs)) --json"
        let response: AWDVerifyResponse = try decode(try await SSH.arena(command, timeout: 300))
        if !response.ok { throw SSHError.badResponse(response.error ?? "验证 AWD 赛队失败") }
        return response.results
    }

    /// Container-level status for every team in the arena.
    static func awdStatus(eventID: String) async throws -> [AWDTeamStatus] {
        let response: AWDStatusResponse = try decode(
            try await SSH.arena("arenactl awd status \(safe(eventID)) --json", timeout: 120))
        if !response.ok { throw SSHError.badResponse(response.error ?? "读取 AWD 赛队状态失败") }
        return response.teams
    }

    private static func awdTeamsFlag(_ teamIDs: [String]) -> String {
        let ids = teamIDs.map { safe($0) }.filter { !$0.isEmpty }
        guard !ids.isEmpty else { return "" }
        return " --teams " + ids.joined(separator: ",")
    }

    // MARK: Encoding

    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SSHError.badResponse("无法编码请求")
        }
        return text
    }

    private static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func safe(_ id: String) -> String {
        id.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func decode<T: Decodable>(_ text: String) throws -> T {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{") else {
            throw SSHError.badResponse("服务器返回了无法解析的数据")
        }
        do {
            return try decoder.decode(T.self, from: Data(trimmed[start...].utf8))
        } catch {
            throw SSHError.badResponse("解析服务器响应失败：\(error.localizedDescription)")
        }
    }
}

private struct SimpleResponse: Codable {
    var ok: Bool
    var error: String?
}

private struct HostMutationResponse: Codable {
    var ok: Bool
    var host: PlatformHost?
    var error: String?
}

private struct ProbeResponse: Codable {
    var ok: Bool
    var error: String?
    var probe: HostProbe?
    var host_probe: HostProbe?

    enum CodingKeys: String, CodingKey {
        case ok, error, probe, host_probe
    }
}

private struct TopologyMutationResponse: Codable {
    var ok: Bool
    var topology: Topology?
    var error: String?
}

private struct EventMutationResponse: Codable {
    var ok: Bool
    var event: ArenaEvent?
    var error: String?
}

private struct AWDCreatePayload: Encodable {
    var name: String
    var teams: Int
    var services: Int
    var attackers: Int
}

struct AWDCreateResponse: Codable {
    var ok: Bool
    var event: ArenaEvent?
    var hosts: [PlatformHost]?
    var count: Int?
    var error: String?
}

struct AWDHostError: Codable, Hashable {
    var host: String?
    var container: String?
    var error: String?
}

struct AWDActionResponse: Codable {
    var ok: Bool
    var error: String?
    var started: [AWDHostAction]?
    var stopped: [String]?
    var errors: [AWDHostError]?
    var teams: [String]?
}

struct AWDHostAction: Codable, Hashable {
    var team: String?
    var host: String?
    var container: String?
    var action: String?
}
