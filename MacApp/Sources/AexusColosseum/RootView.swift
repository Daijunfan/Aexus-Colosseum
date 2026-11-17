import SwiftUI
import AppKit

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        GeometryReader { outer in
            let scale = max(0.75, min(1.50, app.uiScale))
            ZStack(alignment: .bottom) {
                ArenaBackground()

                HStack(spacing: 0) {
                    if !(app.mode == .pitLive && app.hudSidebarCollapsed && !app.settingsOpen) {
                        SidebarView()
                            .frame(width: 312)

                        Rectangle()
                            .fill(Color.black.opacity(0.065))
                            .frame(width: 1)
                    }

                    VStack(spacing: 0) {
                        AppleTopBar()

                        Rectangle()
                            .fill(Color.black.opacity(0.055))
                            .frame(height: 1)

                        ZStack {
                            content
                                .id(contentIdentity)
                                .transition(.opacity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(Motion.page, value: contentIdentity)
                        .clipped()
                    }
                }
                .ignoresSafeArea(.container, edges: .top)

                if let banner = app.banner {
                    BannerView(banner: banner)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(20)
                }
            }
            .frame(width: outer.size.width / scale, height: outer.size.height / scale)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: outer.size.width, height: outer.size.height, alignment: .topLeading)
        }
        .background(
            WindowConfigurator(
                onZoomIn: { app.zoomIn() },
                onZoomOut: { app.zoomOut() },
                onZoomReset: { app.resetZoom() }
            )
        )
        .frame(minWidth: 1200, minHeight: 780)
        .animation(Motion.banner, value: app.banner)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            app.connections.closeAll()
            app.pit.stopSSHTunnel()
        }
        .onExitCommand {
            if app.settingsOpen {
                app.settingsOpen = false
            } else if app.selectedLabID != nil {
                app.selectedLabID = nil
            } else if app.mode == .pitLive && app.pit.visorOpen {
                app.pit.visorOpen = false
            }
        }
        .alert("操作未完成", isPresented: errorBinding) {
            Button("知道了", role: .cancel) { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "")
        }
        .confirmationDialog(removeTitle, isPresented: removeBinding, titleVisibility: .visible) {
            Button("从磁盘删除", role: .destructive) {
                let ids = app.confirmRemoveIDs
                app.confirmRemoveIDs = []
                Task { await app.remove(ids) }
            }
            Button("取消", role: .cancel) { app.confirmRemoveIDs = [] }
        } message: {
            Text("环境目录、容器数据卷与镜像都会被删除。之后可以从来源一键重新下载。")
        }
        .alert("关闭 Arena 服务器？", isPresented: $app.confirmStopVM) {
            Button("关闭", role: .destructive) {
                Task { await app.stopServer() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("正在运行的实验会全部停止，虚拟机内存释放。磁盘上的环境与数据保持不变。")
        }
    }

    private var contentIdentity: String {
        if app.settingsOpen { return "settings" }
        if app.mode == .training, let lab = app.selectedLab { return "lab:\(lab.id)" }
        if app.mode == .training { return "training:\(app.armorySection):\(app.scope)" }
        if app.mode == .pitArena { return "pitArena:\(app.lobbySubSection)" }
        return app.mode.rawValue
    }

    @ViewBuilder
    private var content: some View {
        if app.settingsOpen {
            SettingsView()
        } else {
            switch app.mode {
            case .pitArena:
                PitLobbyView()
                    .environmentObject(app.pit)
            case .pitLive:
                PitBattleHUDView()
                    .environmentObject(app.pit)
            case .training:
                if let lab = app.selectedLab {
                    LabDetailView(lab: lab)
                } else {
                    LibraryView()
                        .environmentObject(app.pit)
                }
            case .workspace:
                WorkspaceView()
            case .events:
                EventsView()
            case .hosts:
                HostsView()
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { app.errorMessage != nil },
                set: { if !$0 { app.errorMessage = nil } })
    }

    private var removeBinding: Binding<Bool> {
        Binding(get: { !app.confirmRemoveIDs.isEmpty },
                set: { if !$0 { app.confirmRemoveIDs = [] } })
    }

    private var removeTitle: String {
        let count = app.confirmRemoveIDs.count
        let names = app.confirmRemoveIDs.prefix(3).compactMap { id in
            app.labs.first(where: { $0.id == id })?.name
        }
        let joined = names.joined(separator: "、")
        return count > 3 ? "删除 \(count) 个环境？" : "删除「\(joined)」？"
    }
}

// MARK: - Unified Frosted Apple TopBar (Aligned with Aexus Spear)

private struct AppleTopBar: View {
    @EnvironmentObject private var app: AppState

    private var canGoBack: Bool {
        app.settingsOpen || (app.mode == .training && app.selectedLab != nil)
    }

    private var pageTitle: String {
        if app.settingsOpen { return "设置与连接管理" }
        switch app.mode {
        case .pitArena:
            return app.lobbySubSection == "leaderboard" ? "天梯榜与战局录像" : "斗兽场对决编排"
        case .pitLive:
            return app.pit.match.isStandby ? "实况战场 · 待命就绪" : app.pit.match.title
        case .training:
            if let lab = app.selectedLab { return lab.name }
            if app.armorySection == "harnesses" { return "传奇渗透智能体 (Harnesses)" }
            return app.scopeTitle
        case .workspace:
            return "单兵调试终端"
        case .events:
            return "多队攻防赛事"
        case .hosts:
            return "主机与网络拓扑"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if app.mode == .pitLive && app.hudSidebarCollapsed && !app.settingsOpen {
                RoundIconButton(systemImage: "sidebar.left", size: 30, help: "展开侧边栏") {
                    withAnimation(Motion.page) { app.hudSidebarCollapsed = false }
                }
            }

            if canGoBack {
                RoundIconButton(systemImage: "chevron.left", size: 30, help: "返回") {
                    withAnimation(Motion.page) {
                        if app.settingsOpen {
                            app.settingsOpen = false
                        } else {
                            app.selectedLabID = nil
                        }
                    }
                }
            }

            Text(pageTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ArenaTheme.textPrimary)
                .lineLimit(1)

            // Truthful Kernel eBPF / Engine Pill
            HStack(spacing: 5) {
                Circle()
                    .fill(app.pit.connectionState.isLiveBackend ? ArenaTheme.success : ArenaTheme.warning)
                    .frame(width: 6, height: 6)
                Text(
                    app.pit.connectionState.isLiveBackend
                        ? (app.pit.health.perfStats.map {
                            String(format: "Linux eBPF 真机在线 · 直滤 %.1f%%", $0.kernelFilterPct)
                        } ?? "Linux eBPF 真机已连接")
                        : "未连接 pitd 后端"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArenaTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(Capsule().fill(Color.black.opacity(0.042)))

            Spacer(minLength: 12)

            if app.mode == .training && !app.settingsOpen && app.selectedLab == nil {
                AppleSearchField(
                    text: Binding(
                        get: { app.searchText },
                        set: { value in
                            app.searchText = value
                        }
                    ),
                    placeholder: "搜索 133 款靶标、CVE 或框架…",
                    width: 236
                )
            } else if app.mode == .pitArena && !app.settingsOpen {
                Button {
                    withAnimation(Motion.page) { app.mode = .pitLive }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("查看实况战场")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ArenaTheme.appleBlue)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(ArenaTheme.appleBlue.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(ArenaTheme.appleBlue.opacity(0.18), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle(scale: 0.96))
            } else if app.mode == .pitLive && !app.settingsOpen {
                Button {
                    withAnimation(Motion.page) {
                        app.lobbySubSection = "create"
                        app.mode = .pitArena
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("新建对决")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.white.opacity(0.88)))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle(scale: 0.96))
            }

            // Compact UI Zoom Control (`⌘-` / `⌘0` / `⌘+`)
            HStack(spacing: 2) {
                Button {
                    app.zoomOut()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ArenaTheme.textSecondary)
                        .frame(width: 24, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.92))
                .help("缩小界面 (⌘-)")

                Button {
                    app.resetZoom()
                } label: {
                    Text("\(Int((app.uiScale * 100).rounded()))%")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(abs(app.uiScale - 1.0) < 0.01 ? ArenaTheme.textTertiary : ArenaTheme.appleBlue)
                        .frame(minWidth: 38, minHeight: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.95))
                .help("恢复默认缩放 100% (⌘0)")

                Button {
                    app.zoomIn()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ArenaTheme.textSecondary)
                        .frame(width: 24, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.92))
                .help("放大界面 (⌘+)")
            }
            .padding(.horizontal, 4)
            .background(Capsule().fill(Color.white.opacity(0.76)))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.07), lineWidth: 1))

            RoundIconButton(systemImage: "gearshape", size: 31, help: "设置与连接 (⌘,)") {
                withAnimation(Motion.page) {
                    app.settingsOpen.toggle()
                    app.selectedLabID = nil
                }
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 56)
        .padding(.top, 6)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .light)
                Color.white.opacity(0.58)
            }
        )
    }
}

// MARK: - Floating Apple Toast Banner

private struct BannerView: View {
    var banner: ActivityBanner

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(banner.success ? ArenaTheme.success : ArenaTheme.danger)
            Text(banner.text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(ArenaTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9.5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.10), radius: 16, y: 6)
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
        )
    }
}
