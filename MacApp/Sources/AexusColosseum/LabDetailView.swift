import SwiftUI
import AppKit

struct LabDetailView: View {
    @EnvironmentObject private var app: AppState
    var lab: Lab

    @State private var logs: String?
    @State private var loadingLogs = false

    private var current: Lab { app.labs.first(where: { $0.id == lab.id }) ?? lab }
    private var tint: Color { app.categoryColor(current.category) }
    private var category: CatalogCategory? { app.category(current.category) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            overviewCard
                            objectivesCard
                            accessCard
                            logsCard
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            stateCard
                            resourceCard
                            if !current.credentials.isEmpty { credentialsCard }
                            if !current.mitre.isEmpty { mitreCard }
                            sourceCard
                            dangerCard
                        }
                        .frame(width: 292)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: 1280, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .task(id: current.id) {
            logs = nil
            if current.running { await loadLogs() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if let category {
                    Image(systemName: category.symbol)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(category.name)
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
                Text("/")
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textQuaternary)
                Text(current.name)
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            AppleOpenPill(title: "选作斗兽场靶标", active: true) {
                app.selectMapForPit(current)
            }

            Chip(text: current.sourceLabel, color: tint)

            if current.installed {
                Button {
                    app.requestRemove([current.id])
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArenaTheme.textTertiary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.92))
                .help("从磁盘删除")
            }

            RoundIconButton(systemImage: "arrow.clockwise", help: "刷新") {
                Task { await app.refresh() }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
    }

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.06)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tint.opacity(0.32), lineWidth: 1)
                Image(systemName: category?.symbol ?? "shippingbox.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    Text(current.name)
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                    if current.running {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2.5)
                            .background(Capsule().fill(ArenaTheme.accent))
                    }
                }
                Text(current.subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(ArenaTheme.textSecondary)
                HStack(spacing: 8) {
                    DifficultyDots(level: current.difficulty,
                                   color: current.difficulty >= 3 ? ArenaTheme.accent : ArenaTheme.ember)
                    Text(difficultyLabel)
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                    Text("·").foregroundStyle(ArenaTheme.textQuaternary)
                    Text(current.ramLabel)
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                    Text("·").foregroundStyle(ArenaTheme.textQuaternary)
                    Text(String(format: "%g vCPU", current.cpu))
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
                if !current.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(current.tags.prefix(6), id: \.self) { tag in
                            Chip(text: tag, color: tint)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    if current.running {
                        if let access = current.webAccess {
                            GhostButton(title: "打开实验", systemImage: "safari") {
                                Task { await app.openOnMac(access, lab: current) }
                            }
                        }
                        AccentButton(title: "停止环境", systemImage: "stop.fill",
                                     busy: app.stoppingLabs.contains(current.id)) {
                            Task { await app.stop(current) }
                        }
                    } else if current.installed {
                        AccentButton(title: "启动环境", systemImage: "play.fill",
                                     busy: app.startingLabs.contains(current.id),
                                     enabled: app.serverReady) {
                            Task { await app.start(current) }
                        }
                    } else {
                        AccentButton(title: "下载到服务器", systemImage: "arrow.down.circle.fill",
                                     busy: app.installingLabs.contains(current.id),
                                     enabled: app.serverReady) {
                            Task { await app.install(current) }
                        }
                    }
                }
                Text(stateLine)
                    .font(ArenaType.caption)
                    .foregroundStyle(current.running ? ArenaTheme.accentBright : ArenaTheme.textTertiary)
            }
            .padding(.top, 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.10), ArenaTheme.card.opacity(0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var difficultyLabel: String {
        switch current.difficulty {
        case 1: return "入门"
        case 2: return "进阶"
        case 3: return "困难"
        default: return "专家"
        }
    }

    private var stateLine: String {
        if current.running {
            return current.memHuman.isEmpty ? "环境正在占用内存" : "当前占用 \(current.memHuman)"
        }
        if current.installed { return "已落盘 · 启动后才占用内存" }
        return "尚未下载 · 仅存在于来源目录"
    }

    // MARK: Main column

    private var overviewCard: some View {
        DetailCard(title: "概述", symbol: "text.alignleft") {
            Text(current.summary)
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(ArenaTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !current.notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10.5))
                        .foregroundStyle(tint.opacity(0.9))
                        .padding(.top, 1)
                    Text(current.notes)
                        .font(ArenaType.callout)
                        .foregroundStyle(ArenaTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }

    private var objectivesCard: some View {
        DetailCard(title: "实验目标", symbol: "target") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(current.objectives.enumerated()), id: \.offset) { index, objective in
                    HStack(alignment: .top, spacing: 9) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(tint)
                            .padding(.top, 2)
                        Text(objective)
                            .font(ArenaType.body)
                            .foregroundStyle(ArenaTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if current.objectives.isEmpty {
                    Text("暂无预设目标。")
                        .font(ArenaType.callout)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
            }
        }
    }

    private var accessCard: some View {
        DetailCard(title: "访问方式", symbol: "link") {
            if current.access.isEmpty {
                Text("该环境没有暴露端口。通过服务器终端或容器网络访问。")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            } else {
                VStack(spacing: 10) {
                    ForEach(current.access) { entry in
                        LabAccessRow(access: entry, target: app.labHost(current), running: current.running,
                                     tunnel: app.connections.tunnel(target: app.labHost(current), port: entry.port))
                    }
                }
                Text("Web 页面可在 Mac 浏览器中打开。数据库等 TCP 服务需使用对应客户端；全部通过现有 SSH 通道接入。")
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textTertiary)
                if !current.running {
                    Text("环境启动后，以上地址才可访问。")
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textQuaternary)
                        .padding(.top, 1)
                }
            }
        }
    }

    private var logsCard: some View {
        DetailCard(title: "运行日志", symbol: "terminal") {
            if !current.running && logs == nil {
                Text("环境未运行。启动后可在这里查看容器日志。")
                    .font(ArenaType.callout)
                    .foregroundStyle(ArenaTheme.textTertiary)
            } else if loadingLogs && logs == nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                    Text("正在读取日志…")
                        .font(ArenaType.callout)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
            } else {
                ScrollView {
                    Text(logs?.isEmpty == false ? logs! : "暂无日志输出。")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ArenaTheme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 190)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(ArenaTheme.codeBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(ArenaTheme.tint(0.06), lineWidth: 0.8)
                )
                HStack(spacing: 8) {
                    GhostButton(title: "刷新日志", systemImage: "arrow.clockwise", busy: loadingLogs) {
                        Task { await loadLogs() }
                    }
                    Spacer()
                    CopyChip(text: logs ?? "", label: "复制全部")
                }
            }
        }
    }

    // MARK: Side column

    private var stateCard: some View {
        DetailCard(title: "状态", symbol: "gauge.with.dots.needle.33percent") {
            HStack(spacing: 8) {
                StatusDot(color: stateColor, pulsing: current.running)
                Text(stateTitle)
                    .font(ArenaType.headline)
                    .foregroundStyle(ArenaTheme.textPrimary)
                Spacer()
                Text(stateBadgeText)
                    .font(ArenaType.micro)
                    .foregroundStyle(stateColor)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(stateColor.opacity(0.12)))
            }
            if current.running && !current.containers.isEmpty {
                VStack(spacing: 5) {
                    ForEach(current.containers) { container in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(container.isRunning ? ArenaTheme.success : ArenaTheme.textQuaternary)
                                .frame(width: 5, height: 5)
                            Text(container.name)
                                .font(ArenaType.mono)
                                .foregroundStyle(ArenaTheme.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(container.state)
                                .font(ArenaType.caption)
                                .foregroundStyle(ArenaTheme.textQuaternary)
                        }
                    }
                }
                .padding(.top, 2)
            }
            if current.running {
                HStack {
                    Text("内存")
                    Spacer()
                    Text(current.memHuman.isEmpty ? "—" : current.memHuman)
                        .foregroundStyle(ArenaTheme.accentBright)
                }
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
            }
        }
    }

    private var stateColor: Color {
        if current.running { return ArenaTheme.success }
        if current.installed { return ArenaTheme.ember }
        return ArenaTheme.textTertiary
    }

    private var stateTitle: String {
        if current.running { return "运行中" }
        if current.installed { return "已安装" }
        return "未下载"
    }

    private var stateBadgeText: String {
        if current.running { return "占用中" }
        if current.installed { return "硬盘" }
        return "来源"
    }

    private var resourceCard: some View {
        DetailCard(title: "资源", symbol: "cube") {
            VStack(spacing: 7) {
                infoRow("内存上限", current.ramLabel)
                infoRow("CPU", String(format: "%g vCPU", current.cpu))
                infoRow("运行方式", current.build ? "本地构建镜像" : "预构建镜像")
                infoRow("编排文件", current.compose)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
            Spacer()
            Text(value)
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var credentialsCard: some View {
        DetailCard(title: "凭据", symbol: "key.fill") {
            HStack(alignment: .top, spacing: 7) {
                Text(current.credentials)
                    .font(ArenaType.body)
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                CopyChip(text: current.credentials, label: "复制")
            }
        }
    }

    private var mitreCard: some View {
        DetailCard(title: "MITRE ATT&CK", symbol: "shield.lefthalf.filled") {
            FlowChips(items: current.mitre, color: tint)
        }
    }

    private var sourceCard: some View {
        DetailCard(title: "来源", symbol: "tray.full") {
            VStack(alignment: .leading, spacing: 6) {
                infoRow("来源", current.sourceLabel)
                if let path = current.sourceDetail {
                    HStack {
                        Text("路径")
                            .font(ArenaType.caption)
                            .foregroundStyle(ArenaTheme.textTertiary)
                        Spacer()
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(ArenaTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if let url = current.sourceURL, let link = URL(string: url) {
                    Button {
                        NSWorkspace.shared.open(link)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 9))
                            Text("打开上游仓库")
                                .font(ArenaType.caption)
                        }
                        .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                }
                Text(current.installed
                     ? "删除后仍可从此来源重新下载。"
                     : "尚未下载。点击上方按钮即可拉取到服务器。")
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textQuaternary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dangerCard: some View {
        DetailCard(title: "管理", symbol: "slider.horizontal.3") {
            VStack(spacing: 8) {
                if current.installed {
                    GhostButton(title: "从磁盘删除", systemImage: "trash", tint: ArenaTheme.danger,
                                wide: true) {
                        app.requestRemove([current.id])
                    }
                    Text("会删除环境目录、数据卷与镜像，Arena 虚拟机不受影响。")
                        .font(ArenaType.caption)
                        .foregroundStyle(ArenaTheme.textQuaternary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    GhostButton(title: "下载到服务器", systemImage: "arrow.down.circle",
                                tint: ArenaTheme.textSecondary,
                                busy: app.installingLabs.contains(current.id),
                                enabled: app.serverReady, wide: true) {
                        Task { await app.install(current) }
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func loadLogs() async {
        loadingLogs = true
        defer { loadingLogs = false }
        do {
            logs = try await ArenaAPI.logs(current.id)
        } catch {
            if logs == nil { logs = "无法读取日志：\(error.localizedDescription)" }
        }
    }
}

// MARK: - Shells

private struct DetailCard<Content: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textTertiary)
                Text(title)
                    .font(ArenaType.micro)
                    .tracking(0.8)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .arenaCard(radius: 15)
    }
}

private struct FlowChips: View {
    var items: [String]
    var color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 5)],
                  alignment: .leading, spacing: 5) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(color.opacity(0.09))
                    )
            }
        }
    }
}
