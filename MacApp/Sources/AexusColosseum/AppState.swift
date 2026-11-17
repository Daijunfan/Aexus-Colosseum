import Foundation
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case connection, environments, sources, about
    var id: String { rawValue }
    var label: String {
        switch self {
        case .connection: return "连接"
        case .environments: return "环境管理"
        case .sources: return "来源"
        case .about: return "关于"
        }
    }
    var symbol: String {
        switch self {
        case .connection: return "bolt.horizontal.circle"
        case .environments: return "square.stack.3d.up"
        case .sources: return "tray.and.arrow.down"
        case .about: return "seal"
        }
    }
}

struct ActivityBanner: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let success: Bool
}

/// The event a workspace was opened from.  Keeping the event and team here
/// (instead of only in the view) lets the workspace point at the right hosts
/// even when the active topology belongs to something else.  Memory only: a
/// relaunch returns to the regular topology view.
struct WorkspaceContext: Equatable {
    var eventID: String
    var eventName: String
    var teamID: String
    var teamName: String
    var attackerID: String?
    var targetID: String?
}

@MainActor
final class AppState: ObservableObject {
    let connections = LabConnections()
    let pit = PitClient()
    // Catalog
    @Published var categories: [CatalogCategory] = []
    @Published var labs: [Lab] = []
    @Published var catalogDate: Date?
    @Published var trainingCollections: [TrainingCollection] = []

    // Server
    @Published var vm: VMInfo?
    @Published var kaliVM: VMInfo?
    @Published var host: ArenaHostInfo?
    @Published var vmBusy = false
    @Published var loading = false
    @Published var lastRefresh: Date?
    @Published var reachable: Bool?

    // Navigation (Game-First Default: The Pit Lobby)
    @Published var mode: AppMode = .pitArena
    var nav: AppMode {
        get { mode }
        set { mode = newValue }
    }
    @Published var hudSidebarCollapsed = false
    @Published var uiScale: Double = 1.0
    @Published var armorySection: String = "maps"
    @Published var lobbySubSection: String = "create"
    @Published var scope: LibraryScope = .all
    @Published var sourceFilter: SourceFilter = .all
    @Published var searchText = ""
    @Published var selectedLabID: String?
    @Published var settingsOpen = false
    @Published var settingsTab: SettingsTab = .connection

    // Platform: hosts, topologies, events
    @Published var hosts: [PlatformHost] = []
    @Published var topologies: [Topology] = []
    @Published var events: [ArenaEvent] = []
    @Published var hostProbes: [String: HostProbe] = [:]
    @Published var eventStatuses: [String: EventStatus] = [:]
    @Published var selectedHostID: String?
    @Published var selectedEventID: String?
    @Published var selectedTopologyID: String?
    @Published var workspaceLabID: String?
    @Published var platformLoading = false
    @Published var platformLoaded = false
    @Published var platformError: String?
    @Published var probeBusy: Set<String> = []
    @Published var topologyBusy: Set<String> = []
    @Published var eventBusy: Set<String> = []

    // AWD arena: per-event container teams, verify results and in-flight work.
    // Busy tokens are "<eventID>:<action>" so independent teams stay responsive.
    @Published var awdTeams: [String: [AWDTeamStatus]] = [:]
    @Published var awdVerifyResults: [String: [AWDVerifyResult]] = [:]
    @Published var awdStatusError: [String: String] = [:]
    @Published var awdBusy: Set<String> = []

    // Participation: event ID -> team ID.  Persisted across launches.
    @Published var eventParticipation: [String: String] = [:]
    @Published var workspaceContext: WorkspaceContext?

    // Work in flight
    @Published var startingLabs: Set<String> = []
    @Published var stoppingLabs: Set<String> = []
    @Published var installingLabs: Set<String> = []
    @Published var removingLabs: Set<String> = []
    @Published var deleteSelection: Set<String> = []

    // Messaging
    @Published var banner: ActivityBanner?
    @Published var errorMessage: String?
    @Published var confirmRemoveIDs: [String] = []
    @Published var confirmStopVM = false

    private var bannerTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    private static let participationKey = "arena.participation"
    private static let uiScaleKey = "arena.uiScale"

    init() {
        loadCachedCatalog()
        let savedScale = UserDefaults.standard.double(forKey: Self.uiScaleKey)
        if savedScale >= 0.75 && savedScale <= 1.50 {
            uiScale = savedScale
        }
        if let stored = UserDefaults.standard.dictionary(forKey: Self.participationKey) as? [String: String] {
            eventParticipation = stored
        }
        let env = ProcessInfo.processInfo.environment
        if let ui = env["AEXUS_UI"], ui == "settings" {
            settingsOpen = true
            if let tab = env["AEXUS_TAB"], let value = SettingsTab(rawValue: tab) {
                settingsTab = value
            }
        }
        if let raw = env["AEXUS_MODE"], let value = AppMode(rawValue: raw) {
            mode = value
        }
        if let raw = env["AEXUS_TOPOLOGY"], !raw.isEmpty {
            selectedTopologyID = raw
        }
        if let raw = env["AEXUS_EVENT"], !raw.isEmpty {
            selectedEventID = raw
        }
        if let lab = env["AEXUS_LAB"], !lab.isEmpty {
            selectedLabID = lab
        }
        #if DEBUG
        if env["AEXUS_UI"] == "awd-demo" {
            DemoFixtures.install(into: self)
        }
        #endif
    }

    // MARK: - Derived

    var runningLabs: [Lab] { labs.filter(\.running) }
    var installedLabs: [Lab] { labs.filter(\.installed) }
    var availableLabs: [Lab] { labs.filter { !$0.installed } }
    var activeLab: Lab? { runningLabs.first }

    var serverReady: Bool { vm?.ready == true }
    var serverRunning: Bool { vm?.running == true }

    var selectedLab: Lab? {
        guard let id = selectedLabID else { return nil }
        return labs.first(where: { $0.id == id })
    }

    var scopeTitle: String {
        switch scope {
        case .all: return "地图与军火素材库"
        case .running: return "正在运行"
        case .installed: return "已安装环境"
        case .available: return "可下载环境"
        case .category(let id): return category(id)?.name ?? "分类"
        }
    }

    var scopeBlurb: String {
        switch scope {
        case .all: return "收录 \(labs.count)+ 真实 CTF/CVE 靶标与五大传奇开源渗透 Harness 舰队，一键抽调投入斗兽场实网死斗。"
        case .running: return "当前占用内存的实验环境。"
        case .installed: return "已落盘、可立即启动的环境。"
        case .available: return "仍在来源目录中，一键下载到服务器。"
        case .category(let id): return category(id)?.blurb ?? ""
        }
    }

    var filteredLabs: [Lab] {
        var result = labs

        switch scope {
        case .running: result = result.filter(\.running)
        case .installed: result = result.filter(\.installed)
        case .available: result = result.filter { !$0.installed }
        case .category(let id): result = result.filter { $0.category == id }
        case .all: break
        }

        switch sourceFilter {
        case .all: break
        case .curated: result = result.filter { $0.source == "curated" }
        case .vulhub: result = result.filter { $0.source == "vulhub" }
        }

        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !needle.isEmpty {
            result = result.filter { lab in
                lab.name.lowercased().contains(needle)
                || lab.subtitle.lowercased().contains(needle)
                || lab.summary.lowercased().contains(needle)
                || lab.id.lowercased().contains(needle)
                || lab.tags.contains(where: { $0.lowercased().contains(needle) })
                || lab.mitre.contains(where: { $0.lowercased().contains(needle) })
            }
        }

        let order = Dictionary(uniqueKeysWithValues: categories.enumerated().map { ($1.id, $0) })
        return result.sorted { a, b in
            let ca = order[a.category] ?? 99
            let cb = order[b.category] ?? 99
            if ca != cb { return ca < cb }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    func category(_ id: String) -> CatalogCategory? {
        categories.first(where: { $0.id == id })
    }

    func count(in scope: LibraryScope) -> Int {
        switch scope {
        case .all: return labs.count
        case .running: return runningLabs.count
        case .installed: return installedLabs.count
        case .available: return availableLabs.count
        case .category(let id): return labs.filter { $0.category == id }.count
        }
    }

    func categoryColor(_ id: String) -> Color {
        Color(hex: category(id)?.color ?? "#8A8A92")
    }

    func isBusy(_ id: String) -> Bool {
        startingLabs.contains(id) || stoppingLabs.contains(id)
            || installingLabs.contains(id) || removingLabs.contains(id)
    }

    var runningMemoryLabel: String {
        let bytes = runningLabs.reduce(0) { $0 + $1.memBytes }
        guard bytes > 0 else { return "0 MB" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    var installedMemoryFootprint: String {
        let mb = installedLabs.reduce(0) { $0 + $1.ramMB }
        if mb >= 1024 {
            let gb = Double(mb) / 1024
            return gb >= 10 ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
        }
        return "\(mb) MB"
    }

    var vmMemoryUsedFraction: Double {
        guard let total = host?.memTotal, total > 0, let avail = host?.memAvailable else { return 0 }
        return max(0, min(1, Double(total - avail) / Double(total)))
    }

    var vmDiskUsedFraction: Double {
        guard let total = host?.diskTotal, total > 0, let used = host?.diskUsed else { return 0 }
        return max(0, min(1, Double(used) / Double(total)))
    }

    // MARK: - Loading

    func loadCachedCatalog() {
        if let cached = Self.readCache(), !cached.labs.isEmpty {
            apply(cached)
            return
        }
        if let url = Bundle.module.url(forResource: "catalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(CatalogFile.self, from: data) {
            apply(file)
        }
    }

    func connect() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let info = try await ArenaAPI.hostInfo()
            vm = info
            kaliVM = try? await ArenaAPI.kaliInfo()
            reachable = info.ok
            if info.ready == true {
                async let catalogRefresh: Void = refresh(showSpinner: false)
                async let platformRefresh: Void = loadPlatform()
                _ = await (catalogRefresh, platformRefresh)
            } else {
                host = nil
            }
        } catch {
            vm = nil
            reachable = false
            present(error)
        }
    }

    func refresh(showSpinner: Bool = true) async {
        guard vm?.ready != false else { return }
        if showSpinner { loading = true }
        defer { loading = false }
        do {
            let response = try await ArenaAPI.list()
            if let categories = response.categories, !categories.isEmpty {
                self.categories = categories
            }
            if let labs = response.labs {
                self.labs = labs
                connections.closeStoppedLabs(runningIDs: Set(labs.filter(\.running).map(\.id)))
                catalogDate = Date()
                Self.writeCache(CatalogFile(version: 1, generatedAt: response.generatedAt,
                                            categories: self.categories, labs: labs))
            }
            reachable = true
            lastRefresh = Date()
        } catch {
            if case SSHError.failed = error {
                reachable = false
            }
            present(error)
        }
        if let info = try? await ArenaAPI.info() {
            host = info
        }
        if let lab = activeLab {
            // keep the currently focused lab in sync
            _ = lab
        }
    }

    private func apply(_ file: CatalogFile) {
        categories = file.categories
        labs = file.labs
        pit.mergeCatalogLabs(file.labs)
        if let raw = file.generatedAt, let date = ISO8601DateFormatter().date(from: raw) {
            catalogDate = date
        }
    }

    // MARK: - VM control

    func startServer() async {
        guard !vmBusy else { return }
        vmBusy = true
        defer { vmBusy = false }
        banner = ActivityBanner(text: "正在启动 Arena 虚拟机…", success: true)
        do {
            let info = try await ArenaAPI.startVM()
            vm = info
            if info.ready == true {
                show(ActivityBanner(text: "Arena 已就绪", success: true))
                await refresh(showSpinner: false)
            } else {
                presentError(info.error ?? "虚拟机已启动，但 SSH 尚未就绪")
            }
        } catch {
            present(error)
        }
    }

    func stopServer() async {
        guard !vmBusy else { return }
        vmBusy = true
        defer { vmBusy = false }
        banner = ActivityBanner(text: "正在关闭 Arena…", success: true)
        do {
            // Stop every environment first so compose has a chance to clean up.
            _ = try? await ArenaAPI.stopAll()
            let info = try await ArenaAPI.stopVM()
            vm = info
            host = nil
            connections.closeAll()
            labs = labs.map { var copy = $0; copy.running = false; copy.memBytes = 0; copy.memHuman = ""; copy.containers = []; return copy }
            show(ActivityBanner(text: "Arena 已关闭，硬盘数据保留", success: true))
        } catch {
            present(error)
        }
    }

    // MARK: - Lab control

    func start(_ lab: Lab) async {
        guard serverReady else {
            presentError("请先启动 Arena 服务器")
            return
        }
        guard !isBusy(lab.id) else { return }
        startingLabs.insert(lab.id)
        defer { startingLabs.remove(lab.id) }
        do {
            let response = try await ArenaAPI.start(lab.id)
            guard response.ok else { throw SSHError.failed(response.error ?? "启动失败") }
            show(ActivityBanner(text: "\(lab.name) 已启动", success: true))
            await refresh(showSpinner: false)
            selectedLabID = lab.id
        } catch {
            present(error)
        }
    }

    func stop(_ lab: Lab) async {
        guard !isBusy(lab.id) else { return }
        stoppingLabs.insert(lab.id)
        defer { stoppingLabs.remove(lab.id) }
        do {
            let response = try await ArenaAPI.stop(lab.id)
            guard response.ok else { throw SSHError.failed(response.error ?? "停止失败") }
            show(ActivityBanner(text: "\(lab.name) 已停止", success: true))
            await refresh(showSpinner: false)
        } catch {
            present(error)
        }
    }

    func toggle(_ lab: Lab) async {
        if lab.running { await stop(lab) } else { await start(lab) }
    }

    func install(_ lab: Lab) async {
        guard serverReady else {
            presentError("请先启动 Arena 服务器")
            return
        }
        guard !isBusy(lab.id) else { return }
        installingLabs.insert(lab.id)
        defer { installingLabs.remove(lab.id) }
        banner = ActivityBanner(text: "正在下载 \(lab.name)…", success: true)
        do {
            let response = try await ArenaAPI.install(lab.id)
            guard response.ok else { throw SSHError.failed(response.error ?? "下载失败") }
            show(ActivityBanner(text: "\(lab.name) 已下载到服务器", success: true))
            await refresh(showSpinner: false)
        } catch {
            present(error)
        }
    }

    func installMissing(_ lab: Lab) async {
        await install(lab)
    }

    func installAllMissing() async {
        guard serverReady else {
            presentError("请先启动 Arena 服务器")
            return
        }
        let missing = labs.filter { !$0.installed }
        guard !missing.isEmpty else {
            show(ActivityBanner(text: "所有环境都已在服务器上", success: true))
            return
        }
        var completed = 0
        for lab in missing {
            installingLabs.insert(lab.id)
            show(ActivityBanner(text: "正在下载 \(completed + 1)/\(missing.count) · \(lab.name)",
                                success: true))
            do {
                let response = try await ArenaAPI.install(lab.id)
                if !response.ok {
                    presentError(response.error ?? "\(lab.name) 下载失败")
                }
            } catch {
                present(error)
            }
            installingLabs.remove(lab.id)
            completed += 1
        }
        show(ActivityBanner(text: "下载完成 \(completed)/\(missing.count)，可随时启动",
                            success: true))
        await refresh(showSpinner: false)
    }

    func remove(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        let names = ids.compactMap { id in labs.first(where: { $0.id == id })?.name }
        for id in ids {
            removingLabs.insert(id)
            do {
                let response = try await ArenaAPI.remove(id)
                if response.ok {
                    if let index = labs.firstIndex(where: { $0.id == id }) {
                        labs[index].installed = false
                        labs[index].running = false
                        labs[index].memBytes = 0
                        labs[index].memHuman = ""
                        labs[index].containers = []
                    }
                    deleteSelection.remove(id)
                } else {
                    presentError(response.error ?? "删除 \(id) 失败")
                }
            } catch {
                present(error)
            }
            removingLabs.remove(id)
        }
        show(ActivityBanner(text: "已从磁盘删除 \(names.count) 个环境，可随时重新下载",
                            success: true))
        await refresh(showSpinner: false)
    }

    func requestRemove(_ ids: [String]) {
        confirmRemoveIDs = ids
    }

    func stopEverything() async {
        guard serverReady else { return }
        do {
            _ = try await ArenaAPI.stopAll()
            await refresh(showSpinner: false)
            show(ActivityBanner(text: "所有实验环境已停止", success: true))
        } catch {
            present(error)
        }
    }

    // MARK: - Platform (hosts, topologies, events)

    /// Standalone hosts belong to the training/solving topologies.  AWD
    /// machines are created and managed inside an event, so they are kept out
    /// of this inventory to keep the two topologies visibly separate.
    var generalHosts: [PlatformHost] { hosts.filter { !$0.tags.contains("awd") } }
    var attackerHosts: [PlatformHost] { generalHosts.filter { $0.role == .attacker } }
    var targetHosts: [PlatformHost] { generalHosts.filter { $0.role == .target || $0.role == .service } }
    var observerHosts: [PlatformHost] { generalHosts.filter { $0.role == .observer } }
    var generalOnlineCount: Int {
        generalHosts.filter { hostProbes[$0.id]?.online == true }.count
    }

    func host(_ id: String?) -> PlatformHost? {
        guard let id else { return nil }
        return hosts.first(where: { $0.id == id })
    }

    func topology(_ id: String?) -> Topology? {
        guard let id else { return nil }
        return topologies.first(where: { $0.id == id })
    }

    func event(_ id: String?) -> ArenaEvent? {
        guard let id else { return nil }
        return events.first(where: { $0.id == id })
    }

    // MARK: - Participation

    func participantTeam(for eventID: String) -> String? {
        eventParticipation[eventID]
    }

    /// The team the user joined for this event.  Falls back to the first team
    /// when an event was re-created and team IDs changed, so a stored choice
    /// never silently turns the user back into an observer.
    func participatingTeam(in event: ArenaEvent) -> EventTeam? {
        guard let teamID = eventParticipation[event.id] else { return nil }
        return event.teams.first(where: { $0.id == teamID }) ?? event.teams.first
    }

    func setParticipant(eventID: String, teamID: String?) {
        if let teamID, !teamID.isEmpty {
            eventParticipation[eventID] = teamID
            // Keep an open workspace in sync when the team changes.
            if let context = workspaceContext, context.eventID == eventID,
               let matching = event(eventID),
               let team = matching.teams.first(where: { $0.id == teamID }) {
                workspaceContext = WorkspaceContext(eventID: eventID, eventName: matching.name,
                                                    teamID: team.id, teamName: team.name,
                                                    attackerID: team.primaryAttacker, targetID: team.primaryService)
            }
        } else {
            eventParticipation.removeValue(forKey: eventID)
            if workspaceContext?.eventID == eventID { workspaceContext = nil }
        }
        persistParticipation()
    }

    private func persistParticipation() {
        UserDefaults.standard.set(eventParticipation, forKey: Self.participationKey)
    }

    // MARK: - Workspace context

    func openWorkspace(for event: ArenaEvent, team: EventTeam) {
        workspaceContext = WorkspaceContext(eventID: event.id, eventName: event.name,
                                            teamID: team.id, teamName: team.name,
                                            attackerID: team.primaryAttacker,
                                            targetID: team.primaryService)
        selectedEventID = event.id
        mode = .workspace
    }

    func clearWorkspaceContext() {
        workspaceContext = nil
    }

    /// The team behind the open workspace, including every machine it owns.
    var workspaceTeam: EventTeam? {
        guard let context = workspaceContext,
              let event = event(context.eventID) else { return nil }
        return event.teams.first(where: { $0.id == context.teamID })
    }

    /// Switch the active attacker/service inside a multi-machine team without
    /// leaving the workspace.
    func setWorkspaceHost(attackerID: String? = nil, targetID: String? = nil) {
        guard var context = workspaceContext else { return }
        if let attackerID { context.attackerID = attackerID }
        if let targetID { context.targetID = targetID }
        workspaceContext = context
    }

    var workspaceLab: Lab? {
        // An event workspace is the team's own arena, not a catalog lab.
        if workspaceContext != nil { return nil }
        if let workspaceLabID, let lab = labs.first(where: { $0.id == workspaceLabID }) {
            return lab
        }
        if let selectedLab { return selectedLab }
        return runningLabs.first ?? installedLabs.first
    }

    var activeTopology: Topology? {
        topology(selectedTopologyID) ?? topologies.first(where: { $0.ready }) ?? topologies.first
    }

    var readyTopologyCount: Int { topologies.filter(\.ready).count }

    var probeOnlineCount: Int {
        hosts.filter { hostProbes[$0.id]?.online == true }.count
    }

    func loadPlatform() async {
        guard serverReady else { return }
        platformLoading = true
        platformError = nil
        defer { platformLoading = false }
        do {
            async let hostList = PlatformAPI.hosts()
            async let topologyList = PlatformAPI.topologies()
            async let eventList = PlatformAPI.events()
            let (h, t, e) = try await (hostList, topologyList, eventList)
            hosts = h
            topologies = t
            events = e
            platformLoaded = true
            if selectedHostID == nil { selectedHostID = h.first?.id }
            if selectedTopologyID == nil { selectedTopologyID = t.first?.id }
            if selectedEventID == nil { selectedEventID = e.first?.id }
            print("platform loaded: hosts=\(h.count) topologies=\(t.count) events=\(e.count)")
        } catch {
            // A freshly deployed server may not have the platform commands yet.
            print("platform load failed: \(error)")
            platformError = friendly(error)
            platformLoaded = true
        }
    }

    func addHost(_ host: PlatformHost) async {
        platformLoading = true
        defer { platformLoading = false }
        do {
            let saved = try await PlatformAPI.addHost(host)
            if let saved { hosts.append(saved); selectedHostID = saved.id }
            await reloadHosts()
            show(ActivityBanner(text: "已添加主机 \(host.name)", success: true))
        } catch {
            present(error)
        }
    }

    func deleteHost(_ host: PlatformHost) async {
        do {
            try await PlatformAPI.removeHost(host.id)
            hosts.removeAll { $0.id == host.id }
            topologies.removeAll { $0.target == host.id || $0.attacker == host.id }
            hostProbes.removeValue(forKey: host.id)
            if selectedHostID == host.id { selectedHostID = hosts.first?.id }
            show(ActivityBanner(text: "已删除主机 \(host.name)", success: true))
        } catch {
            present(error)
        }
    }

    func probeHost(_ host: PlatformHost) async {
        guard !probeBusy.contains(host.id) else { return }
        probeBusy.insert(host.id)
        defer { probeBusy.remove(host.id) }
        do {
            let probe = try await PlatformAPI.probeHost(host.id)
            hostProbes[host.id] = probe
        } catch {
            hostProbes[host.id] = HostProbe(hostId: host.id, error: friendly(error))
        }
    }

    func probeAllHosts() async {
        for host in generalHosts { await probeHost(host) }
    }

    func createTopology(name: String, target: String, attacker: String) async {
        do {
            let created = try await PlatformAPI.addTopology(name: name, target: target, attacker: attacker)
            if let created {
                topologies.append(created)
                selectedTopologyID = created.id
            } else {
                topologies = try await PlatformAPI.topologies()
            }
            show(ActivityBanner(text: "拓扑已创建，正在检测连通性…", success: true))
            if let id = selectedTopologyID { await testTopology(id) }
        } catch {
            present(error)
        }
    }

    func testTopology(_ id: String) async {
        guard !topologyBusy.contains(id) else { return }
        topologyBusy.insert(id)
        defer { topologyBusy.remove(id) }
        do {
            _ = try await PlatformAPI.testTopology(id)
            topologies = try await PlatformAPI.topologies()
            show(ActivityBanner(text: topologyStatusBanner(id), success: true))
        } catch {
            present(error)
        }
    }

    private func topologyStatusBanner(_ id: String) -> String {
        guard let topology = topology(id) else { return "拓扑检测完成" }
        switch topology.status {
        case "ready": return "拓扑可用：攻击机可以访问靶机"
        case "partial": return "拓扑部分可用：有一侧主机不能访问"
        case "offline": return "拓扑不可用：请检查主机地址与网络"
        default: return "拓扑状态未知"
        }
    }

    func deleteTopology(_ topology: Topology) async {
        do {
            try await PlatformAPI.removeTopology(topology.id)
            topologies.removeAll { $0.id == topology.id }
            if selectedTopologyID == topology.id { selectedTopologyID = topologies.first?.id }
        } catch {
            present(error)
        }
    }

    func createEvent(_ event: ArenaEvent) async {
        do {
            let created = try await PlatformAPI.createEvent(event)
            await reloadEvents()
            if let id = created?.id ?? events.last?.id {
                selectedEventID = id
                show(ActivityBanner(text: "赛事已创建", success: true))
            }
        } catch {
            present(error)
        }
    }

    func removeEvent(_ event: ArenaEvent) async {
        do {
            try await PlatformAPI.removeEvent(event.id)
            events.removeAll { $0.id == event.id }
            // Only AWD events own their machines: the server removes those
            // containers and host records together. A generic event merely
            // references existing hosts, which must stay in the registry.
            if event.awd == true {
                let removedHosts = Set(event.hosts
                    + event.teams.flatMap { $0.allServices + $0.allAttackers })
                if !removedHosts.isEmpty {
                    hosts.removeAll { removedHosts.contains($0.id) }
                    for id in removedHosts { hostProbes.removeValue(forKey: id) }
                }
            }
            eventStatuses.removeValue(forKey: event.id)
            awdTeams.removeValue(forKey: event.id)
            awdVerifyResults.removeValue(forKey: event.id)
            awdStatusError.removeValue(forKey: event.id)
            awdBusy = awdBusy.filter { !$0.hasPrefix("\(event.id):") }
            eventParticipation.removeValue(forKey: event.id)
            persistParticipation()
            if workspaceContext?.eventID == event.id { workspaceContext = nil }
            if selectedEventID == event.id { selectedEventID = events.first?.id }
        } catch {
            present(error)
        }
    }

    func startEvent(_ event: ArenaEvent) async {
        guard !eventBusy.contains(event.id) else { return }
        eventBusy.insert(event.id)
        defer { eventBusy.remove(event.id) }
        do {
            var status = try await PlatformAPI.startEvent(event.id)
            // `events start` returns the same probes under a keyed dictionary;
            // fold them into the list the host panel renders.
            if status.hosts == nil, let probes = status.probes {
                status.hosts = probes.values.sorted { $0.hostId < $1.hostId }
            }
            eventStatuses[event.id] = status
            await reloadEvents()
            show(ActivityBanner(text: "赛事已开始，正在观察主机", success: true))
        } catch {
            present(error)
        }
    }

    func stopEvent(_ event: ArenaEvent) async {
        guard !eventBusy.contains(event.id) else { return }
        eventBusy.insert(event.id)
        defer { eventBusy.remove(event.id) }
        do {
            eventStatuses[event.id] = try await PlatformAPI.stopEvent(event.id)
            await reloadEvents()
        } catch {
            present(error)
        }
    }

    func refreshEvent(_ event: ArenaEvent) async {
        guard !eventBusy.contains(event.id) else { return }
        eventBusy.insert(event.id)
        defer { eventBusy.remove(event.id) }
        do {
            eventStatuses[event.id] = try await PlatformAPI.eventStatus(event.id)
        } catch {
            present(error)
        }
    }

    /// Background poll: refresh observations without touching `eventBusy`, so
    /// buttons and spinners do not flash every polling interval.
    func pollEvent(_ event: ArenaEvent) async {
        guard !eventBusy.contains(event.id) else { return }
        if let status = try? await PlatformAPI.eventStatus(event.id) {
            eventStatuses[event.id] = status
        }
    }

    func invite(_ event: ArenaEvent) async -> InviteResponse? {
        do {
            return try await PlatformAPI.invite(event.id)
        } catch {
            present(error)
            return nil
        }
    }

    // MARK: - AWD arena

    /// Create an Arena-managed AWD event.  Containers are registered but not
    /// started; the operator starts only the teams they need.
    @discardableResult
    func createArenaEvent(name: String, teams: Int, services: Int, attackers: Int) async -> ArenaEvent? {
        guard !awdBusy.contains("global:create") else { return nil }
        awdBusy.insert("global:create")
        defer { awdBusy.remove("global:create") }
        do {
            let created = try await PlatformAPI.awdCreate(name: name, teams: teams,
                                                          services: services, attackers: attackers)
            // Trust the create response: the follow-up list calls can fail on a
            // flaky link, and losing the new arena would leave its running
            // machines unreachable from the UI.
            if let event = created.event {
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = event
                } else {
                    events.insert(event, at: 0)
                }
                selectedEventID = event.id
            }
            if let added = created.hosts {
                let ids = Set(added.map(\.id))
                hosts = hosts.filter { !ids.contains($0.id) } + added
            }
            await reloadEvents()
            await reloadHosts()
            if let id = created.event?.id {
                await refreshAWDStatus(for: id)
                show(ActivityBanner(text: "Arena 演练已生成，未启动任何容器", success: true))
            }
            return created.event
        } catch {
            present(error)
            return nil
        }
    }

    /// Quiet refresh used by the event detail poller: it never raises a banner
    /// and never takes the busy state that the action buttons depend on.
    func refreshAWDStatus(for eventID: String) async {
        // Only Arena-managed arenas have container teams to poll.
        guard event(eventID)?.awd == true else { return }
        guard !awdBusy.contains("\(eventID):status") else { return }
        awdBusy.insert("\(eventID):status")
        defer { awdBusy.remove("\(eventID):status") }
        do {
            let teams = try await PlatformAPI.awdStatus(eventID: eventID)
            awdTeams[eventID] = teams
            connections.close(hostIDs: Set(teams.flatMap { $0.services + $0.attackers }
                .filter { !$0.running }.map(\.hostId)))
            awdStatusError.removeValue(forKey: eventID)
        } catch {
            // Keep the last known state on screen, but stop pretending it is
            // live: the panel shows this message next to the refresh button.
            awdStatusError[eventID] = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    func startAWDTeams(_ eventID: String, teams: [String]) async {
        let token = "\(eventID):start"
        guard !awdBusy.contains(token) else { return }
        awdBusy.insert(token)
        defer { awdBusy.remove(token) }
        do {
            let result = try await PlatformAPI.awdStart(eventID: eventID, teamIDs: teams)
            await refreshAWDStatus(for: eventID)
            await reloadEvents()
            await pollEventStatus(eventID)
            let failures = result.errors ?? []
            if failures.isEmpty && result.ok {
                show(ActivityBanner(text: teams.isEmpty ? "全部赛队已启动" : "赛队已启动", success: true))
            } else {
                let first = failures.first?.error ?? result.error ?? "部分机器未启动"
                show(ActivityBanner(text: "已启动 \(result.started?.count ?? 0) 台 · \(first)",
                                    success: false))
            }
        } catch {
            // Even a transport error may hide a partial start; show the truth.
            await refreshAWDStatus(for: eventID)
            await reloadEvents()
            await pollEventStatus(eventID)
            present(error)
        }
    }

    func stopAWDTeams(_ eventID: String, teams: [String]) async {
        let token = "\(eventID):stop"
        guard !awdBusy.contains(token) else { return }
        awdBusy.insert(token)
        defer { awdBusy.remove(token) }
        do {
            let result = try await PlatformAPI.awdStop(eventID: eventID, teamIDs: teams)
            await refreshAWDStatus(for: eventID)
            await reloadEvents()
            await pollEventStatus(eventID)
            let failures = result.errors ?? []
            if failures.isEmpty && result.ok {
                show(ActivityBanner(text: "赛队已停止，资源已释放", success: true))
            } else {
                let first = failures.first?.error ?? result.error ?? "部分机器未停止"
                show(ActivityBanner(text: "已停止 \(result.stopped?.count ?? 0) 台 · \(first)",
                                    success: false))
            }
        } catch {
            await refreshAWDStatus(for: eventID)
            await reloadEvents()
            await pollEventStatus(eventID)
            present(error)
        }
    }

    /// Quiet event-status refresh used after AWD actions so the header pill,
    /// topology node and host panel agree with the AWD panel immediately.
    private func pollEventStatus(_ eventID: String) async {
        guard let event = event(eventID) else { return }
        await pollEvent(event)
    }

    func verifyAWDTeams(_ eventID: String, teams: [String]) async {
        let token = "\(eventID):verify"
        guard !awdBusy.contains(token) else { return }
        awdBusy.insert(token)
        defer { awdBusy.remove(token) }
        do {
            let results = try await PlatformAPI.awdVerify(eventID: eventID, teamIDs: teams)
            awdVerifyResults[eventID] = results
            await refreshAWDStatus(for: eventID)
            await reloadEvents()
            await pollEventStatus(eventID)
            let tested = results.filter { $0.untested != true }
            let passed = tested.filter(\.ok).count
            let untested = results.count - tested.count
            let text: String
            if results.isEmpty {
                text = "没有可验证的赛队"
            } else if tested.isEmpty {
                text = "队伍未启动，已保留上次验证结果"
            } else if untested > 0 && passed == tested.count {
                text = "\(passed) 支通过验证 · \(untested) 支未启动，保留上次结果"
            } else if passed == tested.count {
                text = "\(passed) 支队伍全部通过实战验证"
            } else {
                text = "\(passed)/\(tested.count) 支队伍通过验证"
            }
            // Untested teams are not failures: the server deliberately keeps
            // their previous verdict.
            let success = !results.isEmpty && (tested.isEmpty || passed == tested.count)
            show(ActivityBanner(text: text, success: success))
        } catch {
            present(error)
        }
    }

    func reloadHosts() async {
        if let list = try? await PlatformAPI.hosts() { hosts = list }
    }

    func loadTrainingLibrary() async {
        guard serverReady else { return }
        do {
            trainingCollections = try await ArenaAPI.library().collections
        } catch { present(error) }
    }

    func reloadEvents() async {
        if let list = try? await PlatformAPI.events() {
            events = list
            if let selectedEventID, !list.contains(where: { $0.id == selectedEventID }) {
                self.selectedEventID = list.first?.id
            }
        }
    }

    /// The training attacker is a full Kali VM, managed alongside Arena.
    func deployAttackHost() async {
        guard !platformLoading else { return }
        platformLoading = true
        defer { platformLoading = false }
        do {
            let info = try await ArenaAPI.startKali()
            kaliVM = info
            guard info.ok && info.ready == true else {
                throw SSHError.failed(info.error ?? "Arena-Kali 尚未就绪")
            }
            await loadPlatform()
            if let kali = generalHosts.first(where: { $0.tags.contains("kali-vm") }) {
                await probeHost(kali)
            }
            show(ActivityBanner(text: "Arena-Kali 独立虚拟机已就绪", success: true))
        } catch { present(error) }
    }

    func stopKali() async {
        guard !platformLoading else { return }
        platformLoading = true
        defer { platformLoading = false }
        do {
            let info = try await ArenaAPI.stopKali()
            guard info.ok else { throw SSHError.failed(info.error ?? "关闭 Kali 失败") }
            kaliVM = info
            for kali in generalHosts where kali.tags.contains("kali-vm") { await probeHost(kali) }
            show(ActivityBanner(text: "Arena-Kali 已关闭", success: true))
        } catch { present(error) }
    }

    private func friendly(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Messages

    func show(_ banner: ActivityBanner) {
        bannerTask?.cancel()
        self.banner = banner
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.banner?.id == banner.id { self?.banner = nil }
            }
        }
    }

    func present(_ error: Error) {
        presentError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    func presentError(_ message: String) {
        errorMessage = message
    }

    // MARK: - Cache

    private static var cacheURL: URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = dir.appendingPathComponent("AexusColosseum", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("catalog-cache.json")
    }

    private static func readCache() -> CatalogFile? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CatalogFile.self, from: data)
    }

    private static func writeCache(_ file: CatalogFile) {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension AppState {
    /// Switching workspace modes always leaves the settings pane and lab
    /// selection behind, so each product opens cleanly on its own.
    func switchMode(to newMode: AppMode) {
        settingsOpen = false
        selectedLabID = nil
        mode = newMode
    }

    /// Selects a catalog lab as the active Pit Battle Map and jumps into The Pit Lobby.
    func selectMapForPit(_ lab: Lab) {
        pit.mergeCatalogLabs(labs)
        pit.selectedMapID = lab.id
        settingsOpen = false
        selectedLabID = nil
        mode = .pitArena
        show(ActivityBanner(text: "⚔️ 已装载「\(lab.name)」作为斗兽场实战地图", success: true))
    }

    /// Assigns a Legendary Harness into the Pit Combatant Matrix and jumps into The Pit Lobby.
    func selectHarnessForPit(_ harness: PitHarnessPreset) {
        pit.assignHarnessToLobby(harness)
        settingsOpen = false
        selectedLabID = nil
        lobbySubSection = "create"
        mode = .pitArena
        show(ActivityBanner(text: "已将「\(harness.name)」加入参战席位", success: true))
    }

    // MARK: - UI Zoom (`⌘+` / `⌘-` / `⌘0`)

    func zoomIn() {
        setUIScale(uiScale + 0.08)
    }

    func zoomOut() {
        setUIScale(uiScale - 0.08)
    }

    func resetZoom(announce: Bool = true) {
        setUIScale(1.0, announce: announce)
    }

    func setUIScale(_ value: Double, announce: Bool = true) {
        let clamped = (min(1.50, max(0.75, value)) * 100).rounded() / 100
        let changed = abs(clamped - uiScale) > 0.001
        if changed {
            withAnimation(.easeOut(duration: 0.14)) {
                uiScale = clamped
            }
        }
        UserDefaults.standard.set(clamped, forKey: Self.uiScaleKey)
        if announce && changed {
            let pct = Int((clamped * 100).rounded())
            show(ActivityBanner(text: "界面缩放 \(pct)%", success: true))
        }
    }
}
