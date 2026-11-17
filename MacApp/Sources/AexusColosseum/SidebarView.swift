import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedCategories: Set<String> = ["ai", "web"]
    @State private var engineHovering = false

    private var allExpanded: Bool {
        !app.categories.isEmpty && expandedCategories.count >= app.categories.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand

            arenaSection
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 16)

            armorySection
                .padding(.horizontal, 12)
                .padding(.bottom, 14)

            categoriesHeader
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(app.categories) { category in
                        SidebarCategoryDisclosure(
                            category: category,
                            labs: labs(in: category.id),
                            isExpanded: expandedCategories.contains(category.id),
                            isSelected: isCategorySelected(category.id),
                            toggle: { toggleCategory(category.id) },
                            selectCategory: {
                                withAnimation(Motion.page) {
                                    app.settingsOpen = false
                                    app.selectedLabID = nil
                                    app.armorySection = "maps"
                                    app.scope = .category(category.id)
                                    app.mode = .training
                                }
                            },
                            selectLab: { lab in
                                withAnimation(Motion.page) {
                                    app.settingsOpen = false
                                    app.armorySection = "maps"
                                    app.selectedLabID = lab.id
                                    app.mode = .training
                                }
                            }
                        )
                    }

                    guideNote
                        .padding(.top, 14)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
            .clipped()

            footer
        }
        .background(
            ZStack {
                Rectangle().fill(.thinMaterial).environment(\.colorScheme, .light)
                Color.white.opacity(0.48)
            }
        )
    }

    private func labs(in categoryID: String) -> [Lab] {
        app.labs.filter { $0.category == categoryID }
    }

    private func isCategorySelected(_ id: String) -> Bool {
        guard !app.settingsOpen, app.mode == .training, app.armorySection == "maps" else { return false }
        if let lab = app.selectedLab { return lab.category == id }
        return app.scope == .category(id)
    }

    private func toggleCategory(_ id: String) {
        withAnimation(reduceMotion ? nil : Motion.disclosure) {
            if expandedCategories.contains(id) {
                expandedCategories.remove(id)
            } else {
                expandedCategories.insert(id)
            }
        }
    }

    // MARK: - Brand (44pt Top Clearance for macOS Traffic Lights — Identical to Aexus Spear)

    private var brand: some View {
        HStack(spacing: 11) {
            PitEmblemView(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aexus Colosseum")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(-0.25)
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text("AI CYBER ARENA")
                    .font(ArenaType.microBold)
                    .tracking(1.3)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 44)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.45), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Section 1: ARENA (攻防对决核心流程)

    private var arenaSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ARENA · 攻防竞技")
                .font(ArenaType.microBold)
                .tracking(1.35)
                .foregroundStyle(ArenaTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            AppleSidebarNavRow(
                symbol: "sparkles.rectangle.stack.fill",
                title: "创建对决",
                count: "\(app.pit.lobbySeats.count) 席",
                selected: !app.settingsOpen && app.mode == .pitArena && app.lobbySubSection == "create"
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.lobbySubSection = "create"
                    app.mode = .pitArena
                }
            }

            let liveBadge: String = {
                if app.pit.match.isRunning { return "LIVE" }
                if app.pit.match.isCompleted { return "完赛" }
                if app.pit.match.status == "paused" { return "暂停" }
                return "待命"
            }()

            AppleSidebarNavRow(
                symbol: "waveform.path.ecg.rectangle.fill",
                title: "实况战场",
                count: liveBadge,
                selected: !app.settingsOpen && app.mode == .pitLive,
                countHighlighted: app.pit.match.isRunning
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.mode = .pitLive
                }
            }

            AppleSidebarNavRow(
                symbol: "trophy.fill",
                title: "天梯与战局录像",
                count: "\(max(app.pit.leaderboard.count, app.pit.recentReplays.count))",
                selected: !app.settingsOpen && app.mode == .pitArena && app.lobbySubSection == "leaderboard"
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.lobbySubSection = "leaderboard"
                    app.mode = .pitArena
                }
            }
        }
    }

    // MARK: - Section 2: ARMORY (靶标地图、传奇智能体与工具台)

    private var armorySection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ARMORY · 素材与工具")
                .font(ArenaType.microBold)
                .tracking(1.35)
                .foregroundStyle(ArenaTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            AppleSidebarNavRow(
                symbol: "square.grid.2x2.fill",
                title: "全部靶标地图",
                count: "\(max(app.labs.count, app.pit.armoryMaps.count))",
                selected: !app.settingsOpen && app.mode == .training && app.armorySection == "maps" && app.scope == .all && app.selectedLabID == nil
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.armorySection = "maps"
                    app.scope = .all
                    app.mode = .training
                }
            }

            AppleSidebarNavRow(
                symbol: "cpu.fill",
                title: "传奇渗透智能体",
                count: "\(app.pit.armoryHarnesses.count)",
                selected: !app.settingsOpen && app.mode == .training && app.armorySection == "harnesses"
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.armorySection = "harnesses"
                    app.mode = .training
                }
            }

            AppleSidebarNavRow(
                symbol: "terminal.fill",
                title: "单兵调试终端",
                count: app.runningLabs.isEmpty ? nil : "\(app.runningLabs.count) 运行",
                selected: !app.settingsOpen && app.mode == .workspace
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.mode = .workspace
                }
            }

            AppleSidebarNavRow(
                symbol: "server.rack",
                title: "主机与多队运维",
                count: app.events.isEmpty ? nil : "\(app.events.count)",
                selected: !app.settingsOpen && (app.mode == .hosts || app.mode == .events)
            ) {
                withAnimation(Motion.page) {
                    app.settingsOpen = false
                    app.selectedLabID = nil
                    app.mode = .hosts
                }
                if !app.platformLoaded {
                    Task { await app.loadPlatform() }
                }
            }
        }
    }

    // MARK: - Section 3: CATEGORIES (与 Aexus Spear 一致的可折叠分类树)

    private var categoriesHeader: some View {
        HStack(spacing: 8) {
            Text("CATEGORIES · 靶标分类")
                .font(ArenaType.microBold)
                .tracking(1.35)
                .foregroundStyle(ArenaTheme.textTertiary)
            Spacer()
            RoundIconButton(
                systemImage: allExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
                size: 26,
                help: allExpanded ? "折叠全部分类" : "展开全部分类"
            ) {
                withAnimation(reduceMotion ? nil : Motion.disclosure) {
                    expandedCategories = allExpanded ? [] : Set(app.categories.map(\.id))
                }
            }
        }
        .padding(.horizontal, 10)
    }

    private var guideNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArenaTheme.success)
            Text("所有参战容器均隔离外网直连，统一通过计量网关核算 Token 额度。")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Bottom Engine Workspace Card (Matching Aexus Spear Footer)

    private var footer: some View {
        let mapTotal = max(app.labs.count, app.pit.armoryMaps.count)
        let probeCount = app.pit.health.attachedProbes.count
        let progress: CGFloat = app.pit.connectionState.isLiveBackend ? 1.0 : 0.0

        return VStack(spacing: 8) {
            Rectangle()
                .fill(ArenaTheme.hairline)
                .frame(height: 1)

            Button {
                withAnimation(Motion.page) {
                    app.settingsOpen = true
                    app.selectedLabID = nil
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ArenaTheme.appleBlue.opacity(engineHovering ? 0.16 : 0.10))
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ArenaTheme.appleBlue)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ARENA ENGINE")
                            .font(ArenaType.microBold)
                            .tracking(1.0)
                            .foregroundStyle(ArenaTheme.textTertiary)
                        Text(app.pit.connectionState.statusLabel)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(ArenaTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text("\(probeCount) eBPF")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ArenaTheme.success)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(engineHovering ? 0.88 : 0.62))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(engineHovering ? 0.09 : 0.06), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.985))
            .onHover { value in
                withAnimation(Motion.hover) { engineHovering = value }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textQuaternary)
                    Text(app.serverReady ? "Arena 靶场服务器在线" : "本地与远程双模就绪")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ArenaTheme.textSecondary)
                    Spacer(minLength: 4)
                    Text("\(mapTotal) 款靶标可用")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArenaTheme.textTertiary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.06))
                        Capsule()
                            .fill(ArenaTheme.appleBlue.opacity(0.65))
                            .frame(width: max(0, proxy.size.width * progress))
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - Apple Sidebar Primary Row

private struct AppleSidebarNavRow: View {
    let symbol: String
    let title: String
    let count: String?
    let selected: Bool
    var countHighlighted: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(selected ? ArenaTheme.appleBlue : ArenaTheme.textSecondary)
                    .frame(width: 21)

                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? ArenaTheme.textPrimary : ArenaTheme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let count {
                    Text(count)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(countHighlighted ? Color.white : ArenaTheme.textTertiary)
                        .padding(.horizontal, countHighlighted ? 7 : 0)
                        .padding(.vertical, countHighlighted ? 2 : 0)
                        .background(
                            Capsule().fill(countHighlighted ? ArenaTheme.appleBlue : Color.clear)
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        selected
                            ? Color.white.opacity(0.95)
                            : (hovering ? Color.white.opacity(0.58) : Color.clear)
                    )
                    .shadow(color: .black.opacity(selected ? 0.055 : 0), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.black.opacity(0.06) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressStyle(scale: 0.99))
        .onHover { value in
            withAnimation(Motion.hover) { hovering = value }
        }
    }
}

// MARK: - Expandable Category Disclosure Group (Matching Aexus Spear)

private struct SidebarCategoryDisclosure: View {
    @EnvironmentObject private var app: AppState
    let category: CatalogCategory
    let labs: [Lab]
    let isExpanded: Bool
    let isSelected: Bool
    let toggle: () -> Void
    let selectCategory: () -> Void
    let selectLab: (Lab) -> Void
    @State private var hovering = false

    private var headerFill: Color {
        if isSelected { return ArenaTheme.appleBlue.opacity(0.10) }
        if hovering { return Color.white.opacity(0.60) }
        if isExpanded { return Color.black.opacity(0.03) }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button(action: selectCategory) {
                    HStack(spacing: 9) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: category.color))
                            .frame(width: 19)

                        Text(category.name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? ArenaTheme.textPrimary : ArenaTheme.textSecondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text("\(labs.count)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(ArenaTheme.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.995))

                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(ArenaTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 24, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.90))
            }
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .frame(height: 33)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(headerFill))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? ArenaTheme.appleBlue.opacity(0.20) : Color.clear, lineWidth: 1)
            )
            .onHover { value in
                withAnimation(Motion.hover) { hovering = value }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(labs.prefix(12)) { lab in
                        SidebarLabMiniRow(
                            lab: lab,
                            tint: Color(hex: category.color),
                            selected: app.selectedLabID == lab.id
                        ) {
                            selectLab(lab)
                        }
                    }
                }
                .padding(.leading, 18)
                .padding(.vertical, 3)
            }
        }
    }
}

private struct SidebarLabMiniRow: View {
    let lab: Lab
    let tint: Color
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LabGlyph(lab: lab, color: tint, size: 22)
                Text(lab.name)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? ArenaTheme.textPrimary : ArenaTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Circle()
                    .fill(lab.running ? ArenaTheme.appleBlue : (lab.installed ? ArenaTheme.success : Color.black.opacity(0.14)))
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, 10)
            .frame(height: 29)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.94) : (hovering ? Color.white.opacity(0.55) : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(selected ? ArenaTheme.appleBlue.opacity(0.24) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.99))
        .onHover { value in
            withAnimation(Motion.hover) { hovering = value }
        }
    }
}
