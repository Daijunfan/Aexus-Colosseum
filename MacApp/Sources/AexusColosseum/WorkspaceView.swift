import SwiftUI
import AppKit
import WebKit

/// The place where a challenge is actually solved: a mission brief on the
/// left, an SSH console into the attack host, and an embedded browser for the
/// target's web surface.  Every command runs on the attacker, never on the Mac
/// and never on Arena.
struct WorkspaceView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var shell = RemoteShell()

    @State private var terminalExpanded = false
    @State private var showPicker = false
    @State private var webURL: URL?
    @State private var shareText: String?
    @State private var pickerSearch = ""

    private var topology: Topology? { app.activeTopology }
    private var workspaceContext: WorkspaceContext? { app.workspaceContext }
    private var attacker: PlatformHost? {
        if let context = workspaceContext { return app.host(context.attackerID) }
        return app.host(topology?.attacker)
    }
    private var target: PlatformHost? {
        if let context = workspaceContext { return app.host(context.targetID) }
        return lab.map { app.labHost($0) } ?? app.host(topology?.target)
    }
    private var lab: Lab? { app.workspaceLab }
    private var teamAttackers: [PlatformHost] {
        (app.workspaceTeam?.allAttackers ?? []).compactMap { app.host($0) }
    }
    private var teamServices: [PlatformHost] {
        (app.workspaceTeam?.allServices ?? []).compactMap { app.host($0) }
    }
    /// In an event the target is the team's own service container: its web
    /// entry is the published loopback port, not a catalog lab's port.
    private var webAccess: LabAccess? {
        if workspaceContext != nil {
            guard let port = target?.ports.first else { return nil }
            return LabAccess(label: "服务机 Web", port: port, scheme: "http", path: "/")
        }
        return lab?.webAccess
    }
    private var extraAccess: [LabAccess] {
        workspaceContext == nil ? (lab?.access ?? []) : []
    }
    /// Live dot for a machine.  AWD containers are not part of the general
    /// host-probe loop, so event mode reads their state from the arena status.
    private func awdStatus(_ id: String?) -> AWDHostStatus? {
        guard let id, let context = workspaceContext else { return nil }
        for team in app.awdTeams[context.eventID] ?? [] {
            if let host = (team.services + team.attackers).first(where: { $0.hostId == id }) {
                return host
            }
        }
        return nil
    }

    private func hostOnline(_ id: String?) -> Bool {
        guard let id else { return false }
        if id == attacker?.id, shell.connected { return true }
        if workspaceContext != nil { return awdStatus(id)?.state == "running" }
        if let lab, id == app.labHost(lab).id { return lab.running }
        return app.hostProbes[id]?.online == true
    }

    private func machineLabel(_ status: AWDHostStatus?) -> String {
        switch status?.state {
        case "running": return "运行中"
        case "restarting": return "重启中"
        case "paused": return "已暂停"
        case "exited": return "已停止"
        case "created": return "未启动"
        case let state?: return state
        case nil: return "未知"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if workspaceContext != nil || (attacker != nil && target != nil) {
                        topologyBar
                    }
                    if attacker != nil, target != nil {
                        if !terminalExpanded { missionRow }
                        HStack(alignment: .top, spacing: 14) {
                            consoleCard
                                .frame(maxWidth: .infinity)
                            if !terminalExpanded {
                                targetCard.frame(width: 340)
                            }
                        }
                        .frame(height: max(380, geometry.size.height - (terminalExpanded ? 220 : 405)))
                    } else {
                        onboarding
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 30)
                .frame(maxWidth: 1280)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showPicker) { challengePicker }
        .task(id: attacker) {
            if let attacker, shell.host != attacker {
                shell.start(host: attacker)
            } else if attacker == nil {
                shell.stop()
            }
        }
        .onDisappear { shell.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            shell.stop()
        }
        // The events screen's poller stops when this view takes over, so keep
        // the team's container state live while the operator is attacking.
        .task(id: workspaceContext?.eventID) {
            guard let id = workspaceContext?.eventID else { return }
            while !Task.isCancelled {
                await app.refreshAWDStatus(for: id)
                if let event = app.event(id) { await app.pollEvent(event) }
                try? await Task.sleep(nanoseconds: 12_000_000_000)
            }
        }
        .task(id: lab?.id) {
            // Automation hook used by the visual test harness.
            guard ProcessInfo.processInfo.environment["AEXUS_OPENWEB"] == "1",
                  let web = lab?.webAccess else { return }
            for _ in 0..<60 {
                if target != nil {
                    openWeb(web)
                    return
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        .onChange(of: lab?.id) { _, _ in
            webURL = nil
        }
        .onChange(of: app.workspaceContext) { _, _ in
            webURL = nil
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("WORKSPACE")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(3.2)
                    .foregroundStyle(ArenaTheme.accentBright.opacity(0.9))
                Text("解题台")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text(workspaceContext == nil
                     ? "题目在左边，攻击机在中间，靶机入口在右边。所有命令都从攻击机发出。"
                     : "赛事模式：终端连到本队攻击机，右侧直达本队服务机。所有命令都从攻击机发出。")
                    .font(ArenaType.body)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer()
            HStack(spacing: 8) {
                GhostButton(title: "主机与拓扑", systemImage: "server.rack", tint: ArenaTheme.textSecondary) {
                    withAnimation(Motion.page) { app.mode = .hosts }
                }
                AccentButton(title: "选择题目", systemImage: "list.bullet.rectangle") {
                    showPicker = true
                }
            }
        }
    }

    // MARK: Topology bar

    private var topologyBar: some View {
        HStack(spacing: 12) {
            if let context = workspaceContext {
                HStack(spacing: 8) {
                    Image(systemName: "flag.2.crossed.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArenaTheme.accentBright)
                    Text(context.eventName)
                        .font(ArenaType.headline)
                        .foregroundStyle(ArenaTheme.textPrimary)
                        .lineLimit(1)
                    Chip(text: "参赛 · \(context.teamName)", color: ArenaTheme.accent)
                }
            } else if let topology {
                HStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArenaTheme.accentBright)
                    Text(lab.map { "训练环境 · \($0.name)" } ?? topology.name)
                        .font(ArenaType.headline)
                        .foregroundStyle(ArenaTheme.textPrimary)
                }
            }
            Divider().frame(height: 14)
            hostMenu(attacker, role: "攻击机", options: teamAttackers) { id in
                app.setWorkspaceHost(attackerID: id)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ArenaTheme.textQuaternary)
            hostMenu(target, role: workspaceContext == nil ? "靶机" : "服务机",
                     options: teamServices) { id in
                app.setWorkspaceHost(targetID: id)
            }
            Spacer()
            if workspaceContext != nil {
                GhostButton(title: "退出赛事", systemImage: "rectangle.portrait.and.arrow.right",
                            tint: ArenaTheme.textSecondary) {
                    withAnimation(Motion.page) { app.clearWorkspaceContext() }
                }
            } else if let topology {
                statusPill(topology)
                GhostButton(title: "检测", systemImage: "antenna.radiowaves.left.and.right", tint: ArenaTheme.textSecondary) {
                    Task { await app.testTopology(topology.id) }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .arenaCard(radius: 14, fill: ArenaTheme.card.opacity(0.9))
    }

    private func hostPill(_ host: PlatformHost?, role: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(host.map { hostOnline($0.id) ? ArenaTheme.success : ArenaTheme.textQuaternary }
                          ?? ArenaTheme.textQuaternary)
                .frame(width: 6, height: 6)
            Text(role)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textQuaternary)
            Text(host?.name ?? "未绑定")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArenaTheme.textSecondary)
                .lineLimit(1)
        }
    }

    /// A team can own several attackers or services.  With one machine this is
    /// the plain pill; with more, it becomes a menu so the operator can move
    /// between them without leaving the workspace.
    @ViewBuilder
    private func hostMenu(_ host: PlatformHost?, role: String,
                          options: [PlatformHost], pick: @escaping (String) -> Void) -> some View {
        if options.count > 1 {
            Menu {
                ForEach(options) { option in
                    Button {
                        pick(option.id)
                    } label: {
                        if option.id == host?.id {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(option.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    hostPill(host, role: role)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textQuaternary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            hostPill(host, role: role)
        }
    }

    private func statusPill(_ topology: Topology) -> some View {
        let (label, color): (String, Color)
        switch topology.status {
        case "ready": (label, color) = ("可用", ArenaTheme.success)
        case "partial": (label, color) = ("部分可用", ArenaTheme.warning)
        case "offline": (label, color) = ("不可用", ArenaTheme.danger)
        default: (label, color) = ("待检测", ArenaTheme.textTertiary)
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.11)))
    }

    // MARK: Mission brief

    private var missionRow: some View {
        HStack(alignment: .top, spacing: 14) {
            missionBrief
                .frame(maxWidth: .infinity)
            quickActions
                .frame(width: 300)
        }
    }

    private var missionBrief: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text(workspaceContext?.eventName ?? lab?.name ?? "选择一个靶场开始")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                if workspaceContext != nil {
                    Text("AWD")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(ArenaTheme.accentBright)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(ArenaTheme.accent.opacity(0.1)))
                } else if let lab {
                    Text(lab.category.uppercased())
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(ArenaTheme.accentBright)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(ArenaTheme.accent.opacity(0.1)))
                }
                Spacer()
                if let lab { DifficultyDots(level: lab.difficulty,
                                            color: lab.difficulty >= 3 ? ArenaTheme.accent : ArenaTheme.ember) }
            }
            Text(workspaceContext != nil
                 ? "从攻击机发起攻击，服务机是你要攻破的目标；守住自己的服务，别让对手拿分。"
                 : (lab?.summary ?? "在题库中挑一个环境，启动后即可在这里攻击。"))
                .font(ArenaType.body)
                .foregroundStyle(ArenaTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let context = workspaceContext {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(teamServices) { host in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(hostOnline(host.id) ? ArenaTheme.success : ArenaTheme.textQuaternary)
                                .frame(width: 5, height: 5)
                            Text("服务机 · \(host.name)")
                                .font(ArenaType.callout)
                                .foregroundStyle(ArenaTheme.textTertiary)
                            if let port = host.ports.first {
                                Text(":\(String(port))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(ArenaTheme.textQuaternary)
                            }
                        }
                    }
                    if let team = app.awdTeams[context.eventID]?.first(where: { $0.id == context.teamID }) {
                        Text("本队 \(context.teamName) · \(team.ready ? "环境就绪" : "待检测") · \(team.verified ? "已验证" : "未验证")")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textQuaternary)
                    }
                }
            } else if let lab, !lab.objectives.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lab.objectives.prefix(3).enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 7) {
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(ArenaTheme.accentBright)
                                .frame(width: 13, height: 13)
                                .background(Circle().fill(ArenaTheme.accent.opacity(0.12)))
                            Text(item)
                                .font(ArenaType.callout)
                                .foregroundStyle(ArenaTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .arenaCard(radius: 16)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(workspaceContext == nil ? "环境" : "本队机器")
                .font(ArenaType.caption.weight(.semibold))
                .foregroundStyle(ArenaTheme.textTertiary)
            if let context = workspaceContext {
                ForEach(teamAttackers) { host in
                    HStack(spacing: 8) {
                        StatusDot(color: hostOnline(host.id) ? ArenaTheme.success : ArenaTheme.textQuaternary,
                                  pulsing: hostOnline(host.id))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(host.name)
                                .font(ArenaType.body)
                                .foregroundStyle(ArenaTheme.textSecondary)
                                .lineLimit(1)
                            Text("攻击机 · \(machineLabel(awdStatus(host.id)))")
                                .font(ArenaType.caption)
                                .foregroundStyle(ArenaTheme.textQuaternary)
                        }
                        Spacer()
                        if host.id == attacker?.id {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ArenaTheme.accentBright)
                                .help("当前终端")
                        }
                    }
                }
                ForEach(teamServices) { host in
                    HStack(spacing: 8) {
                        StatusDot(color: hostOnline(host.id) ? ArenaTheme.success : ArenaTheme.textQuaternary,
                                  pulsing: hostOnline(host.id))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(host.name)
                                .font(ArenaType.body)
                                .foregroundStyle(ArenaTheme.textSecondary)
                                .lineLimit(1)
                            Text("服务机 · \(machineLabel(awdStatus(host.id)))")
                                .font(ArenaType.caption)
                                .foregroundStyle(ArenaTheme.textQuaternary)
                        }
                        Spacer()
                        if host.id == target?.id {
                            Image(systemName: "scope")
                                .font(.system(size: 9))
                                .foregroundStyle(ArenaTheme.accentBright)
                                .help("当前目标")
                        }
                    }
                }
                if let team = app.awdTeams[context.eventID]?.first(where: { $0.id == context.teamID }),
                   !team.ready {
                    Text("赛前请先在赛事页「验证」本队机器。")
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let lab {
                HStack(spacing: 8) {
                    StatusDot(color: lab.running ? ArenaTheme.success : ArenaTheme.textQuaternary,
                              pulsing: lab.running)
                    Text(lab.running ? "靶场运行中" : (lab.installed ? "已安装，未启动" : "尚未下载"))
                        .font(ArenaType.body)
                        .foregroundStyle(ArenaTheme.textSecondary)
                    Spacer()
                }
                if lab.running {
                    GhostButton(title: "停止靶场", systemImage: "stop.fill", tint: ArenaTheme.textSecondary) {
                        Task { await app.stop(lab) }
                    }
                } else if lab.installed {
                    AccentButton(title: "启动靶场", systemImage: "play.fill", busy: app.isBusy(lab.id), wide: true) {
                        Task { await app.start(lab) }
                    }
                } else {
                    AccentButton(title: "下载并启动", systemImage: "arrow.down.circle", busy: app.isBusy(lab.id), wide: true) {
                        Task {
                            await app.install(lab)
                            await app.start(lab)
                        }
                    }
                }
                if !lab.credentials.isEmpty && lab.credentials != "无" {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "key.fill").font(.system(size: 9)).foregroundStyle(ArenaTheme.ember)
                        Text(lab.credentials)
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("尚未选择题目")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .arenaCard(radius: 16)
    }

    // MARK: Console

    private var consoleCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "ADB8CC"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(attacker?.name ?? "攻击机终端")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E6E9EF"))
                    Text(attacker?.displayAddress ?? "远程会话")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(hex: "929DAF"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                HStack(spacing: 5) {
                    Circle().fill(terminalStatusColor).frame(width: 6, height: 6)
                    Text(shell.statusLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(terminalStatusColor)
                        .fixedSize()
                }
                terminalButton("stop.fill", label: "中断当前命令（Ctrl+C）", enabled: shell.connected) {
                    shell.sendControlC()
                }
                terminalButton("arrow.clockwise", label: "重新连接", enabled: !shell.connecting) {
                    if let attacker { shell.start(host: attacker) }
                }
                terminalButton(terminalExpanded ? "arrow.down.right.and.arrow.up.left"
                               : "arrow.up.left.and.arrow.down.right",
                               label: terminalExpanded ? "收起终端" : "展开终端") {
                    terminalExpanded.toggle()
                    shell.focus()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(hex: "1D2129"))

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)

            Group {
                if let terminal = shell.terminal {
                    RemoteTerminalView(terminal: terminal)
                        .id(ObjectIdentifier(terminal))
                } else {
                    Text("正在准备远程终端…")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color(hex: "929DAF"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(Color(hex: "15181E"))

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)

            HStack(spacing: 6) {
                terminalButton("minus", label: "缩小终端字号", enabled: shell.fontSize > 11) {
                    shell.adjustFont(by: -1)
                }
                Text("\(Int(shell.fontSize))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "AAB4C5"))
                    .frame(width: 18)
                terminalButton("plus", label: "放大终端字号", enabled: shell.fontSize < 22) {
                    shell.adjustFont(by: 1)
                }
                Spacer(minLength: 6)
                Text(terminalHint)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "929DAF"))
                    .lineLimit(1)
                    .help(terminalHint)
                terminalButton("eraser", label: "清空终端", enabled: !shell.connecting) {
                    shell.clear()
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color(hex: "1D2129"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            .allowsHitTesting(false))
        .shadow(color: ArenaTheme.shadow(0.35), radius: 18, y: 10)
    }

    private var terminalStatusColor: Color {
        switch shell.state {
        case .connected: return Color(hex: "72D6A0")
        case .connecting: return Color(hex: "E9BE72")
        case .failed, .closed(.some(255)): return Color(hex: "F18B82")
        default: return Color(hex: "929DAF")
        }
    }

    private var terminalHint: String {
        switch shell.state {
        case .connecting: return "正在等待远端 Shell 就绪…"
        case .connected: return "Tab 补全 · ↑ 历史 · ⌃C 中断"
        case .failed(let message): return message
        default: return "点击右上角重连，继续使用终端"
        }
    }

    private func terminalButton(_ symbol: String, label: String, enabled: Bool = true,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "B5BECE").opacity(enabled ? 1 : 0.3))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .disabled(!enabled)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: Target card

    private var targetCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
            Text(workspaceContext == nil ? "靶机入口" : "服务机入口")
                .font(ArenaType.caption.weight(.semibold))
                .foregroundStyle(ArenaTheme.textTertiary)

            if let target {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(ArenaTheme.ember)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(target.name)
                            .font(ArenaType.headline)
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Text(target.displayAddress)
                            .font(ArenaType.mono)
                            .foregroundStyle(ArenaTheme.textTertiary)
                    }
                    Spacer()
                    Circle()
                        .fill(hostOnline(target.id) ? ArenaTheme.success : ArenaTheme.textQuaternary)
                        .frame(width: 7, height: 7)
                }
            }

            if let web = webAccess {
                accessRow(web)
                if let url = webURL {
                    WebPreview(url: url)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(ArenaTheme.hairline, lineWidth: 1))
                } else {
                    Button {
                        openWeb(web)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "globe.asia.australia.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(ArenaTheme.accentBright)
                            Text(workspaceContext == nil ? "在应用内打开靶场" : "在应用内打开服务")
                                .font(ArenaType.callout.weight(.semibold))
                                .foregroundStyle(ArenaTheme.textSecondary)
                            Text("通过 SSH 隧道转发，不暴露公网")
                                .font(ArenaType.caption)
                                .foregroundStyle(ArenaTheme.textQuaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ArenaTheme.tint(0.025)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .disabled(workspaceContext == nil && !(lab?.running == true
                                                          || lab?.access.isEmpty == false))
                }
            } else if workspaceContext != nil {
                Text("该服务机没有发布 Web 端口，请在左侧终端直接访问。")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            } else if lab != nil {
                Text("该环境使用专用协议。可在左侧 Kali 终端操作，或连接到 Mac 后使用对应客户端。")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            } else {
                Text("先选择一道题目")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            if let target {
                ForEach(workspaceContext == nil ? extraAccess : [webAccess].compactMap { $0 }) { access in
                    LabAccessRow(access: access, target: target,
                                 running: workspaceContext == nil ? lab?.running == true : hostOnline(target.id),
                                 tunnel: app.connections.tunnel(target: target, port: access.port))
                }
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxHeight: .infinity)
        .arenaCard(radius: 16)
    }

    private func accessRow(_ access: LabAccess) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "link")
                .font(.system(size: 9))
                .foregroundStyle(ArenaTheme.accentBright)
            Text(access.label)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
            Spacer()
            Text("端口 \(String(access.port))")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textQuaternary)
        }
    }

    private func openWeb(_ access: LabAccess) {
        guard let target else { return }
        Task { webURL = await app.macURL(for: access, target: target) }
    }

    // MARK: Onboarding

    private var onboarding: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(ArenaTheme.accentBright)
                Text("先把两台主机接成一个拓扑")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text("解题台需要一台攻击机和一台靶机。Arena-Kali 是独立的 Kali Linux 虚拟机；靶机可以选内置环境，也可以绑定你自己的机器。")
                    .font(ArenaType.body)
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 32)

            HStack(alignment: .top, spacing: 12) {
                step(1, "准备攻击机", "启动独立的 Arena-Kali 虚拟机，或绑定已有 Kali 主机。") {
                    AccentButton(title: "启动 Arena-Kali", systemImage: "bolt.shield.fill",
                                 busy: app.platformLoading, wide: true) {
                        Task { await app.deployAttackHost() }
                    }
                }
                step(2, "绑定靶机", "内置环境由 Arena 托管；外部靶机填入 IP 和 SSH 信息。") {
                    GhostButton(title: "添加主机", systemImage: "plus", tint: ArenaTheme.textSecondary) {
                        withAnimation(Motion.page) { app.mode = .hosts }
                    }
                }
                step(3, "建立拓扑", "指定一台攻击机和一台靶机，检测连通性。") {
                    GhostButton(title: "主机与拓扑", systemImage: "arrow.right", tint: ArenaTheme.textSecondary) {
                        withAnimation(Motion.page) { app.mode = .hosts }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .arenaCard(radius: 20)
    }

    private func step<Content: View>(_ index: Int, _ title: String, _ body: String,
                                     @ViewBuilder action: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(ArenaTheme.accentBright)
                .frame(width: 22, height: 22)
                .background(Circle().fill(ArenaTheme.accent.opacity(0.12)))
            Text(title)
                .font(ArenaType.headline)
                .foregroundStyle(ArenaTheme.textPrimary)
            Text(body)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            action()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .arenaCard(radius: 14, fill: ArenaTheme.cardRaised)
    }

    // MARK: Challenge picker

    private var challengePicker: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("选择题目").font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                    Text("已安装或正在运行的环境").font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
                Spacer()
                Button("关闭") { showPicker = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(ArenaTheme.textSecondary)
            }
            .padding(18)
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
                    .foregroundStyle(ArenaTheme.textTertiary)
                TextField("搜索环境…", text: $pickerSearch)
                    .textFieldStyle(.plain)
                    .font(ArenaType.body)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredPickerLabs) { lab in
                        Button {
                            app.workspaceLabID = lab.id
                            showPicker = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: (app.category(lab.category)?.symbol) ?? "shippingbox")
                                    .font(.system(size: 11))
                                    .foregroundStyle(app.categoryColor(lab.category))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(lab.name).font(ArenaType.headline)
                                        .foregroundStyle(ArenaTheme.textPrimary)
                                    Text(lab.subtitle).font(ArenaType.caption)
                                        .foregroundStyle(ArenaTheme.textTertiary).lineLimit(1)
                                }
                                Spacer()
                                if lab.running {
                                    Text("运行中").font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(ArenaTheme.success)
                                } else if lab.installed {
                                    Text("已安装").font(.system(size: 9))
                                        .foregroundStyle(ArenaTheme.textQuaternary)
                                }
                                if lab.id == app.workspaceLabID {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(ArenaTheme.accentBright)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle(scale: 0.995))
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 560, height: 560)
        .background(ArenaTheme.background)
    }

    private var filteredPickerLabs: [Lab] {
        let base = app.labs.filter { $0.installed }
        let needle = pickerSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return base.sorted { $0.running && !$1.running } }
        return base.filter {
            $0.name.lowercased().contains(needle) || $0.subtitle.lowercased().contains(needle)
        }
    }
}

// MARK: - Embedded web view

struct WebPreview: NSViewRepresentable {
    var url: URL

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if view.url != url {
            view.load(URLRequest(url: url))
        }
    }
}
