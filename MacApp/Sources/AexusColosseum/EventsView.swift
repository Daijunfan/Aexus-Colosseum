import SwiftUI
import AppKit

// MARK: - Screen
struct EventsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showCreate = false
    @State private var showArenaCreate = false
    @State private var showDetail = ProcessInfo.processInfo.environment["AEXUS_EVENT"] != nil
        || ProcessInfo.processInfo.environment["AEXUS_UI"] == "awd-demo"
    @State private var refreshing = false
    @State private var confirmDelete = false
    private let columns = [GridItem(.adaptive(minimum: 400, maximum: 640), spacing: 16, alignment: .top)]
    var body: some View {
        Group {
            if showDetail, let event = selectedEvent {
                EventDetailView(event: event, onBack: { withAnimation(Motion.page) { showDetail = false } },
                                onDelete: { confirmDelete = true }).transition(.opacity)
            } else { listBody.transition(.opacity) }
        }.sheet(isPresented: $showCreate) { CreateEventSheet().environmentObject(app) }
        .sheet(isPresented: $showArenaCreate) { ArenaEventCreateSheet().environmentObject(app) }
        .alert("删除赛事？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                guard let event = selectedEvent else { return }
                withAnimation(Motion.page) { showDetail = false }
                Task { await app.removeEvent(event) } }
            Button("取消", role: .cancel) {}
        } message: { Text("赛事记录会被删除，由 Arena 创建的服务机与攻击机容器也会一并移除。") }
        .onAppear {
            // Visual harness hook, matching the other AEXUS_UI entries.
            if ProcessInfo.processInfo.environment["AEXUS_UI"] == "arena-create" {
                showArenaCreate = true
            }
        } }
    private var selectedEvent: ArenaEvent? {
        app.selectedEventID.flatMap { id in app.events.first { $0.id == id } } }
    private var sortedEvents: [ArenaEvent] {
        app.events.sorted { a, b in a.running != b.running ? a.running
            : (DateText.date(a.createdAt) ?? .distantPast) > (DateText.date(b.createdAt) ?? .distantPast) } }
    private var listBody: some View {
        VStack(spacing: 0) {
            header
            hairline
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if app.events.isEmpty { emptyState } else {
                        SectionLabel(text: "全部赛事", trailing: "\(app.events.count) 场")
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(sortedEvents) { event in EventCard(event: event) { open(event) } } } }
                }.padding(.horizontal, 30).padding(.top, 24).padding(.bottom, 40)
               .frame(maxWidth: 1320, alignment: .leading).frame(maxWidth: .infinity, alignment: .top)
            }.background(ArenaTheme.background.opacity(0.001)) } }
    private var header: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("ARENA EVENTS")
                Text("攻防赛事").font(.system(size: 38, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                Text("由 Arena 创建每队的服务机与攻击机，在应用内启动、验证与观察。").font(.system(size: 13)).foregroundStyle(ArenaTheme.textSecondary) }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                GhostButton(title: "刷新", systemImage: "arrow.clockwise", busy: refreshing) { Task { await refresh() } }
                GhostButton(title: "编排赛事", systemImage: "plus") { showCreate = true }
                AccentButton(title: "生成竞技场", systemImage: "sparkles") { showArenaCreate = true } }
        }.padding(.horizontal, 30).padding(.top, 26).padding(.bottom, 18) }
    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(ArenaTheme.accent.opacity(0.09)).frame(width: 78, height: 78)
                Image(systemName: "flag.2.crossed.fill").font(.system(size: 28, weight: .medium)).foregroundStyle(ArenaTheme.accent) }
            VStack(spacing: 6) {
                Text("还没有赛事").font(.system(size: 22, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                Text("创建一场对抗，把队伍、靶机与攻击机编排在一起，然后在这里观察心跳与连通性。").font(.system(size: 12.5)).foregroundStyle(ArenaTheme.textSecondary)
                   .multilineTextAlignment(.center).frame(maxWidth: 520).fixedSize(horizontal: false, vertical: true) }
            HStack(alignment: .top, spacing: 14) {
                modeCard("flag.2.crossed.fill", "AWD", "1–3 服务 · 1–3 攻击", ArenaTheme.accent,
                         "最多五支队伍，每队拥有独立的服务机与攻击机。Arena 负责创建、启动与验证，参赛者从自己的攻击机发起对抗。")
                modeCard("crown.fill", "King of the Hill", "抢占同一台主机", ArenaTheme.gold,
                         "所有队伍争夺同一台目标主机。谁先取得并保持控制权，谁就占据山头。") }
            HStack(spacing: 10) {
                AccentButton(title: "生成竞技场", systemImage: "sparkles") { showArenaCreate = true }
                GhostButton(title: "编排已有主机", systemImage: "slider.horizontal.3") { showCreate = true } }
            Text("创建后仍可随时开始、暂停或停止观察。").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
        }.frame(maxWidth: .infinity).padding(.vertical, 34).padding(.horizontal, 30).arenaCard(radius: Radius.panel) }
    private func modeCard(_ symbol: String, _ title: String, _ subtitle: String,
                          _ color: Color, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.13))
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                }.frame(width: 28, height: 28)
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(ArenaTheme.textPrimary)
                Spacer(minLength: 4)
                Chip(text: subtitle, color: color) }
            Text(description).font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary)
               .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
       .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(color.opacity(0.045))
           .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(color.opacity(0.14), lineWidth: 0.9))) }
    @MainActor private func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        await app.loadPlatform()
        refreshing = false }
    private func open(_ event: ArenaEvent) {
        app.selectedEventID = event.id
        withAnimation(Motion.page) { showDetail = true } } }
private var hairline: some View { Rectangle().fill(ArenaTheme.hairline).frame(height: 1) }
private func eyebrow(_ text: String) -> some View {
    HStack(spacing: 8) {
        Text(text).font(ArenaType.micro).tracking(2.2).foregroundStyle(ArenaTheme.accent.opacity(0.9))
        Rectangle().fill(ArenaTheme.accent.opacity(0.4)).frame(width: 26, height: 1) } }

// MARK: - Card
private struct EventCard: View {
    @EnvironmentObject private var app: AppState
    var event: ArenaEvent
    var onOpen: () -> Void
    @State private var hovering = false
    private var busy: Bool { app.eventBusy.contains(event.id) }
    private var tint: Color { eventFormatColor(event.format) }
    private var managed: Bool { event.awd == true }
    private var machineCount: Int {
        let ids = event.teams.flatMap { $0.allServices + $0.allAttackers }
        return ids.isEmpty ? event.hosts.count : Set(ids).count
    }
    private var verifiedCount: Int {
        let live = app.awdTeams[event.id] ?? []
        return event.teams.filter { team in
            live.first(where: { $0.id == team.id })?.verified ?? (team.verified == true)
        }.count
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.12))
                    Image(systemName: eventFormatSymbol(event.format)).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                }.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name).font(ArenaType.cardTitle).foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                    Text("\(event.formatLabel) · 创建于 \(DateText.short(event.createdAt))")
                       .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary).lineLimit(1) }
                Spacer(minLength: 6)
                eventStatusPill(event.status) }
            HStack(spacing: 7) {
                metaChip("person.2.fill", "\(event.teams.count) 支队伍")
                metaChip(managed ? "server.rack" : "desktopcomputer", "\(machineCount) 台机器")
                if verifiedCount > 0 {
                    Chip(text: "\(verifiedCount) 队已验证", color: ArenaTheme.success)
                        .help("这些队伍的服务与攻击链路已通过真实连通性验证") }
                if event.agents { metaChip("dot.radiowaves.left.and.right", "Agent") }
                if let team = app.participatingTeam(in: event) {
                    Chip(text: "参赛者 · \(team.name)", color: ArenaTheme.accent)
                        .help("你已选择以参赛者身份加入这场赛事") }
                Spacer(minLength: 0) }
            hairline
            HStack(spacing: 8) {
                if managed {
                    AccentButton(title: "管理赛队", systemImage: "square.grid.2x2.fill") { onOpen() }
                    Text(event.running ? "资源占用中" : "容器已停止")
                        .font(ArenaType.micro)
                        .foregroundStyle(event.running ? ArenaTheme.accent : ArenaTheme.textQuaternary)
                } else if event.running {
                    GhostButton(title: "停止", systemImage: "stop.fill", tint: ArenaTheme.accentBright,
                                enabled: !busy) { Task { await app.stopEvent(event) } }
                } else {
                    AccentButton(title: "开始", systemImage: "play.fill", busy: busy,
                                 enabled: !busy) { Task { await app.startEvent(event) } } }
                GhostButton(title: "观察", systemImage: "eye", tint: ArenaTheme.textPrimary) { onOpen() }
                Spacer(minLength: 0)
                if event.observer {
                    Text("观察已启用").font(ArenaType.micro).foregroundStyle(ArenaTheme.textQuaternary) } }
        }.padding(16).background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
           .fill(hovering ? ArenaTheme.cardHover : ArenaTheme.card).overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
               .strokeBorder(event.running ? ArenaTheme.accent.opacity(0.35)
                              : (hovering ? ArenaTheme.tint(0.14) : ArenaTheme.stroke), lineWidth: 1))
           .shadow(color: ArenaTheme.shadow(hovering ? 0.4 : 0.25),
                    radius: hovering ? 20 : 12, y: hovering ? 12 : 7)).overlay(alignment: .topLeading) {
            if event.running {
                Capsule().fill(ArenaTheme.accentGradient).frame(width: 30, height: 2.5).offset(x: 17, y: -1) }
        }.contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)).pointerCursor().onTapGesture { onOpen() }
       .onHover { value in withAnimation(Motion.hover) { hovering = value } } }
    private func metaChip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9, weight: .semibold)); Text(text).font(ArenaType.caption)
        }.foregroundStyle(ArenaTheme.textTertiary).padding(.horizontal, 7).padding(.vertical, 3.5).background(Capsule().fill(ArenaTheme.tint(0.04))) }
}
private func eventStatusPill(_ status: String) -> some View {
    let c = statusColor(status)
    return HStack(spacing: 5) {
        StatusDot(color: c, pulsing: status == "running"); Text(statusLabel(status)).font(ArenaType.micro)
    }.foregroundStyle(c).padding(.horizontal, 9).padding(.vertical, 4).background(Capsule().fill(c.opacity(0.12)))
   .overlay(Capsule().strokeBorder(c.opacity(0.2), lineWidth: 0.8)) }

// MARK: - Create sheet
private struct CreateEventSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var format = "awd"
    @State private var teams = [TeamDraft(name: "红队")]
    @State private var observer = true
    @State private var agents = true
    private var targetOptions: [PlatformHost] {
        let preferred = app.generalHosts.filter { $0.role == .target || $0.role == .service }
        return preferred.isEmpty ? app.generalHosts : preferred }
    private var attackerOptions: [PlatformHost] {
        let preferred = app.generalHosts.filter { $0.role == .attacker }
        return preferred.isEmpty ? app.generalHosts : preferred }
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !teams.isEmpty
            && teams.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    private var hostCount: Int { Set(teams.flatMap { [$0.target, $0.attacker].compactMap { $0 } }).count }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    eyebrow("NEW ARENA EVENT")
                    Text("新建赛事").font(.system(size: 22, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                    Text("编排参赛队伍与主机，应用只负责观察比赛状态。").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary) }
                Spacer()
                RoundIconButton(systemImage: "xmark", help: "关闭") { dismiss() }
            }.padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 16)
            hairline
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "赛事名称"); ArenaField(placeholder: "例如：周五夜间 AWD 练习赛", text: $name) }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "比赛格式")
                        Picker("比赛格式", selection: $format) {
                            Text("AWD 攻防").tag("awd"); Text("King of the Hill").tag("koh"); Text("自定义").tag("custom")
                        }.pickerStyle(.segmented).labelsHidden()
                        Text(formatBlurb).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary).fixedSize(horizontal: false, vertical: true)
                    }
                    teamsSection
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "观察选项")
                        toggleRow("启用观察", "记录主机连通性、延迟与 Agent 心跳。", $observer)
                        toggleRow("允许 Agent", "允许参赛主机安装轻量 Agent，用于上报心跳。", $agents) }
                }.padding(.horizontal, 26).padding(.vertical, 20) }
            hairline
            HStack(spacing: 10) {
                Text("\(teams.count) 支队伍 · \(hostCount) 台主机").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                Spacer()
                GhostButton(title: "取消") { dismiss() }
                AccentButton(title: "创建赛事", systemImage: "checkmark", enabled: canSubmit) { submit() }
            }.padding(.horizontal, 26).padding(.vertical, 16)
        }.frame(width: 660, height: 700).background(ArenaTheme.background) }
    private var formatBlurb: String {
        switch format {
        case "awd": return "攻防兼备：每队一台靶机作为防守目标，一台攻击机用于进攻对手。"
        case "koh": return "山头争夺：所有队伍围绕同一台目标主机展开，控制权实时更替。"
        default: return "自定义赛事只做编排与观察，队伍的主机由你按需指定。" } }
    private var teamsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SectionLabel(text: "队伍编成", trailing: "\(teams.count) 支队伍")
                GhostButton(title: "添加队伍", systemImage: "plus", tint: ArenaTheme.textPrimary) {
                    withAnimation(Motion.disclosure) { teams.append(TeamDraft(name: "队伍 \(teams.count + 1)")) } } }
            ForEach(teams) { team in
                TeamRowEditor(team: binding(for: team.id), targetOptions: targetOptions,
                              attackerOptions: attackerOptions, canRemove: teams.count > 1) {
                    withAnimation(Motion.disclosure) { teams.removeAll { $0.id == team.id } } } }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 11, weight: .semibold)).foregroundStyle(ArenaTheme.ember).padding(.top, 1)
                Text(noteText).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                   .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
           .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.ember.opacity(0.06))) } }
    private var noteText: String {
        let base = "每支队伍需要一台靶机（防守目标）和一台攻击机。赛事不会在这些主机上替你执行命令，参赛者用自己的终端操作。"
        return app.generalHosts.isEmpty ? base + " 当前还没有主机，可以先创建草稿，稍后在「主机与拓扑」中补充。" : base }
    private func toggleRow(_ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary)
                Text(subtitle).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary) }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(ArenaTheme.accent).accessibilityLabel(title)
        }.padding(.horizontal, 13).padding(.vertical, 11)
       .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.tint(0.03)))
       .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ArenaTheme.tint(0.07), lineWidth: 0.8)) }
    private func binding(for id: UUID) -> Binding<TeamDraft> {
        Binding(get: { teams.first(where: { $0.id == id }) ?? TeamDraft() },
                set: { updated in
                    guard let index = teams.firstIndex(where: { $0.id == id }) else { return }
                    teams[index] = updated }) }
    private func submit() {
        guard canSubmit else { return }
        let eventTeams = teams.map {
            EventTeam(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                      target: $0.target, attacker: $0.attacker) }
        let hosts = Array(Set(eventTeams.flatMap { [$0.target, $0.attacker].compactMap { $0 } })).sorted()
        let event = ArenaEvent(id: "", name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                               format: format, status: "draft", teams: eventTeams, hosts: hosts,
                               observer: observer, agents: agents, invite: nil, createdAt: nil,
                               startedAt: nil, endedAt: nil)
        Task { await app.createEvent(event); dismiss() } } }
private struct TeamDraft: Identifiable {
    let id = UUID()
    var name: String = ""
    var target: String?
    var attacker: String? }
private struct ArenaField: View {
    var placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text).textFieldStyle(.plain).font(ArenaType.body)
           .foregroundStyle(ArenaTheme.textPrimary).padding(.horizontal, 10).padding(.vertical, 8)
           .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ArenaTheme.tint(0.035)))
           .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ArenaTheme.tint(0.1), lineWidth: 0.8)) } }
private struct TeamRowEditor: View {
    @Binding var team: TeamDraft
    var targetOptions: [PlatformHost]
    var attackerOptions: [PlatformHost]
    var canRemove: Bool
    var onRemove: () -> Void
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            column("队名") { ArenaField(placeholder: "例如 红队", text: $team.name) }.frame(width: 138)
            column("靶机 / 目标") {
                HostPicker(selection: $team.target, options: targetOptions, tint: ArenaTheme.ember, emptyLabel: "选择靶机")
            }.frame(width: 160)
            Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(ArenaTheme.textQuaternary).padding(.bottom, 10)
            column("攻击机") {
                HostPicker(selection: $team.attacker, options: attackerOptions, tint: ArenaTheme.accent, emptyLabel: "选择攻击机")
            }.frame(width: 160)
            RoundIconButton(systemImage: "minus", tint: ArenaTheme.danger, help: "移除这支队伍") { onRemove() }
               .disabled(!canRemove).opacity(canRemove ? 1 : 0.35).padding(.bottom, 3)
        }.padding(11).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ArenaTheme.tint(0.022)))
       .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ArenaTheme.tint(0.06), lineWidth: 0.8)) }
    private func column<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(ArenaType.micro).tracking(0.8).foregroundStyle(ArenaTheme.textTertiary); content() } } }
private struct HostPicker: View {
    @EnvironmentObject private var app: AppState
    @Binding var selection: String?
    var options: [PlatformHost]
    var tint: Color
    var emptyLabel: String
    private var selected: PlatformHost? {
        guard let selection else { return nil }
        return options.first(where: { $0.id == selection }) ?? app.host(selection) }
    var body: some View {
        Menu {
            Button("未绑定") { selection = nil }
            if !options.isEmpty { Divider() }
            ForEach(options) { host in Button("\(host.name) · \(host.role.label)") { selection = host.id } }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(selected?.role.tint ?? ArenaTheme.textQuaternary).frame(width: 5, height: 5)
                Text(selected?.name ?? emptyLabel).font(ArenaType.callout)
                   .foregroundStyle(selected == nil ? ArenaTheme.textTertiary : ArenaTheme.textPrimary).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 7, weight: .semibold)).foregroundStyle(ArenaTheme.textQuaternary)
            }.padding(.horizontal, 9).padding(.vertical, 8).frame(maxWidth: .infinity)
           .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ArenaTheme.tint(0.035)))
           .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.opacity(selection == nil ? 0.1 : 0.28), lineWidth: 0.8))
           .contentShape(Rectangle())
        }.menuStyle(.borderlessButton).menuIndicator(.hidden) } }

// MARK: - Detail
private struct EventDetailView: View {
    @EnvironmentObject private var app: AppState
    var event: ArenaEvent
    var onBack: () -> Void
    var onDelete: () -> Void
    @State private var showShare = false
    @State private var showDeploy = false
    private var status: String { app.eventStatuses[event.id]?.event?.status ?? event.status }
    private var busy: Bool { app.eventBusy.contains(event.id) }
    private var probes: [HostProbe] { app.eventStatuses[event.id]?.hosts ?? [] }
    private var agents: [AgentHeartbeat] { app.eventStatuses[event.id]?.agents ?? [] }
    private var activities: [AgentActivity] { app.eventStatuses[event.id]?.activities ?? [] }
    private var participantID: String? { app.eventParticipation[event.id] }
    private var participantTeam: EventTeam? { app.participatingTeam(in: event) }
    private var isParticipating: Bool { participantID != nil && participantTeam != nil }
    private var managed: Bool { event.awd == true }
    private var isDemoPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["AEXUS_UI"] == "awd-demo"
        #else
        false
        #endif
    }
    private var machineCount: Int {
        let ids = event.teams.flatMap { $0.allServices + $0.allAttackers }
        return ids.isEmpty ? event.hosts.count : Set(ids).count
    }
    private var verifiedCount: Int {
        let live = app.awdTeams[event.id] ?? []
        return event.teams.filter { team in
            live.first(where: { $0.id == team.id })?.verified ?? (team.verified == true)
        }.count
    }
    private var participationBinding: Binding<Bool> {
        Binding(
            get: { isParticipating },
            set: { on in
                if on {
                    guard let team = event.teams.first else { return }
                    withAnimation(Motion.banner) { app.setParticipant(eventID: event.id, teamID: team.id) }
                } else {
                    withAnimation(Motion.banner) { app.setParticipant(eventID: event.id, teamID: nil) }
                }
            })
    }
    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            hairline
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    participateCard
                    if event.awd == true {
                        AWDControlPanel(event: event)
                    }
                    EventTopologyView(event: event)
                    HStack(alignment: .top, spacing: 16) {
                        HostStatusPanel(event: event, probes: probes).frame(maxWidth: .infinity)
                        AgentsPanel(agents: agents).frame(width: 320) }
                    AgentActivityPanel(activities: activities) { showDeploy = true }
                    Text(managed
                         ? "服务机与攻击机由 Arena 创建和管理。启动、验证与停止只作用于所选队伍，其余队伍保持关闭。"
                         : "赛事编排在本机完成，实际攻防发生在参赛者自己的主机上。")
                        .font(ArenaType.caption).foregroundStyle(ArenaTheme.textQuaternary)
                }.padding(.horizontal, 30).padding(.top, 20).padding(.bottom, 40)
               .frame(maxWidth: 1320, alignment: .leading).frame(maxWidth: .infinity, alignment: .top)
            }.background(ArenaTheme.background.opacity(0.001))
        }.sheet(isPresented: $showShare) { InviteSheet(event: event).environmentObject(app) }
        .sheet(isPresented: $showDeploy) { AgentDeploySheet(event: event).environmentObject(app) }
        .task {
            // The offline preview fixture has no server to poll.
            if isDemoPreview { return }
            if app.eventStatuses[event.id] == nil {
                await app.refreshEvent(event)
            }
            await app.refreshAWDStatus(for: event.id)
            // Keep the live activity timeline and the container state current
            // while the detail is open.  Polls use the quiet paths so action
            // buttons do not flicker every few seconds.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard !Task.isCancelled else { return }
                await app.pollEvent(event)
                await app.refreshAWDStatus(for: event.id)
            }
        }
    }
    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                GhostButton(title: "返回赛事", systemImage: "chevron.left") { onBack() }
                Spacer()
                HStack(spacing: 8) {
                    // Managed arenas keep start/stop/verify in the team panel,
                    // where each row carries its own verdict and controls.
                    if !managed {
                        AccentButton(title: "开始", systemImage: "play.fill", busy: busy,
                                     enabled: !busy && status != "running") { Task { await app.startEvent(event) } }
                        GhostButton(title: "停止", systemImage: "stop.fill", tint: ArenaTheme.accentBright,
                                    enabled: !busy && (status == "running" || status == "paused")) {
                            Task { await app.stopEvent(event) } }
                    }
                    GhostButton(title: "刷新状态", systemImage: "arrow.clockwise", enabled: !busy) {
                        Task {
                            await app.refreshEvent(event)
                            await app.refreshAWDStatus(for: event.id)
                        } }
                    GhostButton(title: "邀请/分享", systemImage: "square.and.arrow.up") { showShare = true }
                    GhostButton(title: "删除", systemImage: "trash", tint: ArenaTheme.danger) { onDelete() } } }
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    eyebrow("ARENA EVENT")
                    Text(event.name).font(ArenaType.pageTitle).foregroundStyle(ArenaTheme.textPrimary).lineLimit(2)
                    HStack(spacing: 7) {
                        Chip(text: event.formatLabel, color: eventFormatColor(event.format))
                        Chip(text: "\(event.teams.count) 支队伍", color: ArenaTheme.textSecondary)
                        Chip(text: "\(machineCount) 台机器", color: ArenaTheme.textSecondary)
                        if verifiedCount > 0 {
                            Chip(text: "\(verifiedCount) 队已验证", color: ArenaTheme.success) }
                        if let team = participantTeam {
                            Chip(text: "参赛者 · \(team.name)", color: ArenaTheme.accent) }
                        Text(isParticipating ? "参赛者模式：从解题台进入攻击机"
                                             : "观察与编排，不代替参赛者操作")
                            .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary) } }
                Spacer(minLength: 12)
                eventStatusPill(status) }
        }.padding(.horizontal, 30).padding(.top, 22).padding(.bottom, 18) }
    private var participateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill((isParticipating ? ArenaTheme.accent : ArenaTheme.textTertiary).opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: isParticipating ? "person.fill.checkmark" : "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isParticipating ? ArenaTheme.accent : ArenaTheme.textSecondary) }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("参与模式").font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary)
                        modeBadge }
                    Text(isParticipating ? "你正以参赛者身份加入这场赛事。"
                                         : "你是这场赛事的观察者，也可以以参赛者身份加入。")
                        .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary) }
                Spacer(minLength: 12)
                HStack(spacing: 8) {
                    Text("我也参战").font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isParticipating ? ArenaTheme.accent : ArenaTheme.textSecondary)
                    Toggle("", isOn: participationBinding).labelsHidden().toggleStyle(.switch)
                        .tint(ArenaTheme.accent).disabled(event.teams.isEmpty)
                        .accessibilityLabel("我也参战") } }
            if event.teams.isEmpty {
                noTeamsHint
            } else if isParticipating, let team = participantTeam {
                participantSummary(team)
            } else {
                observerNote
            }
        }.padding(15).arenaCard().animation(Motion.banner, value: isParticipating) }
    private var modeBadge: some View {
        let participating = isParticipating
        let tint = participating ? ArenaTheme.accent : ArenaTheme.textTertiary
        let label = participating ? "参赛者 · \(participantTeam?.name ?? "")" : "观察者"
        return HStack(spacing: 4.5) {
            Circle().fill(tint).frame(width: 4.5, height: 4.5)
            Text(label).font(ArenaType.micro)
        }.foregroundStyle(tint)
        .padding(.horizontal, 7).padding(.vertical, 2.5)
        .background(Capsule().fill(tint.opacity(0.1)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.2), lineWidth: 0.8)) }
    private var noTeamsHint: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArenaTheme.ember).padding(.top, 1)
            Text("赛事尚未配置队伍，创建队伍后即可选择参战。").font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.ember.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(ArenaTheme.ember.opacity(0.16), lineWidth: 0.8))
        .padding(.top, 12).transition(.opacity.combined(with: .move(edge: .top))) }
    private var observerNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "eye.fill").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArenaTheme.textTertiary).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("观察者模式：只看状态，不加入对抗")
                    .font(ArenaType.callout.weight(.semibold)).foregroundStyle(ArenaTheme.textPrimary)
                Text("主机状态、Agent 心跳与拓扑仅用于观察。打开「我也参战」并选择队伍，即可进入参赛者模式。")
                    .font(ArenaType.caption).foregroundStyle(ArenaTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true) }
        }.padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.tint(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.07), lineWidth: 0.8))
        .padding(.top, 12) }
    private func participantSummary(_ team: EventTeam) -> some View {
        let tint = teamTint(team)
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(team.name).font(ArenaType.headline)
                        .foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                    if event.teams.count > 1 { teamPicker(team) } }
                HStack(spacing: 6) {
                    Text(hostName(team.primaryAttacker)).foregroundStyle(ArenaTheme.accent)
                    Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ArenaTheme.textQuaternary)
                    Text(hostName(team.primaryService)).foregroundStyle(ArenaTheme.ember)
                }.font(.system(size: 10, weight: .medium, design: .monospaced)).lineLimit(1)
                if team.allServices.count > 1 || team.allAttackers.count > 1 {
                    Text("共 \(team.allServices.count) 台服务机 · \(team.allAttackers.count) 台攻击机，全部属于这支队伍。")
                        .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                }
                HStack(spacing: 6) {
                    Text(hostAddress(team.primaryAttacker)).foregroundStyle(ArenaTheme.textTertiary)
                    Image(systemName: "arrow.right").font(.system(size: 7, weight: .bold))
                        .foregroundStyle(ArenaTheme.textQuaternary)
                    Text(hostAddress(team.primaryService)).foregroundStyle(ArenaTheme.textTertiary)
                }.font(.system(size: 9.5, design: .monospaced)).lineLimit(1)
                Text("扫描、利用与提交 flag 都在你的攻击机上完成，应用不会代你执行。")
                    .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 8) {
                AccentButton(title: "进入解题台", systemImage: "terminal.fill") {
                    withAnimation(Motion.page) { app.openWorkspace(for: event, team: team) } }
                CopyChip(text: participantCopyText(team), label: "复制内网信息") } }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(tint.opacity(0.18), lineWidth: 0.8))
        .padding(.top, 12)
        .transition(.opacity.combined(with: .move(edge: .top))) }
    private func teamPicker(_ team: EventTeam) -> some View {
        Menu {
            ForEach(event.teams) { option in
                Button(option.name) {
                    withAnimation(Motion.banner) { app.setParticipant(eventID: event.id, teamID: option.id) } } }
        } label: {
            HStack(spacing: 5) {
                Text("切换队伍").font(ArenaType.caption).foregroundStyle(ArenaTheme.textSecondary)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textQuaternary) }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(ArenaTheme.tint(0.05)))
            .overlay(Capsule().strokeBorder(ArenaTheme.tint(0.1), lineWidth: 0.8))
            .contentShape(Capsule())
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize() }
    private func hostName(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "未绑定" }
        return app.host(id)?.name ?? id }
    private func hostAddress(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "—" }
        return app.host(id)?.displayAddress ?? id }
    private func participantCopyText(_ team: EventTeam) -> String {
        var lines = ["以下为训练网地址；Mac 需通过应用或已授权的 SSH 通道访问。"]
        for (index, id) in team.allAttackers.enumerated() {
            lines.append("攻击机 A\(index + 1) \(hostName(id)) \(hostAddress(id))")
        }
        for (index, id) in team.allServices.enumerated() {
            lines.append("服务机 S\(index + 1) \(hostName(id)) \(hostAddress(id))")
        }
        return lines.joined(separator: "\n")
    }
    private func teamTint(_ team: EventTeam) -> Color {
        guard let index = event.teams.firstIndex(where: { $0.id == team.id }) else { return ArenaTheme.accent }
        return EventTopologyStyle.color(index) }
}

// MARK: - Topology
private struct EventTopologyView: View {
    @EnvironmentObject private var app: AppState
    var event: ArenaEvent
    @State private var pulse = false
    private var status: String { app.eventStatuses[event.id]?.event?.status ?? event.status }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "赛事拓扑", trailing: "控制面 · \(event.teams.count) 支队伍").padding(.horizontal, 17).padding(.top, 15).padding(.bottom, 4)
            GeometryReader { proxy in topology(size: proxy.size) }.frame(height: event.teams.count == 2 ? 248 : 340).padding(.horizontal, 10).padding(.bottom, 10)
        }.arenaCard() }
    private var nodeWidth: CGFloat {
        if event.teams.count == 2 { return 236 }
        return event.teams.count >= 4 ? 152 : 188
    }
    private func topology(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let duel = event.teams.count == 2
        let rx = min(size.width * (duel ? 0.36 : 0.37), duel ? 420 : 430)
        let ry = min(size.height * 0.36, 118)
        return ZStack {
            Canvas { context, _ in
                if duel {
                    // Two teams read best as a left/right duel around the
                    // control plane, not as two dots on an empty ellipse.
                    let axis = CGRect(x: center.x - rx, y: center.y - 1, width: rx * 2, height: 2)
                    context.stroke(Path(axis), with: .color(ArenaTheme.hairline), lineWidth: 1)
                } else {
                    let outer = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
                    context.stroke(Path(ellipseIn: outer), with: .color(ArenaTheme.strokeStrong),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 7]))
                    let inner = CGRect(x: center.x - rx * 0.62, y: center.y - ry * 0.62,
                                       width: rx * 1.24, height: ry * 1.24)
                    context.stroke(Path(ellipseIn: inner), with: .color(ArenaTheme.hairline),
                                   style: StrokeStyle(lineWidth: 1))
                }
                for index in event.teams.indices {
                    var line = Path(); line.move(to: center)
                    line.addLine(to: teamPoint(index, center: center, rx: rx, ry: ry))
                    context.stroke(line, with: .color(EventTopologyStyle.color(index).opacity(event.running ? 0.46 : 0.24)),
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 5])) }
            }.allowsHitTesting(false)
            centerNode.position(center)
            ForEach(Array(event.teams.enumerated()), id: \.element.id) { index, team in
                let live = app.awdTeams[event.id]?.first(where: { $0.id == team.id })
                TeamTopologyNode(team: team, tint: EventTopologyStyle.color(index),
                                 services: team.allServices, attackers: team.allAttackers,
                                 verified: live?.verified ?? (team.verified == true),
                                 running: live?.running ?? (event.awd == true ? false : event.running),
                                 width: nodeWidth)
                   .position(teamPoint(index, center: center, rx: rx, ry: ry)) }
            if event.teams.isEmpty {
                Text("尚未配置队伍").font(ArenaType.callout).foregroundStyle(ArenaTheme.textTertiary).offset(y: 76) }
        }.onAppear { startPulse() }.onChange(of: event.running) { _, running in
            if running { startPulse() } else { withAnimation(Motion.hover) { pulse = false } } } }
    private var centerNode: some View {
        ZStack {
            if event.running {
                Circle().stroke(ArenaTheme.accent.opacity(0.3), lineWidth: 1).frame(width: 132, height: 132)
                   .scaleEffect(pulse ? 1.2 : 0.9).opacity(pulse ? 0.12 : 0.55)
                Circle().stroke(ArenaTheme.accent.opacity(0.18), lineWidth: 1).frame(width: 164, height: 164)
                   .scaleEffect(pulse ? 1.1 : 0.94).opacity(pulse ? 0.05 : 0.3) }
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(ArenaTheme.accentGradient).frame(width: 30, height: 30)
                    Image(systemName: "flag.2.crossed.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                Text("赛事控制面").font(ArenaType.callout.weight(.semibold)).foregroundStyle(ArenaTheme.textPrimary)
                HStack(spacing: 4) {
                    StatusDot(color: statusColor(status), pulsing: event.running)
                    Text(statusLabel(status)).font(ArenaType.micro).foregroundStyle(statusColor(status)) }
            }.padding(.horizontal, 16).padding(.vertical, 11)
           .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ArenaTheme.cardRaised))
           .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ArenaTheme.tint(0.12), lineWidth: 1))
           .shadow(color: ArenaTheme.shadow(0.35), radius: 12, y: 5) } }
    private func teamPoint(_ index: Int, center: CGPoint, rx: CGFloat, ry: CGFloat) -> CGPoint {
        if event.teams.count == 2 {
            return CGPoint(x: center.x + (index == 0 ? -rx : rx), y: center.y) }
        let angle = -Double.pi / 2 + (2 * Double.pi / Double(max(event.teams.count, 1))) * Double(index)
        return CGPoint(x: center.x + CGFloat(cos(angle)) * rx, y: center.y + CGFloat(sin(angle)) * ry) }
    private func hostLabel(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "未绑定" }
        return app.host(id)?.name ?? id }
    private func startPulse() {
        guard event.running else { pulse = false; return }
        pulse = false
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { pulse = true } } }
private struct TeamTopologyNode: View {
    @EnvironmentObject private var app: AppState
    var team: EventTeam
    var tint: Color
    var services: [String]
    var attackers: [String]
    var verified: Bool
    var running: Bool
    var width: CGFloat
    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(team.name).font(ArenaType.caption.weight(.semibold))
                    .foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                Spacer(minLength: 2)
                if verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ArenaTheme.success)
                        .help("实战验证通过")
                } else if running {
                    StatusDot(color: ArenaTheme.success, pulsing: true)
                }
            }
            HStack(spacing: 3) {
                ForEach(Array(services.enumerated()), id: \.element) { index, hostID in
                    machineChip("S\(index + 1)", hostID: hostID, tint: ArenaTheme.ember)
                }
                if !services.isEmpty && !attackers.isEmpty {
                    Rectangle().fill(ArenaTheme.tint(0.12)).frame(width: 0.8, height: 11)
                        .padding(.horizontal, 1)
                }
                ForEach(Array(attackers.enumerated()), id: \.element) { index, hostID in
                    machineChip("A\(index + 1)", hostID: hostID, tint: ArenaTheme.accent)
                }
            }
            Text("\(services.count) 服务 · \(attackers.count) 攻击")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(ArenaTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(verified ? ArenaTheme.success.opacity(0.4) : tint.opacity(0.32),
                          lineWidth: 1))
        .shadow(color: ArenaTheme.shadow(0.22), radius: 8, y: 3)
    }

    private func machineChip(_ label: String, hostID: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(tint.opacity(0.13)))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 0.6))
            .help(app.host(hostID)?.name ?? hostID)
    }
}

// MARK: - AWD control

/// Per-team readiness, start/stop/verify controls and the persisted result of
/// the last real connectivity test.  Verified teams rise to the top, so a
/// successful team is visible at a glance.
struct AWDControlPanel: View {
    @EnvironmentObject private var app: AppState
    var event: ArenaEvent

    private var live: [AWDTeamStatus] { app.awdTeams[event.id] ?? [] }
    private var results: [AWDVerifyResult] { app.awdVerifyResults[event.id] ?? [] }
    private var busy: Bool {
        ["start", "stop", "verify"].contains { app.awdBusy.contains("\(event.id):\($0)") }
    }
    private var ordered: [(index: Int, team: EventTeam, status: AWDTeamStatus?)] {
        let map = Dictionary(uniqueKeysWithValues: live.map { ($0.id, $0) })
        return event.teams.enumerated().map { (index: $0.offset, team: $0.element, status: map[$0.element.id]) }
            .sorted { a, b in
                let av = a.status?.verified ?? (a.team.verified == true)
                let bv = b.status?.verified ?? (b.team.verified == true)
                if av != bv { return av }
                return a.index < b.index
            }
    }
    private var verifiedCount: Int {
        event.teams.filter { team in
            live.first(where: { $0.id == team.id })?.verified ?? (team.verified == true)
        }.count
    }
    private var runningCount: Int { live.filter(\.running).count }
    private var serviceCount: Int { event.teams.reduce(0) { $0 + $1.allServices.count } }
    private var attackerCount: Int { event.teams.reduce(0) { $0 + $1.allAttackers.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            if ordered.isEmpty {
                emptyHint
            } else {
                // Rows fall back to the persisted verdict, so keep them visible
                // even before the first live status arrives — but say clearly
                // that the container state has not been read yet.
                if live.isEmpty { emptyHint }
                VStack(spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element.team.id) { position, row in
                        teamRow(rank: position + 1, team: row.team, status: row.status)
                        if position < ordered.count - 1 { hairline }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ArenaTheme.tint(0.018)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ArenaTheme.tint(0.06), lineWidth: 0.8))
            }
        }
        .padding(16)
        .arenaCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                SectionLabel(text: "赛队状态 · 实战验证",
                             trailing: "\(verifiedCount)/\(event.teams.count) 已验证")
                Spacer()
                HStack(spacing: 7) {
                    GhostButton(title: "刷新", systemImage: "arrow.clockwise",
                                enabled: !busy) {
                        Task { await app.refreshAWDStatus(for: event.id) } }
                    GhostButton(title: "启动全部", systemImage: "play.fill", enabled: !busy) {
                        Task { await app.startAWDTeams(event.id, teams: []) } }
                    GhostButton(title: "停止全部", systemImage: "stop.fill",
                                tint: ArenaTheme.accentBright, enabled: !busy) {
                        Task { await app.stopAWDTeams(event.id, teams: []) } }
                    AccentButton(title: "验证全部", systemImage: "checkmark.seal.fill",
                                 busy: app.awdBusy.contains("\(event.id):verify"),
                                 enabled: !busy) {
                        Task { await app.verifyAWDTeams(event.id, teams: []) } }
                }
            }
            HStack(spacing: 7) {
                metricChip("\(serviceCount) 台服务机", color: ArenaTheme.ember)
                metricChip("\(attackerCount) 台攻击机", color: ArenaTheme.accent)
                metricChip("\(runningCount) 支运行中",
                           color: runningCount > 0 ? ArenaTheme.success : ArenaTheme.textTertiary)
                if verifiedCount > 0 {
                    metricChip("\(verifiedCount) 支已验证", color: ArenaTheme.success) }
                Spacer(minLength: 0)
                Text("创建后默认停止；只启动需要测试或比赛的队伍")
                    .font(ArenaType.micro).foregroundStyle(ArenaTheme.textQuaternary)
            }
            if let error = app.awdStatusError[event.id], !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("状态未更新，显示的是上次结果 · \(error)")
                        .font(ArenaType.micro).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ArenaTheme.warning)
            }
        }
    }

    private func metricChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(ArenaType.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.09)))
            .overlay(Capsule().strokeBorder(color.opacity(0.18), lineWidth: 0.7))
    }

    private func teamRow(rank: Int, team: EventTeam, status: AWDTeamStatus?) -> some View {
        let verified = status?.verified ?? (team.verified == true)
        let (label, color) = readiness(status)
        let result = results.first(where: { $0.teamId == team.id })
        // An "untested" result only says the team is stopped; the meaningful
        // detail is the verdict the server kept from the last real test.
        let detail = (result?.untested == true ? nil : result?.detail) ?? team.verifiedDetail
        return HStack(spacing: 12) {
            rankBadge(rank: rank, verified: verified, color: EventTopologyStyle.color(rank - 1))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(team.name)
                        .font(ArenaType.headline)
                        .foregroundStyle(ArenaTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        StatusDot(color: color, pulsing: status?.running == true && !verified)
                        Text(label).font(ArenaType.micro).foregroundStyle(color)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 2.5)
                    .background(Capsule().fill(color.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 0.7))
                    if verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ArenaTheme.success)
                    }
                }
                HStack(spacing: 4) {
                    if let status {
                        ForEach(Array(status.services.enumerated()), id: \.element.id) { index, host in
                            machineStatusChip("S\(index + 1)", host: host, tint: ArenaTheme.ember)
                        }
                        if !status.services.isEmpty && !status.attackers.isEmpty {
                            Rectangle().fill(ArenaTheme.tint(0.1)).frame(width: 0.8, height: 10)
                                .padding(.horizontal, 2)
                        }
                        ForEach(Array(status.attackers.enumerated()), id: \.element.id) { index, host in
                            machineStatusChip("A\(index + 1)", host: host, tint: ArenaTheme.accent)
                        }
                    } else {
                        Text("\(team.allServices.count) 服务机 · \(team.allAttackers.count) 攻击机")
                            .font(ArenaType.micro).foregroundStyle(ArenaTheme.textTertiary)
                    }
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(verified ? ArenaTheme.success : ArenaTheme.textTertiary)
                        .lineLimit(1)
                        .help(detail)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                GhostButton(title: "启动", systemImage: "play.fill", enabled: !busy) {
                    Task { await app.startAWDTeams(event.id, teams: [team.id]) } }
                GhostButton(title: "停止", systemImage: "stop.fill",
                            tint: ArenaTheme.accentBright, enabled: !busy) {
                    Task { await app.stopAWDTeams(event.id, teams: [team.id]) } }
                GhostButton(title: "验证", systemImage: "checkmark.seal",
                            tint: ArenaTheme.success, enabled: !busy) {
                    Task { await app.verifyAWDTeams(event.id, teams: [team.id]) } }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
    }

    private func rankBadge(rank: Int, verified: Bool, color: Color) -> some View {
        ZStack {
            Circle().fill(verified ? ArenaTheme.success.opacity(0.12) : color.opacity(0.1))
                .frame(width: 26, height: 26)
            if verified {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ArenaTheme.success)
            } else {
                Text("\(rank)").font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
    }

    private func machineStatusChip(_ label: String, host: AWDHostStatus, tint: Color) -> some View {
        let running = host.state == "running"
        let ok = host.httpOk
        let color: Color = ok == true ? ArenaTheme.success : (running ? tint : ArenaTheme.textQuaternary)
        return HStack(spacing: 3) {
            Circle().fill(color).frame(width: 3.5, height: 3.5)
            Text(label).font(.system(size: 8.5, weight: .bold, design: .rounded))
            if let state = host.state {
                Text(machineStateLabel(state))
                    .font(.system(size: 8, weight: .medium))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(color.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(color.opacity(0.16), lineWidth: 0.6))
        .help("\(app.host(host.hostId)?.name ?? host.hostId) · \(host.container ?? "—")"
              + (host.port.map { " · :\($0)" } ?? ""))
    }

    private func machineStateLabel(_ state: String) -> String {
        switch state {
        case "running": return "运行"
        case "exited", "stopped": return "已停止"
        case "created": return "未启动"
        case "restarting": return "重启中"
        case "paused": return "已暂停"
        default: return state
        }
    }

    private func readiness(_ status: AWDTeamStatus?) -> (String, Color) {
        guard let status else { return ("未获取状态", ArenaTheme.textTertiary) }
        if status.verified { return ("已验证", ArenaTheme.success) }
        if status.ready { return ("服务就绪", ArenaTheme.success) }
        if status.running { return ("运行中", ArenaTheme.ember) }
        let anyRunning = status.services.contains(where: \.running)
            || status.attackers.contains(where: \.running)
        return anyRunning ? ("部分运行", ArenaTheme.warning) : ("已停止", ArenaTheme.textTertiary)
    }

    private var emptyHint: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "shippingbox")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArenaTheme.textTertiary)
                .padding(.top, 1)
            Text("尚未读取到容器状态。点击「刷新」从 Arena 获取每支队伍的服务机与攻击机状态。")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.tint(0.025)))
    }
}

// MARK: - Panels
private struct HostStatusPanel: View {
    @EnvironmentObject private var app: AppState
    var event: ArenaEvent
    var probes: [HostProbe]
    private var busy: Bool { app.eventBusy.contains(event.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "主机状态", trailing: probes.isEmpty ? "尚未检测" : "\(probes.count) 台")
            if probes.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                       .font(.system(size: 22, weight: .light)).foregroundStyle(ArenaTheme.textQuaternary)
                    Text("尚未检测").font(ArenaType.headline).foregroundStyle(ArenaTheme.textSecondary)
                    Text("赛事开始或刷新状态后，这里会显示每台主机的连通性、延迟与 SSH / Docker 状态。").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                       .multilineTextAlignment(.center).frame(maxWidth: 340).fixedSize(horizontal: false, vertical: true)
                    GhostButton(title: "刷新状态", systemImage: "arrow.clockwise", busy: busy,
                                enabled: !busy) { Task { await app.refreshEvent(event) } }
                }.frame(maxWidth: .infinity).padding(.vertical, 26)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(probes.enumerated()), id: \.element.hostId) { index, probe in
                        HostProbeRow(probe: probe)
                        if index < probes.count - 1 { hairline } } } }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).arenaCard() } }
private struct HostProbeRow: View {
    @EnvironmentObject private var app: AppState
    var probe: HostProbe
    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: probe.online ? ArenaTheme.success : ArenaTheme.danger, pulsing: probe.online)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.host(probe.hostId)?.name ?? probe.hostId).font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                HStack(spacing: 5) {
                    if let host = app.host(probe.hostId) {
                        Text(host.role.label).font(ArenaType.micro).foregroundStyle(host.role.tint) }
                    Text(app.host(probe.hostId)?.displayAddress ?? probe.hostId)
                       .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary).lineLimit(1) } }
            Spacer(minLength: 8)
            Text(probe.latencyMs.map { "\($0) ms" } ?? "—").font(.system(size: 10.5, weight: .medium, design: .monospaced))
               .foregroundStyle(probe.latencyMs != nil ? ArenaTheme.textSecondary : ArenaTheme.textQuaternary)
               .monospacedDigit().frame(width: 56, alignment: .trailing)
            transport("SSH", probe.sshOk); transport("Docker", probe.dockerOk)
        }.padding(.vertical, 9).contentShape(Rectangle()).help([probe.detail, probe.error].compactMap { $0 }.joined(separator: " · ")) }
    private func transport(_ label: String, _ ok: Bool?) -> some View {
        let color = ok == nil ? ArenaTheme.textQuaternary : (ok == true ? ArenaTheme.success : ArenaTheme.danger)
        let value = ok == nil ? "—" : (ok == true ? "正常" : "失败")
        return HStack(spacing: 3) { Text(label); Text(value) }.font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
           .padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(color.opacity(0.1))) } }
private struct AgentsPanel: View {
    var agents: [AgentHeartbeat]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Agent 心跳", trailing: agents.isEmpty ? nil : "\(agents.count) 个")
            if agents.isEmpty {
                VStack(spacing: 9) {
                    ZStack {
                        Circle().fill(ArenaTheme.tint(0.04)).frame(width: 44, height: 44)
                        Image(systemName: "dot.radiowaves.left.and.right")
                           .font(.system(size: 17, weight: .medium)).foregroundStyle(ArenaTheme.textTertiary) }
                    HStack(spacing: 5) {
                        StatusDot(color: ArenaTheme.textQuaternary, pulsing: true)
                        Text("等待 Agent 心跳").font(ArenaType.headline).foregroundStyle(ArenaTheme.textSecondary) }
                    Text("Agent 可在赛事开始后部署到参赛主机，无需现在配置。收到心跳后会显示主机与最后在线时间。").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                       .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity).padding(.vertical, 26).padding(.horizontal, 6)
            } else {
                VStack(spacing: 9) { ForEach(agents) { AgentRow(agent: $0) } } }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).arenaCard() } }
private struct AgentRow: View {
    @EnvironmentObject private var app: AppState
    var agent: AgentHeartbeat
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            StatusDot(color: ArenaTheme.success, pulsing: true).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name ?? agent.hostname ?? app.host(agent.hostId)?.name ?? agent.hostId).font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                Text(agent.hostname ?? agent.hostId).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary).lineLimit(1)
                if let detail = agent.detail, !detail.isEmpty {
                    Text(detail).font(ArenaType.caption).foregroundStyle(ArenaTheme.textQuaternary).lineLimit(1) } }
            Spacer(minLength: 6)
            Text(agent.lastSeenLabel ?? "—").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary).lineLimit(1)
        }.padding(10).background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(ArenaTheme.tint(0.03))) } }
private struct AgentActivityPanel: View {
    var activities: [AgentActivity]
    var onDeploy: () -> Void
    private var listHeight: CGFloat { min(CGFloat(activities.count) * 58, 260) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SectionLabel(text: "Agent 战况", trailing: "\(activities.count) 条")
                GhostButton(title: "部署 Agent", systemImage: "person.badge.key",
                            tint: ArenaTheme.textPrimary) { onDeploy() } }
            if activities.isEmpty { emptyState } else { timeline }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).arenaCard() }
    private var timeline: some View {
        ScrollView(showsIndicators: activities.count > 4) {
            VStack(spacing: 0) {
                ForEach(Array(activities.enumerated()), id: \.offset) { index, activity in
                    ActivityRow(activity: activity)
                    if index < activities.count - 1 { hairline } }
            }
        }.frame(height: listHeight) }
    private var emptyState: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle().fill(ArenaTheme.tint(0.04)).frame(width: 44, height: 44)
                Image(systemName: "scope")
                   .font(.system(size: 17, weight: .medium)).foregroundStyle(ArenaTheme.textTertiary) }
            Text("尚无 Agent 活动").font(ArenaType.headline).foregroundStyle(ArenaTheme.textSecondary)
            Text("参赛者的 Agent 通过心跳上报侦察、攻击等活动；应用只显示它们主动上报的内容，不会在本地伪造战况。")
               .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
               .multilineTextAlignment(.center).frame(maxWidth: 440).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity).padding(.vertical, 26).padding(.horizontal, 6) } }
private struct ActivityRow: View {
    @EnvironmentObject private var app: AppState
    var activity: AgentActivity
    private var tint: Color { ActivityStyle.color(activity.kind) }
    private var hostName: String { app.host(activity.hostId)?.name ?? activity.hostId }
    private var tooltip: String {
        if let detail = activity.detail, !detail.isEmpty { return detail }
        return "\(hostName) · \(ActivityStyle.label(activity.kind))" }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.opacity(0.12))
                Image(systemName: ActivityStyle.symbol(activity.kind))
                   .font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            }.frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.summary.isEmpty ? "（无摘要）" : activity.summary)
                   .font(ArenaType.body.weight(.medium)).foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                HStack(spacing: 5) {
                    hostChip
                    if let target = activity.target, !target.isEmpty { targetChip(target) } } }
            Spacer(minLength: 8)
            Text(RelativeTime.label(activity.receivedAt ?? activity.at))
               .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
               .monospacedDigit().lineLimit(1)
        }.padding(.vertical, 9).contentShape(Rectangle()).help(tooltip) }
    private var hostChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "server.rack").font(.system(size: 8, weight: .semibold))
            Text(hostName).font(ArenaType.caption).lineLimit(1) }
        .foregroundStyle(ArenaTheme.textSecondary)
        .padding(.horizontal, 6).padding(.vertical, 2.5)
        .background(Capsule().fill(ArenaTheme.tint(0.05)))
        .overlay(Capsule().strokeBorder(ArenaTheme.tint(0.09), lineWidth: 0.8)) }
    private func targetChip(_ target: String) -> some View {
        Text(target).font(.system(size: 9.5, weight: .medium, design: .monospaced))
           .foregroundStyle(ArenaTheme.textSecondary).lineLimit(1)
           .padding(.horizontal, 6).padding(.vertical, 2)
           .background(Capsule().fill(ArenaTheme.tint(0.05)))
           .overlay(Capsule().strokeBorder(ArenaTheme.tint(0.09), lineWidth: 0.8)) } }

// MARK: - Invite
private struct InviteSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    var event: ArenaEvent
    @State private var invite: InvitePayload?
    @State private var errorText: String?
    @State private var loading = true
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    eyebrow("SHARE EVENT")
                    Text("邀请参赛者").font(.system(size: 22, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                    Text("\(event.name) · \(event.formatLabel)").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary) }
                Spacer()
                RoundIconButton(systemImage: "xmark", help: "关闭") { dismiss() }
            }.padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 16)
            hairline
            Group {
                if loading {
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text("正在生成邀请信息…").font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary) }
                } else if invite != nil { content } else {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 24, weight: .light)).foregroundStyle(ArenaTheme.warning)
                        Text(errorText ?? "未能生成邀请信息").font(ArenaType.headline)
                           .foregroundStyle(ArenaTheme.textSecondary).multilineTextAlignment(.center)
                        GhostButton(title: "重试", systemImage: "arrow.clockwise") { Task { await load() } }
                    }.padding(30) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            hairline
            HStack(spacing: 10) {
                Text("地址来自当前主机记录，端口以主机配置为准。").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                Spacer()
                GhostButton(title: "关闭") { dismiss() }
            }.padding(.horizontal, 26).padding(.vertical, 15)
        }.frame(width: 680, height: 640).background(ArenaTheme.background).task { await load() } }
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "person.2.wave.2.fill").font(.system(size: 12, weight: .semibold))
                       .foregroundStyle(ArenaTheme.success).padding(.top, 1)
                    Text("这里列出的是训练网中的主机与端口。Mac 用户需通过已授权的 SSH 连接接入；解题台可生成本机访问地址，本机地址不能转发给其他电脑使用。").font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary)
                       .fixedSize(horizontal: false, vertical: true)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                   .fill(ArenaTheme.success.opacity(0.07))).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                   .strokeBorder(ArenaTheme.success.opacity(0.16), lineWidth: 0.8))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        SectionLabel(text: "队伍接入信息", trailing: "\(event.teams.count) 支队伍")
                        CopyChip(text: teamLines, label: "复制接入说明") }
                    codeText(teamLines, maxHeight: nil) }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        SectionLabel(text: "邀请 JSON", trailing: "arenactl events invite")
                        CopyChip(text: prettyJSON, label: "复制 JSON") }
                    codeText(prettyJSON, maxHeight: 190) }
            }.padding(.horizontal, 26).padding(.vertical, 20) } }
    private var teamLines: String {
        guard !event.teams.isEmpty else { return "尚未配置队伍。" }
        let targetLabel = event.awd == true ? "服务机" : "靶机"
        return event.teams.map { team in
            var lines = [team.name]
            let attackers = team.allAttackers
            let services = team.allServices
            if attackers.isEmpty {
                lines.append("  攻击机  未绑定")
            } else {
                for (index, id) in attackers.enumerated() {
                    lines.append("  攻击机 \(index + 1)  \(addressLabel(id))")
                }
            }
            if services.isEmpty {
                lines.append("  \(targetLabel)  未绑定")
            } else {
                for (index, id) in services.enumerated() {
                    lines.append("  \(targetLabel) \(index + 1)  \(addressLabel(id))")
                }
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n") }
    private var prettyJSON: String {
        guard let invite else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
        guard let data = try? encoder.encode(invite), let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text }
    private func addressLabel(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "未绑定" }
        guard let host = app.host(id) else { return id }
        if host.role == .attacker { return "\(host.name) · 通过解题台终端进入" }
        let address = host.address + (host.ports.isEmpty ? "" : ":" + host.ports.map(String.init).joined(separator: ","))
        return "\(host.name) · 训练网 \(address)" }
    private func codeText(_ text: String, maxHeight: CGFloat?) -> some View {
        let view = Text(text.isEmpty ? "—" : text).font(ArenaType.mono).foregroundStyle(ArenaTheme.textSecondary).textSelection(.enabled)
           .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if let maxHeight {
                ScrollView(showsIndicators: true) { view.padding(13) }.frame(height: maxHeight)
            } else { view.padding(13) }
        }.frame(maxWidth: .infinity, alignment: .leading)
       .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.codeBackground))
       .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ArenaTheme.tint(0.08), lineWidth: 0.8)) }
    @MainActor private func load() async {
        loading = true
        errorText = nil
        let response = await app.invite(event)
        if let payload = response?.invite { invite = payload } else { errorText = response?.error ?? "未能生成邀请信息" }
        loading = false } }

// MARK: - Deploy agent
private struct AgentDeploySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    var event: ArenaEvent
    @State private var selectedHost = ""
    private var eventID: String { event.id.isEmpty ? "<event-id>" : event.id }
    private var hostID: String { selectedHost.isEmpty ? "<host-id>" : selectedHost }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    eyebrow("DEPLOY AGENT")
                    Text("部署 Agent").font(.system(size: 22, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                    Text("\(event.name) · Agent 只上报遥测").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary) }
                Spacer()
                RoundIconButton(systemImage: "xmark", help: "关闭") { dismiss() }
            }.padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 16)
            hairline
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    hostSection
                    heartbeatSection
                    reportSection
                    activitySection
                }.padding(.horizontal, 26).padding(.vertical, 20) }
            hairline
            HStack(spacing: 10) {
                Text("复制命令到参赛主机执行；应用不会自动部署或运行 Agent。").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                Spacer()
                GhostButton(title: "关闭") { dismiss() }
            }.padding(.horizontal, 26).padding(.vertical, 15)
        }.frame(width: 680, height: 640).background(ArenaTheme.background)
        .onAppear { if selectedHost.isEmpty { selectedHost = event.hosts.first ?? "" } } }
    private var intro: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle").font(.system(size: 12, weight: .semibold))
               .foregroundStyle(ArenaTheme.accent).padding(.top, 1)
            Text("Agent 运行在参赛者自己的主机上，只向赛事上报心跳与活动遥测。竞技场不会代你执行扫描或攻击，所有操作仍由参赛者在主机上完成。")
               .font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary)
               .fixedSize(horizontal: false, vertical: true)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
       .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.accent.opacity(0.06)))
       .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
           .strokeBorder(ArenaTheme.accent.opacity(0.14), lineWidth: 0.8)) }
    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "上报主机", trailing: event.hosts.isEmpty ? "尚未配置主机" : "\(event.hosts.count) 台")
            if event.hosts.isEmpty {
                Text("赛事还没有主机，先到「主机与拓扑」添加。下面的命令会以 <host-id> 占位。")
                   .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                   .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 9) {
                    Picker("上报主机", selection: $selectedHost) {
                        ForEach(event.hosts, id: \.self) { id in Text(hostLabel(id)).tag(id) }
                    }.pickerStyle(.menu).labelsHidden().frame(maxWidth: 320, alignment: .leading)
                    Text(hostID).font(.system(size: 10, design: .monospaced))
                       .foregroundStyle(ArenaTheme.textTertiary).lineLimit(1).help("主机 ID")
                    Spacer(minLength: 0) } }
        } }
    private var heartbeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SectionLabel(text: "1 · 启动 Agent", trailing: "在参赛主机上运行")
                CopyChip(text: heartbeatCommand, label: "复制命令") }
            codeText(heartbeatCommand, maxHeight: nil)
            Text("Agent 按 15 秒间隔写出 /tmp/arena-hb.json；它只采集遥测，不会在主机上执行攻击动作。")
               .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
               .fixedSize(horizontal: false, vertical: true) }
    }
    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SectionLabel(text: "2 · 上报到控制面", trailing: "控制面侧运行")
                CopyChip(text: reportCommand, label: "复制命令") }
            codeText(reportCommand, maxHeight: nil)
            Text("主机无法直接访问控制面时，由 Arena 操作方在能读到心跳文件的一侧执行这条命令。")
               .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
               .fixedSize(horizontal: false, vertical: true) }
    }
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SectionLabel(text: "3 · 上报一条活动", trailing: "示例 JSON")
                CopyChip(text: activityJSON, label: "复制 JSON") }
            codeText(activityJSON, maxHeight: 150)
            HStack(spacing: 10) {
                SectionLabel(text: "对应命令")
                CopyChip(text: activityCommand, label: "复制命令") }
            codeText(activityCommand, maxHeight: nil)
            Text("kind 可取 recon、scan、exploit、attack、flag、login 等；target 可选。也可以用 activities 数组一次上报多条，服务端保留最近 300 条。")
               .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
               .fixedSize(horizontal: false, vertical: true) }
    }
    private var heartbeatCommand: String {
        "ARENA_EVENT=\(eventID) ARENA_HOST=\(hostID) arena-agent --interval 15 --out /tmp/arena-hb.json" }
    private var reportCommand: String {
        "arenactl events agent-report \(eventID) \(hostID) \"$(cat /tmp/arena-hb.json)\"" }
    private var activityJSON: String {
        """
        {
          "activity": {
            "kind": "recon",
            "summary": "扫描 10.0.0.5:8081",
            "target": "10.0.0.5:8081"
          }
        }
        """ }
    private var activityPayload: String {
        #"{"activity":{"kind":"recon","summary":"扫描 10.0.0.5:8081","target":"10.0.0.5:8081"}}"# }
    private var activityCommand: String {
        "arenactl events agent-report \(eventID) \(hostID) '\(activityPayload)'" }
    private func hostLabel(_ id: String) -> String {
        app.host(id)?.name ?? id }
    private func codeText(_ text: String, maxHeight: CGFloat?) -> some View {
        let view = Text(text.isEmpty ? "—" : text).font(ArenaType.mono).foregroundStyle(ArenaTheme.textSecondary).textSelection(.enabled)
           .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if let maxHeight {
                ScrollView(showsIndicators: true) { view.padding(13) }.frame(height: maxHeight)
            } else { view.padding(13) }
        }.frame(maxWidth: .infinity, alignment: .leading)
       .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.codeBackground))
       .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ArenaTheme.tint(0.08), lineWidth: 0.8)) } }

// MARK: - Helpers
private func eventFormatColor(_ format: String) -> Color {
    switch format { case "awd": return ArenaTheme.accent; case "koh": return ArenaTheme.gold; default: return ArenaTheme.ember } }
private func eventFormatSymbol(_ format: String) -> String {
    switch format { case "awd": return "flag.2.crossed.fill"; case "koh": return "crown.fill"; default: return "slider.horizontal.3" } }
private func statusLabel(_ status: String) -> String {
    ["running": "进行中", "paused": "已暂停", "ended": "已结束", "draft": "草稿"][status] ?? (status.isEmpty ? "未知" : status) }
private func statusColor(_ status: String) -> Color {
    status == "running" ? ArenaTheme.accent : (status == "paused" ? ArenaTheme.warning : ArenaTheme.textTertiary) }
private enum EventTopologyStyle {
    static let palette: [Color] = [ArenaTheme.accent, ArenaTheme.ember, ArenaTheme.gold,
                                   ArenaTheme.success, ArenaTheme.accentBright]
    static func color(_ index: Int) -> Color { palette[index % palette.count] } }
private enum DateText {
    static func date(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) }
    static func short(_ raw: String?) -> String {
        guard let date = date(raw) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date) }
}
private enum RelativeTime {
    static func label(_ raw: String?) -> String {
        guard let date = DateText.date(raw) else { return "—" }
        let seconds = Int(max(0, Date().timeIntervalSince(date)))
        if seconds < 45 { return "刚刚" }
        if seconds < 3600 { return "\(max(1, seconds / 60)) 分钟前" }
        if seconds < 86_400 { return "\(seconds / 3600) 小时前" }
        return "\(seconds / 86_400) 天前" }
}
private enum ActivityStyle {
    static func symbol(_ kind: String?) -> String {
        let kind = (kind ?? "").lowercased()
        if kind.contains("recon") || kind.contains("scan") { return "scope" }
        if kind.contains("exploit") || kind.contains("attack") { return "bolt.fill" }
        if kind.contains("flag") || kind.contains("capture") { return "flag.fill" }
        if kind.contains("login") || kind.contains("heartbeat") { return "dot.radiowaves.left.and.right" }
        return "circle.fill" }
    static func color(_ kind: String?) -> Color {
        let kind = (kind ?? "").lowercased()
        if kind.contains("recon") || kind.contains("scan") { return ArenaTheme.ember }
        if kind.contains("exploit") || kind.contains("attack") { return ArenaTheme.accent }
        if kind.contains("flag") || kind.contains("capture") { return ArenaTheme.gold }
        if kind.contains("login") || kind.contains("heartbeat") { return ArenaTheme.success }
        return ArenaTheme.textTertiary }
    static func label(_ kind: String?) -> String {
        let kind = (kind ?? "").lowercased()
        if kind.contains("recon") { return "侦察" }
        if kind.contains("scan") { return "扫描" }
        if kind.contains("exploit") { return "利用" }
        if kind.contains("attack") { return "攻击" }
        if kind.contains("flag") || kind.contains("capture") { return "夺取 flag" }
        if kind.contains("login") { return "登录" }
        if kind.contains("heartbeat") { return "心跳" }
        return kind.isEmpty ? "活动" : kind }
}
