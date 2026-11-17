import SwiftUI
import AppKit

struct LibraryView: View {
    @EnvironmentObject private var app: AppState

    private let gridColumns = [
        GridItem(.adaptive(minimum: 248, maximum: 340), spacing: 16)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ApplePageHeader(
                    kicker: app.armorySection == "harnesses"
                        ? "LEGENDARY FLEET  •  \(app.pit.armoryHarnesses.count) SYSTEMS"
                        : "ARMORY CATALOG  •  \(app.filteredLabs.count) TARGETS",
                    title: app.armorySection == "harnesses" ? "传奇渗透智能体" : app.scopeTitle,
                    subtitle: app.armorySection == "harnesses"
                        ? "收纳全球高星开源自主渗透框架与顶尖 Coding Agent，统一通过环境变量接入斗兽场公平竞技。"
                        : app.scopeBlurb,
                    trailing: AnyView(
                        HStack(spacing: 8) {
                            AppleFilterPill(
                                title: "靶标地图库",
                                count: max(app.labs.count, app.pit.armoryMaps.count),
                                symbol: "square.grid.2x2.fill",
                                selected: app.armorySection == "maps"
                            ) {
                                withAnimation(Motion.hover) { app.armorySection = "maps" }
                            }
                            AppleFilterPill(
                                title: "传奇智能体",
                                count: app.pit.armoryHarnesses.count,
                                symbol: "cpu.fill",
                                selected: app.armorySection == "harnesses"
                            ) {
                                withAnimation(Motion.hover) { app.armorySection = "harnesses" }
                            }
                        }
                    )
                )

                if app.armorySection == "maps" {
                    categoryFilterBar

                    if let running = app.activeLab {
                        runningBanner(running)
                    }

                    if app.filteredLabs.isEmpty {
                        emptyMapsState
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(app.filteredLabs) { lab in
                                AppleStoreLabCard(lab: lab)
                            }
                        }
                    }
                } else {
                    harnessContractBanner

                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(app.pit.armoryHarnesses) { harness in
                            AppleStoreHarnessCard(harness: harness)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 26)
            .padding(.bottom, 44)
            .frame(maxWidth: 1420, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Wrapping Category Filter Rail (1:1 Aexus Spear Filter Bar)

    private var categoryFilterBar: some View {
        FlowLayout(spacing: 6, lineSpacing: 8) {
            AppleFilterPill(
                title: "All",
                count: app.count(in: .all),
                selected: app.scope == .all
            ) {
                withAnimation(Motion.hover) { app.scope = .all }
            }

            ForEach(app.categories) { cat in
                AppleFilterPill(
                    title: cat.name,
                    count: app.count(in: .category(cat.id)),
                    symbol: cat.symbol,
                    selected: app.scope == .category(cat.id)
                ) {
                    withAnimation(Motion.hover) { app.scope = .category(cat.id) }
                }
            }
        }
    }

    private func runningBanner(_ lab: Lab) -> some View {
        HStack(spacing: 12) {
            StatusDot(color: ArenaTheme.success, pulsing: true)
            Text("正在运行：\(lab.name)")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(ArenaTheme.textPrimary)
            Spacer()
            GhostButton(title: "进入单兵终端", systemImage: "terminal") {
                app.workspaceLabID = lab.id
                app.mode = .workspace
            }
            GhostButton(title: "停止", systemImage: "stop.fill", tint: ArenaTheme.danger) {
                Task { await app.stop(lab) }
            }
        }
        .padding(14)
        .arenaCard(radius: 16)
    }

    private var harnessContractBanner: some View {
        HStack(spacing: 14) {
            SquircleIconTile(
                symbol: "link.badge.plus",
                colors: [ArenaTheme.appleBlue, Color(hex: "4338CA")],
                size: 46
            )
            VStack(alignment: .leading, spacing: 3) {
                Text("零代码改造接入任意自研 Harness")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text("斗兽场自动向容器注入 OPENAI_BASE_URL、ANTHROPIC_BASE_URL、PIT_TOKEN_BUDGET 与 PIT_TARGETS_JSON，无需接入私有 SDK。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(ArenaTheme.textSecondary)
            }
            Spacer()
            CopyChip(
                text: "OPENAI_BASE_URL=http://host.docker.internal:18880/llm-gateway/$SEAT_TOKEN/v1",
                label: "复制环境变量规范"
            )
        }
        .padding(16)
        .arenaCard(radius: 18)
    }

    private var emptyMapsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ArenaTheme.textTertiary)
            Text("没有找到匹配的靶标")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ArenaTheme.textPrimary)
            Text("请尝试调整顶栏搜索关键词，或点击「All」查看全部靶标。")
                .font(.system(size: 13))
                .foregroundStyle(ArenaTheme.textSecondary)
            GhostButton(title: "清空筛选", systemImage: "xmark.circle") {
                app.searchText = ""
                app.scope = .all
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .arenaCard(radius: 20)
    }
}

// MARK: - Apple App Store Lab Card (1:1 Match with Aexus Spear ToolGridCard)

private struct AppleStoreLabCard: View {
    @EnvironmentObject private var app: AppState
    let lab: Lab
    @State private var hovering = false

    private var categoryColor: Color {
        if let cat = app.categories.first(where: { $0.id == lab.category }) {
            return Color(hex: cat.color)
        }
        return ArenaTheme.appleBlue
    }

    private var categoryTitle: String {
        app.categories.first(where: { $0.id == lab.category })?.name ?? lab.category.uppercased()
    }

    private var categorySymbol: String {
        app.categories.first(where: { $0.id == lab.category })?.symbol ?? "cube.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 10) {
                LabGlyph(lab: lab, color: categoryColor, size: 64)
                Spacer(minLength: 4)
                AppleOpenPill(
                    title: app.pit.selectedMapID == lab.id ? "已装载" : "选作靶标",
                    active: app.pit.selectedMapID == lab.id
                ) {
                    app.selectMapForPit(lab)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(lab.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .lineLimit(1)
                Text(lab.summary.isEmpty ? lab.subtitle : lab.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: categorySymbol)
                        .font(.system(size: 10, weight: .semibold))
                    Text(categoryTitle.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .lineLimit(1)
                }
                .foregroundStyle(categoryColor)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Circle()
                        .fill(lab.running ? ArenaTheme.appleBlue : (lab.installed ? ArenaTheme.success : Color.black.opacity(0.22)))
                        .frame(width: 5, height: 5)
                    Text(lab.running ? "RUNNING" : (lab.installed ? "LOCAL" : "READY"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(
                    color: .black.opacity(hovering ? 0.105 : 0.045),
                    radius: hovering ? 18 : 10,
                    x: 0,
                    y: hovering ? 9 : 5
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            hovering ? Color.black.opacity(0.10) : Color.black.opacity(0.055),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(hovering ? 1.012 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            withAnimation(Motion.page) {
                app.selectedLabID = lab.id
            }
        }
        .onHover { value in
            withAnimation(Motion.hover) { hovering = value }
        }
        .pointerCursor()
    }
}

// MARK: - Apple App Store Harness Card

private struct AppleStoreHarnessCard: View {
    @EnvironmentObject private var app: AppState
    let harness: PitHarnessPreset
    @State private var hovering = false

    private var accent: Color {
        Color(hex: harness.accentColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 10) {
                SquircleIconTile(
                    symbol: harness.defaultKind == .centaur ? "person.crop.circle.badge.bolt" : "cpu.fill",
                    colors: [accent, accent.opacity(0.72)],
                    size: 64,
                    glowing: hovering
                )
                Spacer(minLength: 4)
                AppleOpenPill(title: "派上场") {
                    app.selectHarnessForPit(harness)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(harness.name)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                        .lineLimit(1)
                    Text(harness.stars)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
                Text(harness.tagline)
                    .font(.system(size: 13))
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(harness.language.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Circle().fill(ArenaTheme.success).frame(width: 5, height: 5)
                    Text("ADAPTER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(
                    color: .black.opacity(hovering ? 0.105 : 0.045),
                    radius: hovering ? 18 : 10,
                    x: 0,
                    y: hovering ? 9 : 5
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            hovering ? Color.black.opacity(0.10) : Color.black.opacity(0.055),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(hovering ? 1.012 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            app.selectHarnessForPit(harness)
        }
        .onHover { value in
            withAnimation(Motion.hover) { hovering = value }
        }
        .pointerCursor()
    }
}
