import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                nav
                    .frame(width: 188)
                    .padding(.top, 18)
                Rectangle().fill(ArenaTheme.hairline).frame(width: 1)
                    .padding(.vertical, 16)
                ScrollView(showsIndicators: false) {
                    Group {
                        switch app.settingsTab {
                        case .connection: ConnectionSettings()
                        case .environments: EnvironmentSettings()
                        case .sources: SourceSettings()
                        case .about: AboutSettings()
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 980, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("设置")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text("管理服务器、环境与下载来源")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer()
            if app.serverReady {
                HStack(spacing: 5) {
                    StatusDot(color: ArenaTheme.success, pulsing: true)
                    Text("Arena 在线")
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textSecondary)
                }
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(ArenaTheme.tint(0.04)))
            }
            RoundIconButton(systemImage: "xmark", help: "关闭设置") {
                withAnimation(Motion.page) { app.settingsOpen = false }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var nav: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                settingsTabButton(tab)
            }
        }
        .padding(.horizontal, 12)
    }

    private func settingsTabButton(_ tab: SettingsTab) -> some View {
        let selected = app.settingsTab == tab
        return Button {
            withAnimation(Motion.page) { app.settingsTab = tab }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(selected ? ArenaTheme.accentBright : ArenaTheme.textTertiary)
                    .frame(width: 16)
                Text(tab.label)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? ArenaTheme.textPrimary : ArenaTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? ArenaTheme.tint(0.07) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Connection

private struct ConnectionSettings: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "The Pit · 统一 pitd 控制面与自动 SSH 桥接",
                            caption: "客户端通过 HTTP + WebSocket 直连 pitd；若本机 18880 未监听，自动通过 SSH 端口转发桥接远程 Linux 内核 eBPF 赛场") {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 10) {
                        Text("pitd 接口地址")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .frame(width: 90, alignment: .leading)
                        TextField("http://127.0.0.1:18880", text: Binding(
                            get: { app.pit.baseURLString },
                            set: { app.pit.baseURLString = $0; app.pit.saveEndpointSettings() }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(ArenaType.mono)
                        Chip(text: app.pit.connectionState.statusLabel,
                             color: app.pit.connectionState.isLiveBackend ? ArenaTheme.ecgEmerald : ArenaTheme.patchCyan)
                    }
                    HStack(spacing: 10) {
                        Text("SSH 桥接别名")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .frame(width: 90, alignment: .leading)
                        TextField("留空默认复用 Arena 跳板配置 (或填 arena)", text: Binding(
                            get: { app.pit.sshHostAlias },
                            set: { app.pit.sshHostAlias = $0; app.pit.saveEndpointSettings() }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(ArenaType.mono)
                        Toggle("自动 SSH 端口转发 (-L 18880)", isOn: Binding(
                            get: { app.pit.autoBridgeEnabled },
                            set: { app.pit.autoBridgeEnabled = $0; app.pit.saveEndpointSettings() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(ArenaType.caption)
                    }
                    HStack(spacing: 8) {
                        AccentButton(title: "重连 / 自动桥接 pitd", systemImage: "bolt.horizontal.fill") {
                            Task { await app.pit.connectOrShowcase(attemptSSHBridge: app.pit.autoBridgeEnabled) }
                        }
                        GhostButton(title: "断开当前连接", systemImage: "xmark.circle") {
                            app.pit.disconnectBackend()
                        }
                    }
                }
                .padding(16)
                .arenaCard(radius: 15)
            }

            SettingsSection(title: "Arena 虚拟机", caption: "实验环境运行在 bupt208 上的独立虚拟机中") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 13) {
                        SquircleIconTile(
                            symbol: "server.rack",
                            colors: [ArenaTheme.appleBlue, ArenaTheme.appleBlueDeep],
                            size: 52
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 7) {
                                Text("Arena")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ArenaTheme.textPrimary)
                                StatePill(ready: app.serverReady, running: app.serverRunning)
                            }
                            Text(vmSpecLine)
                                .font(ArenaType.callout)
                                .foregroundStyle(ArenaTheme.textTertiary)
                        }
                        Spacer()
                        if app.serverReady {
                            GhostButton(title: "关闭服务器", systemImage: "power",
                                        tint: ArenaTheme.textSecondary, busy: app.vmBusy) {
                                app.confirmStopVM = true
                            }
                        } else {
                            AccentButton(title: "启动 Arena", systemImage: "power",
                                         busy: app.vmBusy) {
                                Task { await app.startServer() }
                            }
                        }
                    }

                    if app.serverReady, let host = app.host {
                        Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
                        HStack(spacing: 26) {
                            metric("内存", value: memoryLine(host), fraction: app.vmMemoryUsedFraction)
                            metric("数据盘", value: diskLine(host), fraction: app.vmDiskUsedFraction)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("引擎")
                                    .font(ArenaType.caption)
                                    .foregroundStyle(ArenaTheme.textTertiary)
                                Text("Docker \(host.docker ?? "—")")
                                    .font(ArenaType.body)
                                    .foregroundStyle(ArenaTheme.textSecondary)
                                Text("\(host.installedLabs ?? 0) 个环境已安装")
                                    .font(ArenaType.caption)
                                    .foregroundStyle(ArenaTheme.textQuaternary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("虚拟机当前未运行。启动后会挂载 3 TB 数据盘，所有实验只在启动时占用内存。")
                            .font(ArenaType.callout)
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .arenaCard(radius: 15)
            }

            SettingsSection(title: "连接方式", caption: "Mac 通过 SSH 控制服务器，不直接暴露任何端口") {
                VStack(spacing: 0) {
                    connectionRow("主机", "bupt208 · 127.0.0.1:22004", symbol: "network")
                    Rectangle().fill(ArenaTheme.hairline).frame(height: 1).padding(.leading, 34)
                    connectionRow("跳板", "ProxyJump bupt208 · ed25519", symbol: "arrow.triangle.branch")
                    Rectangle().fill(ArenaTheme.hairline).frame(height: 1).padding(.leading, 34)
                    connectionRow("目录", "/srv/arena · catalog / labs / shared / logs", symbol: "folder")
                    Rectangle().fill(ArenaTheme.hairline).frame(height: 1).padding(.leading, 34)
                    connectionRow("代理隧道", "guest 17890 → host 17890（镜像拉取）", symbol: "link")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .arenaCard(radius: 15)

                HStack(spacing: 8) {
                    GhostButton(title: "测试连接", systemImage: "bolt.horizontal",
                                busy: app.loading) {
                        Task { await app.connect() }
                    }
                    GhostButton(title: "刷新状态", systemImage: "arrow.clockwise") {
                        Task { await app.refresh() }
                    }
                    if let date = app.lastRefresh {
                        Text("上次刷新 \(date.formatted(date: .omitted, time: .standard))")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textQuaternary)
                    }
                }
                .padding(.top, 4)
            }
            SettingsSection(title: "Arena-Kali · 独立攻击主机", caption: "实验命令在完整 Kali Linux 虚拟机中执行，靶场服务由 Arena 靶机承载。") {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("8 vCPU · 16 GB 内存 · 256 GB 系统盘").font(ArenaType.body)
                        Text("训练网：Kali 10.77.90.20 → Arena 10.77.90.10")
                            .font(ArenaType.mono).foregroundStyle(ArenaTheme.textSecondary)
                        Text("CTF 资料：/shared/library · 只读共享")
                            .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                    }
                    Spacer()
                    StatePill(ready: app.kaliVM?.ready == true, running: app.kaliVM?.running == true)
                    GhostButton(title: "启动 Kali", systemImage: "power", busy: app.platformLoading) {
                        Task { await app.deployAttackHost() }
                    }
                }.padding(16).arenaCard(radius: 15)
            }
        }
    }

    private var vmSpecLine: String {
        let cpu = app.vm?.cpu ?? 16
        let ram = app.vm?.ramGB ?? 64
        let disk = app.vm?.diskSummary ?? "5 TB"
        return "\(cpu) vCPU · \(ram) GB 内存 · \(disk) 存储 · Ubuntu"
    }

    private func memoryLine(_ host: ArenaHostInfo) -> String {
        guard let total = host.memTotal else { return "—" }
        let used = total - (host.memAvailable ?? 0)
        return "\(ByteCountFormatter.string(fromByteCount: used, countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .memory))"
    }

    private func diskLine(_ host: ArenaHostInfo) -> String {
        guard let total = host.diskTotal else { return "—" }
        let used = host.diskUsed ?? 0
        return "\(ByteCountFormatter.string(fromByteCount: used, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
    }

    private func metric(_ label: String, value: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
            Text(value)
                .font(ArenaType.body)
                .foregroundStyle(ArenaTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Meter(fraction: fraction, tint: ArenaTheme.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func connectionRow(_ label: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(ArenaTheme.textTertiary)
                .frame(width: 16)
            Text(label)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ArenaTheme.textSecondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }
}

// MARK: - Environments

private struct EnvironmentSettings: View {
    @EnvironmentObject private var app: AppState
    @State private var query = ""
    @State private var confirmIndividual: String?

    private var installed: [Lab] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = app.installedLabs.sorted { a, b in
            if a.running != b.running { return a.running && !b.running }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        guard !needle.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(needle) ||
            $0.subtitle.lowercased().contains(needle) ||
            $0.category.lowercased().contains(needle)
        }
    }

    private var allSelected: Bool {
        !installed.isEmpty && installed.allSatisfy { app.deleteSelection.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "已安装环境",
                            caption: "删除会把环境从磁盘上移除；之后可从来源一键重新下载") {
                HStack(spacing: 10) {
                    searchField
                    Spacer()
                    Text("\(app.installedLabs.count) 个 · \(app.installedMemoryFootprint)")
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }

                if installed.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        selectBar
                        Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
                        ForEach(installed) { lab in
                            environmentRow(lab)
                            if lab.id != installed.last?.id {
                                Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .arenaCard(radius: 15)
                }

                HStack(spacing: 9) {
                    GhostButton(title: "删除所选", systemImage: "trash", tint: ArenaTheme.danger,
                                enabled: !app.deleteSelection.isEmpty) {
                        app.requestRemove(Array(app.deleteSelection))
                    }
                    if !app.deleteSelection.isEmpty {
                        Text("已选择 \(app.deleteSelection.count) 个环境")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                    }
                    Spacer()
                    GhostButton(title: "停止全部运行", systemImage: "stop.fill",
                                tint: ArenaTheme.textTertiary,
                                enabled: !app.runningLabs.isEmpty) {
                        Task { await app.stopEverything() }
                    }
                }
            }

            SettingsSection(title: "存储", caption: "题库与资料位于数据盘；Docker 的镜像内容存储也会占用系统盘。") {
                HStack(spacing: 26) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("已用空间")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                        Text(diskUsedText)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Text(diskFreeText)
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textQuaternary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("数据盘占用")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                        Meter(fraction: app.vmDiskUsedFraction, tint: ArenaTheme.gold)
                        Text(String(format: "%.1f%%", app.vmDiskUsedFraction * 100))
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textQuaternary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .arenaCard(radius: 15)
            }
            if let total = app.host?.systemDiskTotal, let used = app.host?.systemDiskUsed {
                SettingsSection(title: "系统与镜像盘", caption: "包含系统、容器镜像和构建缓存，不计入上方资料数据盘。") {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("\(ByteCountFormatter.string(fromByteCount: used, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                            .font(ArenaType.body)
                        Meter(fraction: Double(used) / Double(max(total, 1)), tint: ArenaTheme.gold)
                    }.padding(16).arenaCard(radius: 15)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(ArenaTheme.textTertiary)
            TextField("筛选已安装环境", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(ArenaTheme.textPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(width: 210)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(ArenaTheme.tint(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.08), lineWidth: 0.8))
    }

    private var selectBar: some View {
        HStack(spacing: 9) {
            CheckBox(on: allSelected) {
                if allSelected {
                    app.deleteSelection.removeAll()
                } else {
                    app.deleteSelection = Set(installed.map(\.id))
                }
            }
            Text("全选")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textSecondary)
            Spacer()
            Text("选择多个环境后可一次从磁盘删除")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textQuaternary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
    }

    private func environmentRow(_ lab: Lab) -> some View {
        let selected = app.deleteSelection.contains(lab.id)
        return HStack(spacing: 11) {
            CheckBox(on: selected) {
                if selected { app.deleteSelection.remove(lab.id) }
                else { app.deleteSelection.insert(lab.id) }
            }
            LabGlyph(lab: lab, color: app.categoryColor(lab.category), size: 27)
            VStack(alignment: .leading, spacing: 2) {
                Text(lab.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .lineLimit(1)
                Text(lab.sourceLabel + (lab.sourceDetail.map { " · \($0)" } ?? ""))
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textQuaternary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            HStack(spacing: 5) {
                StatusDot(color: lab.running ? ArenaTheme.success : ArenaTheme.textQuaternary,
                          pulsing: lab.running)
                Text(lab.running ? (lab.memHuman.isEmpty ? "运行中" : "运行中 · \(lab.memHuman)") : "已停止")
                    .font(ArenaType.caption)
                    .foregroundStyle(lab.running ? ArenaTheme.success : ArenaTheme.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
            Text(lab.ramLabel)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
                .frame(width: 58, alignment: .trailing)
            Spacer(minLength: 4)
            if app.removingLabs.contains(lab.id) {
                ProgressView().controlSize(.small).scaleEffect(0.65).frame(width: 22)
            } else {
                RoundIconButton(systemImage: lab.running ? "stop.fill" : "trash",
                                tint: lab.running ? ArenaTheme.textTertiary : ArenaTheme.textTertiary,
                                help: lab.running ? "停止环境" : "从磁盘删除") {
                    if lab.running {
                        Task { await app.stop(lab) }
                    } else {
                        app.requestRemove([lab.id])
                    }
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(selected ? ArenaTheme.tint(0.035) : .clear)
        .contentShape(Rectangle())
        .pointerCursor()
        .onTapGesture {
            if selected { app.deleteSelection.remove(lab.id) }
            else { app.deleteSelection.insert(lab.id) }
        }
    }

    private var diskUsedText: String {
        guard let host = app.host, let used = host.diskUsed else { return "—" }
        return ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    }

    private var diskFreeText: String {
        guard let host = app.host, let free = host.diskFree else { return "Arena 未运行" }
        return "剩余 \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(ArenaTheme.textQuaternary)
            Text(query.isEmpty ? "还没有安装任何环境" : "没有匹配的环境")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ArenaTheme.textSecondary)
            if query.isEmpty {
                GhostButton(title: "浏览可下载环境", systemImage: "icloud.and.arrow.down") {
                    app.scope = .available
                    app.settingsOpen = false
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .arenaCard(radius: 15, fill: ArenaTheme.card.opacity(0.5))
    }
}

// MARK: - Sources

private struct SourceSettings: View {
    @EnvironmentObject private var app: AppState

    private var curated: [Lab] { app.labs.filter { $0.source == "curated" } }
    private var vulhub: [Lab] { app.labs.filter { $0.source == "vulhub" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "下载来源",
                            caption: "所有环境都需要先下载到 Arena 的磁盘，启动时才占用内存") {
                VStack(spacing: 12) {
                    sourceCard(
                        name: "Aexus 精选",
                        detail: "自建的高价值靶场，包含综合 Web、红队基础设施、取证与 AI 安全。",
                        symbol: "seal.fill",
                        tint: ArenaTheme.accent,
                        labs: curated,
                        origin: "catalog/labs · 本地目录"
                    )
                    sourceCard(
                        name: "Vulhub",
                        detail: "官方 CVE 复现集合，覆盖 Java、中间件与近年高危漏洞链。",
                        symbol: "ant.fill",
                        tint: Color(hex: "8B5CF6"),
                        labs: vulhub,
                        origin: "github.com/vulhub/vulhub"
                    )
                }
            }

            SettingsSection(title: "更新与同步", caption: "目录变更后重新部署即可在客户端看到新环境") {
                HStack(spacing: 9) {
                    GhostButton(title: "刷新目录", systemImage: "arrow.clockwise", busy: app.loading) {
                        Task { await app.refresh() }
                    }
                    GhostButton(title: "查看可下载", systemImage: "icloud.and.arrow.down") {
                        app.scope = .available
                        app.settingsOpen = false
                    }
                    GhostButton(title: "一键下载全部缺失",
                                systemImage: "arrow.down.circle.fill",
                                busy: !app.installingLabs.isEmpty,
                                enabled: !app.availableLabs.isEmpty && app.serverReady) {
                        Task { await app.installAllMissing() }
                    }
                    Spacer()
                    Text(app.catalogDate.map { "目录更新于 \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "使用内置目录")
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textQuaternary)
                }
                Text("来源目录保存在服务器的 /srv/arena/catalog；下载后的副本位于 /srv/arena/labs。删除副本不会影响来源，可随时重新下载。")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            SettingsSection(title: "重新下载", caption: "已删除的环境会回到「可下载」列表") {
                HStack(spacing: 9) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArenaTheme.textTertiary)
                    Text("在环境详情页点击「下载到服务器」即可重新安装。下载会拉取镜像；若镜像已在本地缓存，会非常快。")
                        .font(ArenaType.callout)
                        .foregroundStyle(ArenaTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .arenaCard(radius: 15, fill: ArenaTheme.card.opacity(0.55))
            }
            SettingsSection(title: "离线 CTF 与教学资料", caption: "源码、题目附件和原始文档已存入 Arena；各题运行方法以项目 README 为准。") {
                ForEach(app.trainingCollections) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name).font(ArenaType.headline)
                            Spacer()
                            Chip(text: item.status == "downloaded" ? "已下载" : "下载失败",
                                 color: item.status == "downloaded" ? ArenaTheme.success : ArenaTheme.danger)
                        }
                        Text("\(item.authority) · \(item.description)")
                            .font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary)
                        Text("\(String(item.files ?? 0)) 个文件 · \(ByteCountFormatter.string(fromByteCount: item.bytes ?? 0, countStyle: .file))")
                            .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                        Text(item.attackboxPath).font(ArenaType.mono).textSelection(.enabled)
                        HStack {
                            CopyChip(text: item.attackboxPath, label: "复制 Kali 路径")
                            if let url = URL(string: item.url) { Link("原始项目", destination: url).font(ArenaType.caption) }
                        }
                    }.padding(14).arenaCard(radius: 12)
                }
                if app.trainingCollections.isEmpty {
                    Text("连接服务器后可读取资料清单。").font(ArenaType.callout).foregroundStyle(ArenaTheme.textTertiary)
                }
            }
        }
        .task { await app.loadTrainingLibrary() }
    }

    private func sourceCard(name: String, detail: String, symbol: String, tint: Color,
                            labs: [Lab], origin: String) -> some View {
        let installedCount = labs.filter(\.installed).count
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                    Text(origin)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ArenaTheme.textQuaternary)
                }
                Spacer()
                Text("\(labs.count) 个环境")
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            Text(detail)
                .font(ArenaType.body)
                .foregroundStyle(ArenaTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Chip(text: "\(installedCount) 已安装", color: tint)
                Chip(text: "\(labs.count - installedCount) 可下载", color: ArenaTheme.textTertiary)
                Spacer()
                GhostButton(title: "浏览", systemImage: "arrow.right") {
                    app.sourceFilter = labs.first?.source == "vulhub" ? .vulhub : .curated
                    app.scope = .all
                    app.settingsOpen = false
                }
            }
        }
        .padding(15)
        .arenaCard(radius: 15)
    }
}

// MARK: - About

private struct AboutSettings: View {
    @AppStorage(AppearanceSettings.key) private var appearance = AppearanceSettings.defaultValue

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 13) {
                ArenaMark(size: 74)
                Text("Aexus Colosseum")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text("版本 1.0 · macOS 指挥中心")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
                Text("为授权的安全训练与攻防演练而构建。所有实验环境运行在 bupt208 的 Arena 虚拟机中，仅在需要时启动。")
                    .font(ArenaType.body)
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .arenaCard(radius: 18)

            SettingsSection(title: "外观", caption: "默认采用纯正 Apple 浅色玻璃材质风格，支持 ⌘+ / ⌘- 自由调整界面大小。") {
                HStack(spacing: 12) {
                    Text("界面主题")
                        .font(ArenaType.body)
                        .foregroundStyle(ArenaTheme.textSecondary)
                    Spacer()
                    Picker("界面主题", selection: $appearance) {
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                        Text("跟随系统").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 248)
                    .onChange(of: appearance) { _, value in
                        AppearanceSettings.apply(value)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .arenaCard(radius: 15)
            }

            SettingsSection(title: "四种模式", caption: "各司其职，互不耦合") {
                VStack(spacing: 0) {
                    modeGuide("bolt.shield.fill", "训练场",
                              "下载并启动按需漏洞环境，一次只跑一个，用完即停。")
                    divider
                    modeGuide("terminal.fill", "解题台",
                              "命令从攻击机发出，靶场网页内嵌在应用里，题目与目标一目了然。")
                    divider
                    modeGuide("flag.2.crossed.fill", "攻防赛事",
                              "编排多支队伍与多台主机，只做观察与调控，不代替你进攻。")
                    divider
                    modeGuide("server.rack", "主机与拓扑",
                              "绑定训练机、靶机与攻击机，一键探测连通性，确认环境真实可用。")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .arenaCard(radius: 15)
            }

            SettingsSection(title: "架构", caption: nil) {
                VStack(spacing: 0) {
                    aboutRow("客户端", "macOS SwiftUI · Aexus Colosseum")
                    divider
                    aboutRow("控制通道", "SSH · bupt208 跳板 · ed25519")
                    divider
                    aboutRow("服务器", "Arena VM · 16 vCPU / 64 GB / 5 TB")
                    divider
                    aboutRow("运行时", "Docker Compose · /srv/arena")
                    divider
                    aboutRow("安全边界", "仅允许授权测试；环境之间独立编排")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .arenaCard(radius: 15)
            }

            Text("Authorized security training only. © 2026 Aexus.")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textQuaternary)
                .padding(.top, 2)
        }
        .frame(maxWidth: 720)
    }

    private var divider: some View {
        Rectangle().fill(ArenaTheme.hairline).frame(height: 1).padding(.leading, 8)
    }

    private func modeGuide(_ symbol: String, _ title: String, _ blurb: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArenaTheme.accentBright)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ArenaTheme.accent.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ArenaType.headline)
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text(blurb)
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(ArenaType.body)
                .foregroundStyle(ArenaTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

// MARK: - Shared

private struct SettingsSection<Content: View>: View {
    var title: String
    var caption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                if let caption {
                    Text(caption)
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

private struct StatePill: View {
    var ready: Bool
    var running: Bool

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(color: ready ? ArenaTheme.success : (running ? ArenaTheme.warning : ArenaTheme.textQuaternary),
                      pulsing: ready)
            Text(ready ? "在线" : (running ? "启动中" : "离线"))
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(ArenaTheme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(ArenaTheme.tint(0.05)))
    }
}

private struct CheckBox: View {
    var on: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(on ? ArenaTheme.accent : ArenaTheme.tint(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .strokeBorder(on ? ArenaTheme.accentBright.opacity(0.6) : ArenaTheme.tint(0.15),
                                      lineWidth: 1)
                )
                .overlay {
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7.5, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 15, height: 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.9))
    }
}
