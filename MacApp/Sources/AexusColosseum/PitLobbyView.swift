import SwiftUI
import AppKit

struct PitLobbyView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var pit: PitClient

    private let modeColumns = [
        GridItem(.adaptive(minimum: 235, maximum: 340), spacing: 16)
    ]

    private let seatColumns = [
        GridItem(.flexible(minimum: 260), spacing: 12),
        GridItem(.flexible(minimum: 260), spacing: 12)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                if app.lobbySubSection == "leaderboard" {
                    leaderboardScreen
                } else {
                    createMatchScreen
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 26)
            .padding(.bottom, 44)
            .frame(maxWidth: 1380, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Screen A: Guided 3-Step Match Creator (一眼看懂怎么用)

    private var createMatchScreen: some View {
        VStack(alignment: .leading, spacing: 28) {
            ApplePageHeader(
                kicker: "AEXUS COLOSSEUM  •  AI × 人类实网攻防竞技场",
                title: "开始一场攻防对决",
                subtitle: "将顶尖开源渗透智能体（Strix、Shannon、PentAGI 等）与人类白帽投入真实漏洞靶机，在统一 Token 额度下自动展开入侵与代码热修复。",
                trailing: AnyView(
                    HStack(spacing: 10) {
                        GhostButton(title: "查看天梯榜", systemImage: "trophy") {
                            withAnimation(Motion.page) { app.lobbySubSection = "leaderboard" }
                        }
                        AccentButton(title: "一键启动实网圣杯战", systemImage: "play.fill") {
                            Task {
                                pit.applyPreset(.legendaryGrail)
                                pit.tokenBudget = 25_000
                                pit.lobbySeats = Array(pit.lobbySeats.prefix(3)).enumerated().map { i, s in
                                    var copy = s
                                    copy.id = "seat-\(i + 1)"
                                    copy.tokenBudget = 25_000
                                    return copy
                                }
                                await pit.unleashMatch()
                                withAnimation(Motion.page) { app.mode = .pitLive }
                            }
                        }
                    }
                )
            )

            howItWorksBanner

            // STEP 1: Choose Game Mode
            VStack(alignment: .leading, spacing: 14) {
                AppleSectionHeader(
                    stepNumber: "1",
                    title: "选择对战模式",
                    subtitle: "四种核心规则覆盖双向源码攻防、中央靶机争夺、百题竞速与人机防守战"
                )

                LazyVGrid(columns: modeColumns, spacing: 16) {
                    ForEach(PitGameMode.allCases) { mode in
                        AppleModeCard(
                            mode: mode,
                            selected: pit.selectedMode == mode
                        ) {
                            withAnimation(Motion.hover) {
                                pit.selectedMode = mode
                            }
                        }
                    }
                }
            }

            // STEP 2: Configure Combatant Seats
            VStack(alignment: .leading, spacing: 14) {
                AppleSectionHeader(
                    stepNumber: "2",
                    title: "配置参战席位（\(pit.lobbySeats.count) / 6 席）",
                    subtitle: "每个席位可选全自动开源渗透 Harness、真人白帽，或「人机合体」协同模式",
                    actionTitle: pit.lobbySeats.count < 6 ? "添加参战席位" : nil,
                    action: pit.lobbySeats.count < 6 ? {
                        withAnimation(Motion.hover) { pit.addLobbySeat() }
                    } : nil
                )

                // Quick Preset Filter Pills
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(PitLobbyPreset.allCases) { preset in
                        AppleFilterPill(
                            title: preset.title,
                            selected: pit.activePreset == preset
                        ) {
                            withAnimation(Motion.hover) {
                                pit.applyPreset(preset)
                            }
                        }
                    }
                }

                LazyVGrid(columns: seatColumns, spacing: 12) {
                    ForEach(Array(pit.lobbySeats.enumerated()), id: \.element.id) { idx, seat in
                        AppleSeatRowCard(
                            index: idx,
                            seat: seat,
                            canRemove: pit.lobbySeats.count > 2,
                            harnesses: pit.armoryHarnesses,
                            onSelectHarness: { chosen in
                                pit.lobbySeats[idx].name = chosen.name
                                pit.lobbySeats[idx].harnessId = chosen.id
                                pit.lobbySeats[idx].kind = chosen.defaultKind
                                pit.lobbySeats[idx].model = chosen.defaultModel
                                pit.lobbySeats[idx].teamColor = chosen.accentColor
                            },
                            onSelectKind: { kind in
                                pit.lobbySeats[idx].kind = kind
                            },
                            onSelectModel: { model in
                                pit.lobbySeats[idx].model = model
                            },
                            onRemove: {
                                withAnimation(Motion.hover) {
                                    pit.removeLobbySeat(at: idx)
                                }
                            }
                        )
                    }
                }
            }

            // STEP 3: Target Map & Fair Token Budget + Launch CTA
            VStack(alignment: .leading, spacing: 14) {
                AppleSectionHeader(
                    stepNumber: "3",
                    title: "选定靶标地图与公平 Token 额度",
                    subtitle: "所有席位强制接入统一计量网关，额度耗尽返回 HTTP 402 停机，同分时消耗更少 Token 获胜",
                    actionTitle: "浏览全部 \(max(app.labs.count, pit.armoryMaps.count)) 款靶标",
                    action: {
                        withAnimation(Motion.page) {
                            app.armorySection = "maps"
                            app.mode = .training
                        }
                    }
                )

                HStack(alignment: .top, spacing: 16) {
                    targetSelectorCard
                    tokenBudgetAndLaunchCard
                }
            }
        }
    }

    // MARK: - 3-Step Onboarding Strip (Clear Visual Instructions)

    private var howItWorksBanner: some View {
        HStack(spacing: 0) {
            onboardingStep(
                num: "01",
                icon: "flag.2.crossed.fill",
                tint: ArenaTheme.appleBlue,
                title: "选定竞技规则",
                detail: "支持攻防混战、圣杯战争、竞速夺旗与人类防线"
            )
            Divider().frame(height: 38).padding(.horizontal, 14)
            onboardingStep(
                num: "02",
                icon: "cpu.fill",
                tint: Color(hex: "6366F1"),
                title: "混编 AI 与真人席位",
                detail: "零改造投放 Strix / Shannon / Claude Code 或真人接管"
            )
            Divider().frame(height: 38).padding(.horizontal, 14)
            onboardingStep(
                num: "03",
                icon: "waveform.path.ecg",
                tint: ArenaTheme.success,
                title: "宿主机 eBPF 实时透视",
                detail: "每条底层命令实时映射为攻防态势、进程链与补丁对比"
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .arenaCard(radius: 18)
    }

    private func onboardingStep(num: String, icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.11))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("STEP \(num)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                        .lineLimit(1)
                }
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Target Selector & Token Budget Cards

    private var targetSelectorCard: some View {
        let map = pit.selectedMap
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                SquircleIconTile(
                    symbol: "building.columns.fill",
                    colors: [ArenaTheme.appleBlue, Color(hex: "4338CA")],
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("当前对决靶标地图")
                        .font(ArenaType.microBold)
                        .tracking(1.0)
                        .foregroundStyle(ArenaTheme.textTertiary)

                    Menu {
                        ForEach(pit.armoryMaps.prefix(30)) { item in
                            Button("\(item.name) (\(item.category.uppercased()))") {
                                pit.selectedMapID = item.id
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(map.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ArenaTheme.textPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ArenaTheme.appleBlue)
                        }
                        .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .pointerCursor()

                    Text(map.summary)
                        .font(.system(size: 12.5))
                        .foregroundStyle(ArenaTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("靶机内部五层监控架构（由宿主机 Linux eBPF 实时追踪）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArenaTheme.textTertiary)

                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(PitOrganLayer.allCases) { layer in
                        HStack(spacing: 4) {
                            Image(systemName: layer.symbol)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(ArenaTheme.appleBlue)
                            Text("\(layer.index). \(layer.title)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ArenaTheme.textSecondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Capsule().fill(Color.black.opacity(0.04)))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .arenaCard(radius: 20)
    }

    private var tokenBudgetAndLaunchCard: some View {
        let budgets = [25_000, 50_000, 250_000, 500_000, 1_000_000, 2_500_000, 5_000_000]
        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("每席位固定 Token 额度上限")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                    Text("不限制子代理数量，统一以网关实测 Token 消耗结算")
                        .font(.system(size: 12))
                        .foregroundStyle(ArenaTheme.textSecondary)
                }
                Spacer()
                Text(PitSeat.compactTokens(pit.tokenBudget) + " Tokens")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ArenaTheme.appleBlue)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(budgets, id: \.self) { value in
                    let active = pit.tokenBudget == value
                    Button {
                        withAnimation(Motion.hover) {
                            pit.tokenBudget = value
                            for i in pit.lobbySeats.indices {
                                pit.lobbySeats[i].tokenBudget = value
                            }
                        }
                    } label: {
                        Text(PitSeat.compactTokens(value))
                            .font(.system(size: 12, weight: active ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(active ? .white : ArenaTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(active ? ArenaTheme.appleBlue : Color.black.opacity(0.045))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle(scale: 0.96))
                }
            }

            Button {
                Task {
                    await pit.unleashMatch()
                    withAnimation(Motion.page) {
                        app.mode = .pitLive
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("开始攻防对决 · Launch into Arena")
                            .font(.system(size: 14.5, weight: .bold))
                        Text("启动 \(pit.lobbySeats.count) 个隔离沙盒席位与实时 eBPF 态势转播")
                            .font(.system(size: 11))
                            .opacity(0.88)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ArenaTheme.appleBlue)
                        .shadow(color: ArenaTheme.appleBlue.opacity(0.28), radius: 12, y: 5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressStyle(scale: 0.98))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .arenaCard(radius: 20)
    }

    // MARK: - Screen B: Global Pit Leaderboard & Standalone Replays

    private var leaderboardScreen: some View {
        VStack(alignment: .leading, spacing: 26) {
            ApplePageHeader(
                kicker: "LEADERBOARD & REPLAYS  •  积分优先 · 同分少 TOKEN 获胜",
                title: "天梯榜与战局录像",
                subtitle: "记录各大开源渗透智能体、大模型与人类选手的真实攻防胜率及单次破防算力效率。",
                trailing: AnyView(
                    AccentButton(title: "返回创建对决", systemImage: "plus") {
                        withAnimation(Motion.page) { app.lobbySubSection = "create" }
                    }
                )
            )

            // Leaderboard Table Card
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("排名")
                        .frame(width: 48, alignment: .leading)
                    Text("参战智能体 / 选手")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("驱动模型")
                        .frame(width: 160, alignment: .leading)
                    Text("胜率")
                        .frame(width: 80, alignment: .trailing)
                    Text("总积分")
                        .frame(width: 100, alignment: .trailing)
                    Text("平均破防消耗")
                        .frame(width: 130, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArenaTheme.textTertiary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.025))

                if pit.leaderboard.isEmpty {
                    Divider()
                    VStack(spacing: 8) {
                        Image(systemName: "trophy")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(ArenaTheme.appleBlue.opacity(0.65))
                        Text("暂无已归档的实网战局排行记录")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Text("完成首场真实容器攻防对决后，系统将自动按积分与 Token 效率排序归档。")
                            .font(.system(size: 12))
                            .foregroundStyle(ArenaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    ForEach(Array(pit.leaderboard.enumerated()), id: \.element.id) { idx, item in
                        Divider()
                        HStack {
                            HStack(spacing: 5) {
                                if idx == 0 {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ArenaTheme.grailGold)
                                }
                                Text("#\(idx + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(idx == 0 ? ArenaTheme.grailGold : ArenaTheme.textSecondary)
                            }
                            .frame(width: 48, alignment: .leading)

                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: item.teamColor))
                                    .frame(width: 8, height: 8)
                                Text(item.combatantName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ArenaTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(item.model)
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundStyle(ArenaTheme.textSecondary)
                                .frame(width: 160, alignment: .leading)

                            Text("\(Int((item.winRate <= 1 ? item.winRate * 100 : item.winRate).rounded()))%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(ArenaTheme.textPrimary)
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)

                            Text("\(item.totalScore) pts")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundStyle(ArenaTheme.appleBlue)
                                .monospacedDigit()
                                .frame(width: 100, alignment: .trailing)

                            HStack(spacing: 4) {
                                Spacer()
                                Chip(
                                    text: "\(PitSeat.compactTokens(item.avgTokensPerSolve)) / 破防",
                                    color: idx == 0 ? ArenaTheme.success : ArenaTheme.textSecondary
                                )
                            }
                            .frame(width: 130, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .arenaCard(radius: 20)

            // Standalone Replay Vault
            VStack(alignment: .leading, spacing: 14) {
                AppleSectionHeader(
                    title: "独立战局录像 (.pitreplay.html)",
                    subtitle: "导出单文件网页录像，无需安装任何环境即可在任意浏览器 60 帧回放整场攻防",
                    actionTitle: pit.match.isStandby ? nil : "导出当前战局录像",
                    action: pit.match.isStandby ? nil : {
                        Task {
                            let url = URL(fileURLWithPath: NSHomeDirectory())
                                .appendingPathComponent("Downloads/aexus-match.pitreplay.html")
                            _ = try? await pit.exportReplayHTML(to: url, openInBrowser: true)
                            app.show(ActivityBanner(text: "已导出独立录像至下载目录并打开", success: true))
                        }
                    }
                )

                if pit.recentReplays.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ArenaTheme.appleBlue.opacity(0.7))
                        Text("暂无历史战局录像记录，发起一场实网对决后将自动在此存档。")
                            .font(.system(size: 12.5))
                            .foregroundStyle(ArenaTheme.textSecondary)
                        Spacer()
                    }
                    .padding(18)
                    .arenaCard(radius: 18)
                } else {
                    LazyVGrid(columns: seatColumns, spacing: 14) {
                        ForEach(pit.recentReplays) { rep in
                            HStack(spacing: 14) {
                                SquircleIconTile(
                                    symbol: rep.mode.symbol,
                                    colors: [rep.mode.accentColor, ArenaTheme.appleBlueDeep],
                                    size: 48
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rep.title)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(ArenaTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("获胜方：\(rep.winnerName)  •  \(rep.tokenEfficiencyLabel)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ArenaTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                AppleOpenPill(title: "查看") {
                                    Task {
                                        await pit.loadMatch(id: rep.id)
                                        withAnimation(Motion.page) { app.mode = .pitLive }
                                    }
                                }
                            }
                            .padding(16)
                            .arenaCard(radius: 18)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Apple App Store Mode Card (Matching Aexus Spear ToolGridCard)

private struct AppleModeCard: View {
    let mode: PitGameMode
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    private var palette: [Color] {
        switch mode {
        case .awd: return [Color(hex: "EF4444"), Color(hex: "B91C1C")]
        case .grail: return [Color(hex: "F59E0B"), Color(hex: "B45309")]
        case .speedrun: return [ArenaTheme.appleBlue, Color(hex: "1D4ED8")]
        case .lastStand: return [Color(hex: "10B981"), Color(hex: "047857")]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SquircleIconTile(symbol: mode.symbol, colors: palette, size: 58, glowing: hovering || selected)
                Spacer()
                AppleOpenPill(title: selected ? "已选" : "选择", active: selected, action: action)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(mode.title)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                    Text(mode.englishSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ArenaTheme.textTertiary)
                        .lineLimit(1)
                }
                Text(mode.tagline)
                    .font(.system(size: 12.5))
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Text(mode.mapBadge.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.45)
                    .foregroundStyle(palette[0])
                Spacer()
                if selected {
                    HStack(spacing: 4) {
                        Circle().fill(ArenaTheme.appleBlue).frame(width: 5, height: 5)
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ArenaTheme.appleBlue)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(
                    color: .black.opacity(selected ? 0.09 : (hovering ? 0.08 : 0.04)),
                    radius: hovering || selected ? 16 : 10,
                    x: 0,
                    y: hovering || selected ? 8 : 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            selected ? ArenaTheme.appleBlue.opacity(0.65) : Color.black.opacity(hovering ? 0.10 : 0.055),
                            lineWidth: selected ? 1.5 : 1
                        )
                )
        )
        .scaleEffect(hovering ? 1.01 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: action)
        .onHover { value in
            withAnimation(Motion.hover) { hovering = value }
        }
        .pointerCursor()
    }
}

// MARK: - Clean Apple Combatant Seat Card

private struct AppleSeatRowCard: View {
    let index: Int
    let seat: PitSeat
    let canRemove: Bool
    let harnesses: [PitHarnessPreset]
    let onSelectHarness: (PitHarnessPreset) -> Void
    let onSelectKind: (PitSeatKind) -> Void
    let onSelectModel: (String) -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(hex: seat.teamColor).opacity(0.14))
                Text("S\(index + 1)")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: seat.teamColor))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(harnesses) { h in
                            Button("\(h.name) — \(h.stars)") {
                                onSelectHarness(h)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(seat.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ArenaTheme.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(ArenaTheme.textTertiary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .pointerCursor()

                    Menu {
                        ForEach(PitSeatKind.allCases) { k in
                            Button(k.label) { onSelectKind(k) }
                        }
                    } label: {
                        Chip(
                            text: seat.kind.shortLabel,
                            color: seat.kind == .harness ? ArenaTheme.appleBlue : (seat.kind == .human ? ArenaTheme.success : ArenaTheme.grailGold)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .pointerCursor()
                }

                HStack(spacing: 8) {
                    Menu {
                        ForEach(PitCatalogPresets.availableModels, id: \.self) { m in
                            Button(m) { onSelectModel(m) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(ArenaTheme.appleBlue)
                            Text(seat.model)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(ArenaTheme.textSecondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .pointerCursor()

                    Spacer()

                    Label("唯一网关计量", systemImage: "lock.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
            }

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ArenaTheme.textQuaternary)
                }
                .buttonStyle(PressStyle(scale: 0.90))
                .help("移除该席位")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(hovering ? 0.065 : 0.035), radius: 8, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(hovering ? 0.10 : 0.06), lineWidth: 1)
                )
        )
        .onHover { hovering = $0 }
    }
}
