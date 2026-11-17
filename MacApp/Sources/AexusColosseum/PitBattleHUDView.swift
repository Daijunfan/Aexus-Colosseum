import SwiftUI
import AppKit

struct PitBattleHUDView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var pit: PitClient

    @State private var commandInput: String = ""
    @State private var hintInput: String = ""
    @State private var showHintPopover: Bool = false

    private var rankedSeats: [PitSeat] {
        PitSeat.rankSorted(pit.match.seats)
    }

    private var activeSeat: PitSeat {
        pit.match.seats.first(where: { $0.id == pit.focusedSeatID })
            ?? rankedSeats.first
            ?? PitSeat(id: "seat-1", name: "Gladiator", thought: "")
    }

    private var activeTarget: PitTarget {
        pit.match.targets.first(where: { $0.id == pit.focusedTargetID })
            ?? pit.match.targets.first
            ?? PitTarget(id: "target-grail", name: pit.match.mapName)
    }

    var body: some View {
        if pit.match.isStandby {
            standbyStageView
        } else {
            liveOrCompletedBattleView
        }
    }

    // MARK: - 0. Honest Apple Daylight Standby Stage (When No Match Is Running)

    private var standbyStageView: some View {
        VStack {
            Spacer(minLength: 20)
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ArenaTheme.appleBlue.opacity(0.10))
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(ArenaTheme.appleBlue)
                }
                .frame(width: 56, height: 56)

                VStack(spacing: 8) {
                    Text("AEXUS COLOSSEUM · REAL KERNEL TELEMETRY STAGE")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(ArenaTheme.textTertiary)

                    Text("实况战场已就绪 · 尚无进行中的对决")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ArenaTheme.textPrimary)

                    Text("所有对决均运行在真实 Docker 容器沙箱与宿主机 Linux eBPF 内核探针下。请先在大厅编排并启动一场对决，本页将实时流式渲染攻击弹道、连招特写与源码热补丁。")
                        .font(.system(size: 13))
                        .foregroundStyle(ArenaTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }

                HStack(spacing: 12) {
                    standbyStatusTile(
                        title: "后端控制面",
                        value: pit.connectionState.isLiveBackend ? "pitd 在线" : pit.connectionState.statusLabel,
                        tint: pit.connectionState.isLiveBackend ? ArenaTheme.success : ArenaTheme.warning
                    )
                    standbyStatusTile(
                        title: "Linux eBPF 探针",
                        value: pit.connectionState.isLiveBackend
                            ? "\(pit.health.attachedProbes.count) 探针 (\(pit.health.mode))"
                            : "0 探针",
                        tint: pit.health.attachedProbes.isEmpty ? ArenaTheme.textSecondary : ArenaTheme.appleBlue
                    )
                    standbyStatusTile(
                        title: "Ring-0 内核直滤",
                        value: pit.health.perfStats.map { String(format: "%.2f%% · 0 Drop", $0.kernelFilterPct) }
                            ?? (pit.health.dockerReady ? "Docker 已就绪" : "待连接"),
                        tint: ArenaTheme.appleBlue
                    )
                }
                .frame(maxWidth: 560)

                AccentButton(title: "前往大厅创建实网对决", systemImage: "plus") {
                    withAnimation(Motion.page) {
                        app.lobbySubSection = "create"
                        app.mode = .pitArena
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: 640)
            .arenaCard(radius: 24)
            Spacer(minLength: 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func standbyStatusTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ArenaTheme.textTertiary)
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(value)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.968, green: 0.971, blue: 0.980))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }

    // MARK: - Live / Paused / Completed Battle Layout

    private var liveOrCompletedBattleView: some View {
        VStack(spacing: 12) {
            stageControlBar

            contestantScoreStrip

            ZStack(alignment: .bottom) {
                Group {
                    switch pit.activeLens {
                    case .macroArena:
                        macroRadarStage
                    case .xrayOrgan:
                        organAnatomyStage
                    case .liveWebHijack:
                        webHijackStage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if pit.visorOpen {
                    inspectorDrawer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomCasterAndActionBar
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .focusable()
        .onKeyPress(.space) {
            withAnimation(Motion.disclosure) {
                pit.visorOpen.toggle()
            }
            return .handled
        }
    }

    // MARK: - 1. Clean Apple Stage Control Bar

    private var stageControlBar: some View {
        let isCompleted = pit.match.isCompleted
        let isPaused = pit.match.status == "paused"
        let mins = max(0, pit.match.roundSecondsRemaining) / 60
        let secs = max(0, pit.match.roundSecondsRemaining) % 60
        let ebpfCount = max(pit.health.eventsCaptured, pit.match.events.count)

        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Chip(text: pit.match.mode.title, color: ArenaTheme.appleBlue, filled: true)

                Text("第 \(pit.match.round)/\(pit.match.maxRounds) 轮")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .monospacedDigit()

                Text("•")
                    .foregroundStyle(ArenaTheme.textQuaternary)

                if isCompleted {
                    Chip(
                        text: "已完赛结算 · 用时 \(pit.match.elapsedSec)s",
                        color: ArenaTheme.success
                    )
                } else if isPaused {
                    Chip(
                        text: String(format: "已暂停 · %02d:%02d", mins, secs),
                        color: ArenaTheme.warning
                    )
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(String(format: "%02d:%02d", mins, secs))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(ArenaTheme.textSecondary)
                }

                Text("•")
                    .foregroundStyle(ArenaTheme.textQuaternary)

                Text("eBPF \(ebpfCount) 条指令")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ArenaTheme.success)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            HStack(spacing: 3) {
                stageLensTab(lens: .macroArena, title: "全局攻防态势", icon: "dot.radiowaves.left.and.right")
                stageLensTab(lens: .xrayOrgan, title: "靶机五层透视", icon: "square.3.layers.3d.down.right")
                stageLensTab(lens: .liveWebHijack, title: "目标网页实况", icon: "safari")
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.055))
            )

            Button {
                withAnimation(Motion.hover) {
                    pit.autoDirectorEnabled.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: pit.autoDirectorEnabled ? "video.fill" : "video.slash")
                        .font(.system(size: 11, weight: .semibold))
                    Text("自动导播")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(pit.autoDirectorEnabled ? ArenaTheme.appleBlue : ArenaTheme.textSecondary)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(
                    Capsule().fill(pit.autoDirectorEnabled ? ArenaTheme.appleBlue.opacity(0.11) : Color.white.opacity(0.85))
                )
                .overlay(
                    Capsule().strokeBorder(
                        pit.autoDirectorEnabled ? ArenaTheme.appleBlue.opacity(0.25) : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(PressStyle(scale: 0.96))

            Button {
                withAnimation(Motion.disclosure) {
                    pit.visorOpen.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11, weight: .semibold))
                    Text(pit.visorOpen ? "收起检视台" : "底层检视台")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(pit.visorOpen ? .white : ArenaTheme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule().fill(pit.visorOpen ? ArenaTheme.appleBlue : Color.white.opacity(0.90))
                )
                .overlay(
                    Capsule().strokeBorder(
                        pit.visorOpen ? Color.clear : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(PressStyle(scale: 0.96))

            Menu {
                if !isCompleted {
                    Button(isPaused ? "继续比赛" : "暂停比赛") {
                        Task { await pit.togglePauseMatch() }
                    }
                    Button("推进下一轮") {
                        Task { await pit.nextRoundMatch() }
                    }
                    Button("结束本局对决", role: .destructive) {
                        Task { await pit.stopMatch() }
                    }
                    Divider()
                    Button("随机事件：熔断 WAF 护盾") {
                        Task { await pit.triggerChaos(chaosType: "drop_waf") }
                    }
                    Button("随机事件：广播源码漏洞线索") {
                        Task { await pit.triggerChaos(chaosType: "leak_hint") }
                    }
                    Divider()
                } else {
                    Button("前往大厅新建对决") {
                        withAnimation(Motion.page) {
                            app.lobbySubSection = "create"
                            app.mode = .pitArena
                        }
                    }
                    Divider()
                }
                Button(pit.hudSidebarHintTitle(collapsed: app.hudSidebarCollapsed)) {
                    withAnimation(Motion.page) { app.hudSidebarCollapsed.toggle() }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    Text("场控")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ArenaTheme.textSecondary)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(Capsule().fill(Color.white.opacity(0.88)))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .pointerCursor()
        }
    }

    private func stageLensTab(lens: PitCameraLens, title: String, icon: String) -> some View {
        let selected = pit.activeLens == lens
        return Button {
            withAnimation(Motion.hover) {
                pit.autoDirectorEnabled = false
                pit.activeLens = lens
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(selected ? ArenaTheme.textPrimary : ArenaTheme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.white : Color.clear)
                    .shadow(color: .black.opacity(selected ? 0.07 : 0), radius: 3, y: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }

    // MARK: - 2. Top Contestant Score, SLA ECG & Token Quota Strip

    private var contestantScoreStrip: some View {
        let ranked = rankedSeats
        return HStack(spacing: 10) {
            ForEach(Array(ranked.prefix(5).enumerated()), id: \.element.id) { rankIdx, seat in
                AppleContestantHUDCard(
                    rank: rankIdx + 1,
                    seat: seat,
                    focused: pit.focusedSeatID == seat.id
                ) {
                    withAnimation(Motion.hover) {
                        pit.focusedSeatID = seat.id
                    }
                }
            }
        }
    }

    // MARK: - 3A. View 1: Mode-Aware Tactical Radar + Live Kernel Weapon Dock + Event Feed

    private var macroRadarStage: some View {
        let isCompleted = pit.match.isCompleted
        let isRunning = pit.match.isRunning
        let winner = rankedSeats.first

        return HStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                DaylightColosseumRadarCanvas(
                    mode: pit.match.mode,
                    round: pit.match.round,
                    maxRounds: pit.match.maxRounds,
                    isRunning: isRunning,
                    isCompleted: isCompleted,
                    seats: pit.match.seats,
                    targets: pit.match.targets,
                    primaryTarget: activeTarget,
                    projectiles: isRunning ? pit.activeProjectiles : [],
                    focusedSeatID: pit.focusedSeatID
                )

                // Top Overlay: Championship Settlement Banner when Completed, else Live Camera Cue
                if isCompleted {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(ArenaTheme.grailGold.opacity(0.16))
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ArenaTheme.grailGold)
                        }
                        .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(
                                winner != nil
                                    ? "对决已完赛结算 · 冠军：\(winner!.name)（\(winner!.score) 分 · \(winner!.tokensFormatted)）"
                                    : "对决已完赛结算"
                            )
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                            .lineLimit(1)

                            Text("全部容器沙箱已冻结回收 · 总用时 \(pit.match.elapsedSec)s · 归档 \(pit.match.events.count) 条内核 eBPF 事件")
                                .font(.system(size: 11))
                                .foregroundStyle(ArenaTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        AppleOpenPill(title: "+ 新建对决", active: true) {
                            withAnimation(Motion.page) {
                                app.lobbySubSection = "create"
                                app.mode = .pitArena
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.96))
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(ArenaTheme.success.opacity(0.28), lineWidth: 1)
                    )
                    .padding(14)
                } else {
                    HStack(alignment: .top) {
                        HStack(spacing: 7) {
                            Image(systemName: "scope")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(ArenaTheme.appleBlue)
                            Text(
                                pit.match.status == "paused"
                                    ? "比赛已暂停 · 容器攻防时钟暂时冻结"
                                    : (pit.match.cameraCue?.reason ?? "实时追踪各席位底层命令特效、连招组合与代码热修复")
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ArenaTheme.textPrimary)
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.94)))
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)

                        Spacer(minLength: 10)

                        if isRunning,
                           let comboText = activeMacComboBanner(projectiles: pit.activeProjectiles, seats: pit.match.seats) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(comboText)
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(ArenaTheme.danger))
                            .shadow(color: ArenaTheme.danger.opacity(0.28), radius: 8, y: 3)
                        }
                    }
                    .padding(14)
                }

                // Bottom Live Kernel Weapon & Ring-0 Per-CPU Filter Dock
                VStack {
                    Spacer()
                    kernelTelemetryDock
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .arenaCard(radius: 20)

            // Right: Clean Apple Live Event Feed
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("实时攻防动态", systemImage: "bolt.horizontal.fill")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                    Spacer()
                    Text(isCompleted ? "本局归档" : "eBPF 实时驱动")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Divider()

                if pit.match.killFeed.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "bolt.horizontal.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(ArenaTheme.appleBlue.opacity(0.55))
                        Text("等待真实内核攻防信号")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Text("容器内执行命令、夺旗或源码热修复后将实时推送至此")
                            .font(.system(size: 11))
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(pit.match.killFeed.prefix(10)) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(item.badge)
                                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(item.isCritical ? ArenaTheme.danger : ArenaTheme.appleBlue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(
                                                    (item.isCritical ? ArenaTheme.danger : ArenaTheme.appleBlue).opacity(0.10)
                                                )
                                            )
                                        Text(item.actorName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(ArenaTheme.textPrimary)
                                        Spacer()
                                    }
                                    Text(item.message)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(ArenaTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color(red: 0.968, green: 0.971, blue: 0.980))
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                }
            }
            .frame(width: 316)
            .frame(maxHeight: .infinity)
            .arenaCard(radius: 20)
        }
    }

    private var kernelTelemetryDock: some View {
        let events = pit.match.events
        let sonarCnt = events.filter { $0.vfxType == .sonarSweep }.count
        let barrageCnt = events.filter { $0.vfxType == .armorPiercingBarrage }.count
        let rceCnt = events.filter { $0.vfxType == .rceParasiteBreach || $0.vfxType == .reverseShellChain }.count
        let grailCnt = events.filter { $0.vfxType == .grailHeartStolen || $0.vfxType == .rootShockwave }.count
        let patchCnt = max(pit.match.patches.count, events.filter { $0.vfxType == .nanoPatchWeld }.count)

        return HStack(spacing: 10) {
            Text("内核武器遥测")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArenaTheme.textPrimary)

            telemetryCountPill(color: Color(hex: "0284C7"), label: "声呐扫描", count: sonarCnt)
            telemetryCountPill(color: Color(hex: "EA580C"), label: "注入弹幕", count: barrageCnt)
            telemetryCountPill(color: ArenaTheme.danger, label: "RCE 破防", count: rceCnt)
            telemetryCountPill(color: ArenaTheme.grailGold, label: "夺旗提权", count: grailCnt)
            telemetryCountPill(color: ArenaTheme.appleBlue, label: "纳米热补丁", count: patchCnt)

            Spacer(minLength: 4)

            if let perf = pit.health.perfStats {
                Text(String(format: "⚡ Ring-0 直滤 %.1f%% · Drop %llu", perf.kernelFilterPct, perf.ringbufDrops))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ArenaTheme.appleBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ArenaTheme.appleBlue.opacity(0.09)))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.93))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    private func telemetryCountPill(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(count > 0 ? 1.0 : 0.38))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10.5, weight: count > 0 ? .semibold : .regular))
                .foregroundStyle(count > 0 ? ArenaTheme.textPrimary : ArenaTheme.textSecondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(count > 0 ? color : ArenaTheme.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(count > 0 ? color.opacity(0.12) : Color.black.opacity(0.04))
                )
        }
    }

    // MARK: - 3B. View 2: Target 5-Layer Digital Anatomy + Real Process Tree & Live Source/Diff

    private var organAnatomyStage: some View {
        let latestTargetPatch = pit.match.patches.first(where: { $0.targetId == activeTarget.id }) ?? pit.match.patches.first
        let diffText = activeTarget.lastDiff ?? latestTargetPatch?.diff

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("靶机内部五层受创与修补状态")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Text("目标实例：\(activeTarget.name)\(activeTarget.address.isEmpty ? "" : " (\(activeTarget.address))")")
                            .font(.system(size: 12))
                            .foregroundStyle(ArenaTheme.textSecondary)
                    }
                    Spacer()

                    if pit.match.targets.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(pit.match.targets) { tg in
                                Button {
                                    pit.focusedTargetID = tg.id
                                } label: {
                                    Text(tg.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(tg.id == activeTarget.id ? .white : ArenaTheme.textSecondary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(tg.id == activeTarget.id ? ArenaTheme.appleBlue : Color.black.opacity(0.05))
                                        )
                                }
                                .buttonStyle(PressStyle(scale: 0.96))
                            }
                        }
                    }

                    Chip(
                        text: activeTarget.healthy ? "SLA 业务正常 \(Int(activeTarget.slaScore))%" : "SLA 业务受损",
                        color: activeTarget.healthy ? ArenaTheme.success : ArenaTheme.danger
                    )
                }

                VStack(spacing: 9) {
                    ForEach(activeTarget.organs) { organ in
                        let statusColor: Color = organ.compromised
                            ? ArenaTheme.danger
                            : (organ.patched ? ArenaTheme.appleBlue : ArenaTheme.success)
                        let statusText: String = organ.compromised
                            ? "已被突破"
                            : (organ.patched ? "热补丁已加固" : "防线稳固")

                        HStack(spacing: 13) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(statusColor.opacity(0.11))
                                Image(systemName: organ.layer.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(statusColor)
                            }
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("0\(organ.layer.index) · \(organ.layer.title)")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(ArenaTheme.textPrimary)
                                    Text(organ.layer.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(ArenaTheme.textTertiary)
                                        .lineLimit(1)
                                    Spacer()
                                    Chip(text: statusText, color: statusColor)
                                }

                                Text(organ.detail.isEmpty ? "正在通过宿主机 eBPF 追踪该层系统调用" : organ.detail)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(ArenaTheme.textSecondary)
                                    .lineLimit(1)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.black.opacity(0.06))
                                        Capsule()
                                            .fill(statusColor)
                                            .frame(width: max(8, geo.size.width * min(1, max(0.08, organ.integrity))))
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.972, green: 0.975, blue: 0.984))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(statusColor.opacity(organ.compromised ? 0.30 : 0.12), lineWidth: 1)
                                )
                        )
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .arenaCard(radius: 20)

            // Right: Real Linux execve Process Chain & Real Container Source / Git Diff
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Linux execve 实时进程派生链", systemImage: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Spacer()
                        Text("内核态捕获")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ArenaTheme.textTertiary)
                    }

                    if activeTarget.processTree.isEmpty {
                        Text("尚未在靶机容器内捕获到子进程派生链，触发 RCE 或命令执行后将实时展示。")
                            .font(.system(size: 12))
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(activeTarget.processTree.enumerated()), id: \.offset) { idx, proc in
                                let suspicious = proc.contains("/bin/sh") || proc.contains("bash") || proc.contains("uid=0")
                                HStack(spacing: 8) {
                                    Text(String(repeating: "  ", count: idx) + (idx == 0 ? "•" : "└─"))
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(ArenaTheme.textQuaternary)
                                    Text(proc)
                                        .font(.system(size: 12, weight: suspicious ? .semibold : .regular, design: .monospaced))
                                        .foregroundStyle(suspicious ? ArenaTheme.danger : ArenaTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(suspicious ? ArenaTheme.danger.opacity(0.08) : Color(red: 0.968, green: 0.971, blue: 0.980))
                                )
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .arenaCard(radius: 20)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(
                            diffText != nil && !(diffText?.isEmpty ?? true)
                                ? "实时源码热补丁 (Git Unified Diff)"
                                : "容器真实业务源码定位",
                            systemImage: "chevron.left.forwardslash.chevron.right"
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArenaTheme.textPrimary)
                        Spacer()
                        if !activeTarget.hitLocation.isEmpty {
                            Text(activeTarget.hitLocation)
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(ArenaTheme.appleBlue)
                        }
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            if let diff = diffText, !diff.isEmpty {
                                ForEach(Array(diff.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, raw in
                                    let line = String(raw)
                                    let kind: DiffLineKind = line.hasPrefix("-") && !line.hasPrefix("---")
                                        ? .removed
                                        : (line.hasPrefix("+") && !line.hasPrefix("+++") ? .added : .context)
                                    codeDiffLine(line, kind: kind)
                                }
                            } else if !activeTarget.codeExcerpt.isEmpty {
                                ForEach(activeTarget.codeExcerpt) { row in
                                    let kind: DiffLineKind = row.tag == "vulnerable"
                                        ? .removed
                                        : (row.tag == "patched" ? .added : .context)
                                    codeDiffLine(String(format: "%3d  %@", row.line, row.code), kind: kind)
                                }
                            } else {
                                Text("等待从靶机容器加载真实业务源码或热补丁变更记录…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ArenaTheme.textTertiary)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(10)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.968, green: 0.971, blue: 0.980))
                    )
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .arenaCard(radius: 20)
            }
            .frame(width: 440)
        }
    }

    private enum DiffLineKind { case context, removed, added }

    private func codeDiffLine(_ text: String, kind: DiffLineKind) -> some View {
        let fg: Color = switch kind {
        case .context: ArenaTheme.textSecondary
        case .removed: ArenaTheme.danger
        case .added: ArenaTheme.success
        }
        let bg: Color = switch kind {
        case .context: Color.clear
        case .removed: ArenaTheme.danger.opacity(0.09)
        case .added: ArenaTheme.success.opacity(0.10)
        }
        return Text(text)
            .font(.system(size: 11.5, weight: kind == .context ? .regular : .medium, design: .monospaced))
            .foregroundStyle(fg)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(bg))
    }

    // MARK: - 3C. View 3: Safari-Framed Live Target Web Telemetry & Real Ghost Cursors

    private var webHijackStage: some View {
        let hijack = pit.match.webHijacks.first
        let urlDisplay = hijack?.targetUrl
            ?? (activeTarget.webUrl.isEmpty ? "等待靶机容器网络就绪" : activeTarget.webUrl)
        let capturedPayload = hijack?.injectedInput
            ?? pit.match.events.first?.cleartextPayload
            ?? ""

        return HStack(spacing: 14) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "FF5F57")).frame(width: 10, height: 10)
                        Circle().fill(Color(hex: "FEBC2E")).frame(width: 10, height: 10)
                        Circle().fill(Color(hex: "28C840")).frame(width: 10, height: 10)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(ArenaTheme.warning)
                        Text(urlDisplay)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ArenaTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(hijack != nil ? "Web Telemetry 已捕获" : "等待 HTTP 载荷")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(ArenaTheme.appleBlue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.045)))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color(red: 0.962, green: 0.965, blue: 0.975))

                Divider()

                ZStack(alignment: .topLeading) {
                    Color.white

                    VStack(alignment: .leading, spacing: 16) {
                        if let banner = hijack?.defaceBanner, !banner.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                Text(banner)
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                            }
                            .foregroundStyle(ArenaTheme.danger)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.danger.opacity(0.09)))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ArenaTheme.danger.opacity(0.24), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeTarget.name.isEmpty ? pit.match.mapName : activeTarget.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(ArenaTheme.textPrimary)
                            Text("靶机真实业务入口遥测 · 仅展示宿主机内核 uprobe 与引擎捕获到的真实请求载荷")
                                .font(.system(size: 12.5))
                                .foregroundStyle(ArenaTheme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("最近捕获的请求 / 注入载荷 (Captured Request / Payload)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ArenaTheme.textTertiary)
                            if capturedPayload.isEmpty {
                                Text("尚未捕获到面向目标 Web 服务的请求载荷，容器发起请求后将在此实时显示。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ArenaTheme.textTertiary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.968, green: 0.971, blue: 0.980)))
                            } else {
                                Text(capturedPayload)
                                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(ArenaTheme.danger)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.985, green: 0.955, blue: 0.958)))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ArenaTheme.danger.opacity(0.25), lineWidth: 1))
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("靶机业务健康与响应遥测 (Server Health & DOM Telemetry)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ArenaTheme.textTertiary)
                            let statusSummary = hijack?.domMutation
                                ?? (activeTarget.healthy
                                    ? "HTTP 200 OK · 业务语义 SLA \(Int(activeTarget.slaScore))% 正常"
                                    : "🚨 SLA HEARTBEAT FLATLINE · 靶机业务接口响应异常")
                            let tint: Color = !activeTarget.healthy
                                ? ArenaTheme.danger
                                : (hijack?.domMutation != nil ? ArenaTheme.grailGold : ArenaTheme.success)
                            Text(statusSummary)
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(tint)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.24), lineWidth: 1))
                        }

                        Spacer()
                    }
                    .padding(24)

                    GeometryReader { geo in
                        ForEach(pit.match.webHijacks.prefix(3)) { item in
                            HStack(spacing: 4) {
                                Image(systemName: "cursorarrow")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: item.attackerColor))
                                Text(item.attackerName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color(hex: item.attackerColor)))
                                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                            }
                            .position(
                                x: max(70, min(geo.size.width - 90, geo.size.width * item.cursorX)),
                                y: max(60, min(geo.size.height - 50, geo.size.height * item.cursorY))
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .arenaCard(radius: 20)

            // Right: Web Hijack Log
            VStack(alignment: .leading, spacing: 12) {
                Label("网页交互与注入记录", systemImage: "cursorarrow.motionlines")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textPrimary)

                if pit.match.webHijacks.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "cursorarrow.rays")
                            .font(.system(size: 22))
                            .foregroundStyle(ArenaTheme.appleBlue.opacity(0.55))
                        Text("暂无网页劫持记录")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Text("当参战智能体向目标 Web 端点发送注入载荷时将实时归档。")
                            .font(.system(size: 11))
                            .foregroundStyle(ArenaTheme.textTertiary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(pit.match.webHijacks) { item in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Circle().fill(Color(hex: item.attackerColor)).frame(width: 7, height: 7)
                                        Text(item.attackerName)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(ArenaTheme.textPrimary)
                                        Spacer()
                                        Text(String(format: "(%.2f, %.2f)", item.cursorX, item.cursorY))
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(ArenaTheme.textTertiary)
                                    }
                                    Text(item.injectedInput)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(ArenaTheme.appleBlue)
                                        .lineLimit(2)
                                    if !item.domMutation.isEmpty {
                                        Text(item.domMutation)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(ArenaTheme.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(11)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.968, green: 0.971, blue: 0.980)))
                            }
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: 316)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .arenaCard(radius: 20)
        }
    }

    // MARK: - 4. Xcode-Light Bottom Inspector Drawer (`Space` Toggle: Terminal + eBPF + Git Diff)

    private var inspectorDrawer: some View {
        let latestPatch = pit.match.patches.first

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("底层检视与人工接管台", systemImage: "wrench.and.screwdriver.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pit.match.seats) { seat in
                            let selected = seat.id == activeSeat.id
                            Button {
                                pit.focusedSeatID = seat.id
                            } label: {
                                HStack(spacing: 5) {
                                    Circle().fill(Color(hex: seat.teamColor)).frame(width: 6, height: 6)
                                    Text(seat.name)
                                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                                }
                                .foregroundStyle(selected ? ArenaTheme.appleBlue : ArenaTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(selected ? ArenaTheme.appleBlue.opacity(0.11) : Color.black.opacity(0.04)))
                            }
                            .buttonStyle(PressStyle(scale: 0.96))
                        }
                    }
                }

                Spacer()

                Button {
                    withAnimation(Motion.disclosure) { pit.visorOpen = false }
                } label: {
                    HStack(spacing: 4) {
                        Text("收起 (Space)")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Capsule().fill(Color.black.opacity(0.05)))
                }
                .buttonStyle(PressStyle(scale: 0.96))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.962, green: 0.965, blue: 0.975))

            Divider()

            HStack(spacing: 12) {
                // Panel 1: Terminal & Human Possession
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("容器终端 · 人工接管 (\(activeSeat.name))", systemImage: "terminal.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Spacer()
                        Button {
                            Task { await pit.togglePossess(seatID: activeSeat.id) }
                        } label: {
                            Text(activeSeat.possessed ? "交还给 AI" : "人工接管终端")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(activeSeat.possessed ? .white : ArenaTheme.appleBlue)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(activeSeat.possessed ? ArenaTheme.appleBlue : ArenaTheme.appleBlue.opacity(0.11)))
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            if activeSeat.terminalLines.isEmpty {
                                Text("等待该席位容器输出命令日志…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ArenaTheme.textTertiary)
                                    .padding(.vertical, 18)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(Array(activeSeat.terminalLines.suffix(10).enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(line.hasPrefix("$") ? ArenaTheme.appleBlue : ArenaTheme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.968, green: 0.971, blue: 0.980)))

                    HStack(spacing: 6) {
                        Text("$")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(ArenaTheme.appleBlue)
                        TextField("输入容器命令，如 id 或 cat /flag", text: $commandInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(ArenaTheme.textPrimary)
                            .onSubmit {
                                let cmd = commandInput
                                commandInput = ""
                                Task { await pit.sendTerminalCommand(seatID: activeSeat.id, command: cmd) }
                            }
                        AppleOpenPill(title: "执行", active: true) {
                            let cmd = commandInput
                            commandInput = ""
                            Task { await pit.sendTerminalCommand(seatID: activeSeat.id, command: cmd) }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.black.opacity(0.04)))
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Panel 2: eBPF Syscalls & OpenSSL Cleartext
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("eBPF 系统调用与 TLS 明文包", systemImage: "cpu")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Spacer()
                        Text("宿主机零侵入")
                            .font(.system(size: 10.5))
                            .foregroundStyle(ArenaTheme.success)
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            if pit.match.events.isEmpty {
                                Text("等待宿主机 RingBuf 推送容器系统调用事件…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ArenaTheme.textTertiary)
                                    .padding(.vertical, 24)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(pit.match.events.prefix(6)) { ev in
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(ev.probe)
                                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                                .foregroundStyle(ArenaTheme.appleBlue)
                                            Spacer()
                                            let latStr = ev.kernelLatencyNs.map { String(format: " · %.1fµs", Double($0) / 1000.0) } ?? ""
                                            Text("PID \(ev.pid) · uid=\(ev.uid)\(latStr)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(ArenaTheme.textTertiary)
                                        }
                                        Text(ev.cmdline)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(ArenaTheme.textPrimary)
                                            .lineLimit(1)
                                        if let clear = ev.cleartextPayload, !clear.isEmpty {
                                            Text(clear)
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(ArenaTheme.thoughtViolet)
                                                .lineLimit(2)
                                                .padding(5)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(RoundedRectangle(cornerRadius: 6).fill(ArenaTheme.thoughtViolet.opacity(0.07)))
                                        }
                                    }
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(red: 0.968, green: 0.971, blue: 0.980)))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Panel 3: Real Git Diff Live Patch
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Git Diff 实时源码热补丁", systemImage: "bandage.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary)
                        Spacer()
                        Text(latestPatch?.filePath ?? "暂无补丁")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(latestPatch != nil ? ArenaTheme.appleBlue : ArenaTheme.textTertiary)
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            if let patch = latestPatch, !patch.diff.isEmpty {
                                ForEach(Array(patch.diff.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, raw in
                                    let line = String(raw)
                                    let kind: DiffLineKind = line.hasPrefix("-") && !line.hasPrefix("---")
                                        ? .removed
                                        : (line.hasPrefix("+") && !line.hasPrefix("+++") ? .added : .context)
                                    codeDiffLine(line, kind: kind)
                                }
                            } else {
                                Text("等待智能体或人工提交首个 Git 源码热补丁…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ArenaTheme.textTertiary)
                                    .padding(.vertical, 28)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(6)
                    }
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.968, green: 0.971, blue: 0.980)))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(Color.white)
        }
        .frame(height: 278)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 22, y: -4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - 5. Bottom AI Caster & Human Action Bar

    private var bottomCasterAndActionBar: some View {
        let caster = pit.match.casterLines.first
        let fallbackCaster = pit.match.isCompleted
            ? "🏁 本局对决已完赛结算，点击右侧可导出单文件 .pitreplay.html 独立战局录像。"
            : "等待容器攻防事件触发 AI 实时解说…"

        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: pit.match.isCompleted ? "flag.checkered" : "waveform")
                    .font(.system(size: 11, weight: .bold))
                Text(pit.match.isCompleted ? "终局播报" : "AI 实时解说")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(pit.match.isCompleted ? ArenaTheme.success : ArenaTheme.appleBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill((pit.match.isCompleted ? ArenaTheme.success : ArenaTheme.appleBlue).opacity(0.10)))

            Text(caster?.text ?? fallbackCaster)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(ArenaTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if !pit.match.isCompleted {
                GhostButton(
                    title: activeSeat.possessed ? "结束接管 (\(activeSeat.name))" : "接管终端 (\(activeSeat.name))",
                    systemImage: "person.badge.key.fill",
                    tint: activeSeat.possessed ? ArenaTheme.appleBlue : ArenaTheme.textPrimary
                ) {
                    pit.visorOpen = true
                    Task { await pit.togglePossess(seatID: activeSeat.id) }
                }

                Button {
                    showHintPopover.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                        Text("发送提示")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(ArenaTheme.grailGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(ArenaTheme.grailGold.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(ArenaTheme.grailGold.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(PressStyle(scale: 0.96))
                .popover(isPresented: $showHintPopover) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("向「\(activeSeat.name)」发送战术提示")
                            .font(.system(size: 13, weight: .semibold))
                        TextField("输入漏洞位置或修复建议…", text: $hintInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                        HStack {
                            Spacer()
                            AccentButton(title: "发送提示", systemImage: "paperplane.fill") {
                                let h = hintInput
                                hintInput = ""
                                showHintPopover = false
                                Task { await pit.dropHint(seatID: activeSeat.id, hint: h) }
                            }
                        }
                    }
                    .padding(14)
                }
            }

            AccentButton(title: "导出独立录像 (.html)", systemImage: "square.and.arrow.up") {
                Task {
                    let url = URL(fileURLWithPath: NSHomeDirectory())
                        .appendingPathComponent("Downloads/pit-\(pit.match.id).pitreplay.html")
                    _ = try? await pit.exportReplayHTML(to: url, openInBrowser: true)
                    app.show(ActivityBanner(text: "已导出独立战局录像并在浏览器打开", success: true))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .arenaCard(radius: 16)
    }
}

// MARK: - Helper on PitClient for Sidebar Toggle Label

private extension PitClient {
    func hudSidebarHintTitle(collapsed: Bool) -> String {
        collapsed ? "展开左侧导航栏" : "收起左侧导航栏 (宽屏模式)"
    }
}

// MARK: - Clean Apple Contestant Scorecard (SLA ECG + Token Progress)

private struct AppleContestantHUDCard: View {
    let rank: Int
    let seat: PitSeat
    let focused: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("#\(rank)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(rank == 1 ? .white : ArenaTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(rank == 1 ? ArenaTheme.appleBlue : Color.black.opacity(0.06))
                    )

                Text(seat.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .lineLimit(1)

                if seat.holdsGrail {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArenaTheme.grailGold)
                }

                Spacer(minLength: 2)

                Text("\(seat.score)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ArenaTheme.textPrimary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Canvas { ctx, size in
                    let samples = seat.ecgSamples.isEmpty ? [0, 0.1, -0.08, 0.9, -0.4, 0.15, 0] : seat.ecgSamples
                    var path = Path()
                    let midY = size.height * 0.56
                    for i in 0..<28 {
                        let x = CGFloat(i) / 27.0 * size.width
                        let sample = seat.slaHealthy ? samples[i % samples.count] : 0.0
                        let y = midY - CGFloat(sample) * (size.height * 0.42)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(
                        path,
                        with: .color(seat.slaHealthy ? ArenaTheme.ecgEmerald : ArenaTheme.danger),
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 18)

                Text(seat.slaHealthy ? "SLA \(Int(seat.slaScore))%" : "FLATLINE")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(seat.slaHealthy ? ArenaTheme.ecgEmerald : ArenaTheme.danger)
            }

            if seat.outOfMana {
                Text("HTTP 402 · Token 额度耗尽停机")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ArenaTheme.danger))
            } else {
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.06))
                            Capsule()
                                .fill(ArenaTheme.appleBlue)
                                .frame(width: max(4, geo.size.width * seat.manaFraction))
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("剩余 \(Int(seat.manaRemainingPct))%")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(ArenaTheme.appleBlue)
                        Spacer()
                        Text(seat.tokensFormatted)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(ArenaTheme.textTertiary)
                    }
                }
            }

            Text(seat.thought.isEmpty ? "等待下一轮决策…" : seat.thought)
                .font(.system(size: 10.5))
                .foregroundStyle(ArenaTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(focused || hovering ? 0.085 : 0.04), radius: 10, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            !seat.slaHealthy || seat.outOfMana
                                ? ArenaTheme.danger.opacity(0.45)
                                : (focused ? ArenaTheme.appleBlue.opacity(0.65) : Color.black.opacity(0.06)),
                            lineWidth: focused ? 1.5 : 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
        .pointerCursor()
    }
}

// MARK: - Combo Synergy Helper + Mode-Aware Daylight Colosseum Radar Canvas

private func activeMacComboBanner(projectiles: [PitLiveProjectile], seats: [PitSeat]) -> String? {
    let distinctTypes = Set(projectiles.map { $0.vfxType })
    let distinctSeats = Set(projectiles.map { $0.sourceSeatId })
    if distinctTypes.contains(.rceParasiteBreach) && distinctTypes.contains(.reverseShellChain) {
        return "COMBO ×3 · 寄生弑神链激活"
    }
    if distinctTypes.contains(.grailHeartStolen) && distinctTypes.contains(.nanoPatchWeld) {
        return "COMBO ×2 · 👑 王权铁幕展开"
    }
    if distinctSeats.count >= 2 && projectiles.count >= 3 {
        let names = distinctSeats.prefix(2).compactMap { sid in seats.first(where: { $0.id == sid })?.name }
        return "CROSSFIRE ×\(distinctSeats.count) · \(names.joined(separator: " × ")) 立体合围"
    }
    if distinctTypes.count >= 2 {
        return "COMBO ×\(distinctTypes.count) · 多维命令组合连击"
    }
    return nil
}

private struct DaylightColosseumRadarCanvas: View {
    let mode: PitGameMode
    let round: Int
    let maxRounds: Int
    let isRunning: Bool
    let isCompleted: Bool
    let seats: [PitSeat]
    let targets: [PitTarget]
    let primaryTarget: PitTarget
    let projectiles: [PitLiveProjectile]
    let focusedSeatID: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isRunning)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let bgRect = CGRect(origin: .zero, size: size)
                ctx.fill(
                    Path(bgRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.988, green: 0.991, blue: 0.998),
                            Color(red: 0.950, green: 0.958, blue: 0.978)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                // Safe inset bounds so bottom seat labels NEVER clip against the bottom Kernel Dock!
                let safeTop: CGFloat = isCompleted ? 78 : 56
                let safeBottom: CGFloat = 64
                let usableH = max(140, size.height - safeTop - safeBottom)
                let center = CGPoint(x: size.width * 0.5, y: safeTop + usableH * 0.49)
                let maxR = max(44, min(size.width * 0.35, usableH * 0.41))

                let stepPx: CGFloat = 34
                var gx: CGFloat = 18
                while gx < size.width {
                    var gy: CGFloat = 18
                    while gy < size.height {
                        ctx.fill(Path(CGRect(x: gx, y: gy, width: 1.2, height: 1.2)), with: .color(Color.black.opacity(0.042)))
                        gy += stepPx
                    }
                    gx += stepPx
                }

                for step in [1.0, 0.74, 0.48, 0.24] {
                    let r = maxR * step
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    ctx.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color.black.opacity(step == 1.0 ? 0.08 : 0.045)),
                        style: StrokeStyle(lineWidth: 1, dash: step == 0.74 ? [5, 5] : [])
                    )
                }

                // Mode-Aware Seat & Target Coordinates
                var seatPoints: [String: CGPoint] = [:]
                var seatAngles: [String: Double] = [:]
                let count = max(1, seats.count)
                let isMultiFortress = (mode == .awd || mode == .speedrun) && targets.count > 1

                if mode == .lastStand && seats.count > 1 {
                    let defender = seats[0]
                    seatPoints[defender.id] = CGPoint(x: center.x, y: center.y + maxR * 0.90)
                    seatAngles[defender.id] = .pi / 2
                    let besiegers = Array(seats.dropFirst())
                    for (bIdx, seat) in besiegers.enumerated() {
                        let span = Double.pi * 1.25
                        let ang = besiegers.count == 1
                            ? -Double.pi / 2
                            : -Double.pi / 2 - span * 0.5 + (Double(bIdx) / Double(besiegers.count - 1)) * span
                        seatPoints[seat.id] = CGPoint(
                            x: center.x + CGFloat(cos(ang)) * maxR,
                            y: center.y + CGFloat(sin(ang)) * maxR
                        )
                        seatAngles[seat.id] = ang
                    }
                } else {
                    for (i, seat) in seats.enumerated() {
                        // 2-seat matches sit cleanly Left (180°) & Right (0°) with wide horizontal breathing room
                        let angle = count == 2
                            ? (i == 0 ? Double.pi : 0.0)
                            : (-Double.pi / 2 + (2 * Double.pi * Double(i) / Double(count)))
                        let pt = CGPoint(
                            x: center.x + CGFloat(cos(angle)) * maxR,
                            y: center.y + CGFloat(sin(angle)) * maxR
                        )
                        seatPoints[seat.id] = pt
                        seatAngles[seat.id] = angle
                    }
                }

                var targetPoints: [String: CGPoint] = [:]
                if isMultiFortress {
                    let innerFortR = maxR * 0.47
                    for (idx, tg) in targets.enumerated() {
                        let ang = tg.ownerSeatId.flatMap { seatAngles[$0] }
                            ?? (-Double.pi / 2 + (2 * Double.pi * Double(idx) / Double(max(1, targets.count))))
                        let tPt = CGPoint(
                            x: center.x + CGFloat(cos(ang)) * innerFortR,
                            y: center.y + CGFloat(sin(ang)) * innerFortR
                        )
                        targetPoints[tg.id] = tPt
                        if let ownerID = tg.ownerSeatId,
                           let sPt = seatPoints[ownerID],
                           let ownerSeat = seats.first(where: { $0.id == ownerID }) {
                            var tether = Path()
                            tether.move(to: sPt)
                            tether.addLine(to: tPt)
                            ctx.stroke(
                                tether,
                                with: .color(Color(hex: ownerSeat.teamColor).opacity(0.32)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                            )
                        }
                    }
                } else {
                    targetPoints[primaryTarget.id] = center
                    for pt in seatPoints.values {
                        var spoke = Path()
                        spoke.move(to: pt)
                        spoke.addLine(to: center)
                        ctx.stroke(spoke, with: .color(Color.black.opacity(0.04)), lineWidth: 1)
                    }
                }

                // Flowing Golden Grail Sovereignty Conduit when a King holds the Grail
                if mode == .grail,
                   let king = seats.first(where: \.holdsGrail),
                   let kp = seatPoints[king.id] {
                    var glow = Path()
                    glow.move(to: center)
                    glow.addLine(to: kp)
                    ctx.stroke(glow, with: .color(ArenaTheme.grailGold.opacity(0.18)), style: StrokeStyle(lineWidth: 9, lineCap: .round))

                    var line = Path()
                    line.move(to: center)
                    line.addLine(to: kp)
                    ctx.stroke(line, with: .color(ArenaTheme.grailGold.opacity(0.58)), style: StrokeStyle(lineWidth: 1.8, dash: [6, 4]))
                }

                // Hexagonal Aegis Shield Dome if central target is patched
                if !isMultiFortress && primaryTarget.organs.contains(where: { $0.patched }) {
                    let domeR: CGFloat = 72
                    let rot = isRunning ? now * 0.5 : 0.0
                    var hex = Path()
                    for i in 0..<6 {
                        let a = rot + Double(i) * Double.pi / 3.0
                        let p = CGPoint(x: center.x + CGFloat(cos(a)) * domeR, y: center.y + CGFloat(sin(a)) * domeR)
                        if i == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
                    }
                    hex.closeSubpath()
                    ctx.fill(hex, with: .color(ArenaTheme.appleBlue.opacity(0.06)))
                    ctx.stroke(hex, with: .color(ArenaTheme.appleBlue.opacity(0.55)), lineWidth: 2)
                }

                // Render active per-command projectiles routed to exact Target Fortress (`targetPoints[proj.targetId]`)
                var deferredBeamTags: [(CGPoint, PitVFXType, String)] = []
                if isRunning {
                    var drawnLabelKeys = Set<String>()
                    for proj in projectiles {
                        guard let from = seatPoints[proj.sourceSeatId] else { continue }
                        let dest = targetPoints[proj.targetId] ?? center
                        let progress = min(1.0, max(0.0, (now - proj.createdAt) / max(0.5, proj.duration)))
                        let dx = dest.x - from.x
                        let dy = dest.y - from.y
                        let angle = atan2(dy, dx)
                        let perp = CGPoint(x: -sin(angle), y: cos(angle))

                        switch proj.vfxType {
                        case .sonarSweep:
                            let dist = hypot(dx, dy)
                            var cone = Path()
                            cone.move(to: from)
                            let baseDeg = Angle(radians: Double(angle))
                            let sweepOff = Angle(radians: sin(now * 6) * 0.25)
                            cone.addArc(center: from, radius: dist * CGFloat(min(1, progress * 1.4)), startAngle: baseDeg - .radians(0.32) + sweepOff, endAngle: baseDeg + .radians(0.32) + sweepOff, clockwise: false)
                            cone.closeSubpath()
                            ctx.fill(cone, with: .color(Color(hex: "0284C7").opacity(0.14)))
                            for phase in [0.0, 0.33, 0.66] {
                                let wt = CGFloat((progress * 1.6 + phase).truncatingRemainder(dividingBy: 1.0))
                                let wr = 20 + wt * 44
                                ctx.stroke(Path(ellipseIn: CGRect(x: dest.x - wr, y: dest.y - wr, width: wr * 2, height: wr * 2)), with: .color(Color(hex: "0284C7").opacity(Double(1 - wt) * 0.55)), lineWidth: 1.8)
                            }

                        case .armorPiercingBarrage:
                            for (idx, spread) in [-46.0, -23.0, 0.0, 23.0, 46.0].enumerated() {
                                let mt = CGFloat(min(1.0, max(0.0, progress * 1.45 - Double(idx) * 0.06)))
                                if mt <= 0 { continue }
                                let ctrl = CGPoint(x: (from.x + dest.x) * 0.5 + perp.x * CGFloat(spread), y: (from.y + dest.y) * 0.5 + perp.y * CGFloat(spread))
                                var arc = Path()
                                arc.move(to: from)
                                arc.addQuadCurve(to: dest, control: ctrl)
                                ctx.stroke(arc, with: .color(Color(hex: "EA580C").opacity(0.24)), lineWidth: 1.4)
                                let oneMinus = 1 - mt
                                let mx = oneMinus * oneMinus * from.x + 2 * oneMinus * mt * ctrl.x + mt * mt * dest.x
                                let my = oneMinus * oneMinus * from.y + 2 * oneMinus * mt * ctrl.y + mt * mt * dest.y
                                ctx.fill(Path(ellipseIn: CGRect(x: mx - 3.5, y: my - 3.5, width: 7, height: 7)), with: .color(idx % 2 == 0 ? Color(hex: "EA580C") : ArenaTheme.grailGold))
                            }

                        case .sslCleartextIntercept:
                            var strandA = Path()
                            var strandB = Path()
                            let steps = 24
                            for i in 0...steps {
                                let f = CGFloat(i) / CGFloat(steps) * CGFloat(min(1.0, progress * 1.4))
                                let wave = sin(f * .pi * 5 - CGFloat(now * 10)) * 12 * sin(f * .pi)
                                let bx = from.x + dx * f
                                let by = from.y + dy * f
                                let pa = CGPoint(x: bx + perp.x * wave, y: by + perp.y * wave)
                                let pb = CGPoint(x: bx - perp.x * wave, y: by - perp.y * wave)
                                if i == 0 { strandA.move(to: pa); strandB.move(to: pb) }
                                else { strandA.addLine(to: pa); strandB.addLine(to: pb) }
                            }
                            ctx.stroke(strandA, with: .color(Color(hex: "9333EA")), lineWidth: 2.2)
                            ctx.stroke(strandB, with: .color(Color(hex: "EC4899")), lineWidth: 2.2)

                        case .rceParasiteBreach:
                            var bolt = Path()
                            bolt.move(to: from)
                            let segs = 10
                            for i in 1..<segs {
                                let f = CGFloat(i) / CGFloat(segs)
                                let jit = sin(CGFloat(now * 28) + CGFloat(i) * 5.2) * 14 * sin(f * .pi)
                                bolt.addLine(to: CGPoint(x: from.x + dx * f + perp.x * jit, y: from.y + dy * f + perp.y * jit))
                            }
                            bolt.addLine(to: dest)
                            ctx.stroke(bolt, with: .color(ArenaTheme.danger.opacity(0.45)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round))
                            ctx.stroke(bolt, with: .color(.white), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                        case .reverseShellChain:
                            var chain = Path()
                            chain.move(to: dest)
                            chain.addLine(to: from)
                            ctx.stroke(chain, with: .color(ArenaTheme.danger.opacity(0.85)), style: StrokeStyle(lineWidth: 2.5, dash: [7, 5], dashPhase: CGFloat(now * 40)))
                            for ph in [0.0, 0.33, 0.66] {
                                let frac = CGFloat((now * 0.9 + ph).truncatingRemainder(dividingBy: 1.0))
                                let gx = dest.x + (from.x - dest.x) * frac
                                let gy = dest.y + (from.y - dest.y) * frac
                                ctx.fill(Path(CGRect(x: gx - 4, y: gy - 4, width: 8, height: 8)), with: .color(ArenaTheme.grailGold))
                            }

                        case .grailHeartStolen:
                            var tractor = Path()
                            tractor.move(to: dest)
                            tractor.addLine(to: from)
                            ctx.stroke(tractor, with: .color(ArenaTheme.grailGold.opacity(0.42)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            let ease = CGFloat(min(1.0, progress * 1.25))
                            let cxG = dest.x + (from.x - dest.x) * ease
                            let cyG = dest.y + (from.y - dest.y) * ease
                            var diamond = Path()
                            diamond.move(to: CGPoint(x: cxG, y: cyG - 10))
                            diamond.addLine(to: CGPoint(x: cxG + 7, y: cyG))
                            diamond.addLine(to: CGPoint(x: cxG, y: cyG + 10))
                            diamond.addLine(to: CGPoint(x: cxG - 7, y: cyG))
                            diamond.closeSubpath()
                            ctx.fill(diamond, with: .color(Color(hex: "FEF3C7")))
                            ctx.stroke(diamond, with: .color(ArenaTheme.grailGold), lineWidth: 2)

                        case .rootShockwave:
                            let rWave = CGFloat(progress) * maxR * 0.85
                            ctx.stroke(Path(ellipseIn: CGRect(x: dest.x - rWave, y: dest.y - rWave, width: rWave * 2, height: rWave * 2)), with: .color(ArenaTheme.danger.opacity(1 - progress)), lineWidth: 3)
                            var beam = Path()
                            beam.move(to: from)
                            beam.addLine(to: dest)
                            ctx.stroke(beam, with: .color(ArenaTheme.grailGold), lineWidth: 2.8)

                        case .nanoPatchWeld:
                            var beam = Path()
                            beam.move(to: from)
                            beam.addLine(to: dest)
                            ctx.stroke(beam, with: .color(ArenaTheme.appleBlue), lineWidth: 2.6)

                        case .precisionExploitBeam:
                            let reach = CGFloat(min(1.0, progress * 1.35))
                            for side in [-4.0, 4.0] as [CGFloat] {
                                let sx = from.x + perp.x * side
                                let sy = from.y + perp.y * side
                                let hx = sx + dx * reach
                                let hy = sy + dy * reach
                                var dart = Path()
                                dart.move(to: CGPoint(x: sx, y: sy))
                                dart.addLine(to: CGPoint(x: hx, y: hy))
                                ctx.stroke(dart, with: .color(ArenaTheme.appleBlue), lineWidth: 2.0)
                                ctx.fill(Path(ellipseIn: CGRect(x: hx - 3, y: hy - 3, width: 6, height: 6)), with: .color(ArenaTheme.appleBlue))
                            }
                        }

                        let lk = proj.sourceSeatId
                        if !drawnLabelKeys.contains(lk) {
                            drawnLabelKeys.insert(lk)
                            let off: CGFloat = sin(angle) >= 0 ? -18 : 18
                            let mid = CGPoint(x: from.x + dx * 0.40 + perp.x * off, y: from.y + dy * 0.40 + perp.y * off)
                            deferredBeamTags.append((mid, proj.vfxType, proj.label))
                        }
                    }
                }

                // Render Mode-Accurate Target Nodes
                if isMultiFortress {
                    let hubR: CGFloat = 30
                    let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
                    ctx.fill(Path(ellipseIn: hubRect), with: .color(.white))
                    ctx.stroke(Path(ellipseIn: hubRect), with: .color(ArenaTheme.appleBlue.opacity(0.24)), lineWidth: 1.4)
                    ctx.draw(
                        Text(mode == .awd ? "AWD 裁判塔" : "竞速计时塔")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(ArenaTheme.textPrimary),
                        at: CGPoint(x: center.x, y: center.y - 5)
                    )
                    ctx.draw(
                        Text("R\(round)/\(maxRounds)")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ArenaTheme.appleBlue),
                        at: CGPoint(x: center.x, y: center.y + 7)
                    )

                    for tg in targets {
                        guard let tPt = targetPoints[tg.id] else { continue }
                        let owner = tg.ownerSeatId.flatMap { oid in seats.first(where: { $0.id == oid }) }
                        let fR: CGFloat = 33
                        let fRect = CGRect(x: tPt.x - fR, y: tPt.y - fR, width: fR * 2, height: fR * 2)
                        ctx.fill(Path(ellipseIn: fRect), with: .color(.white))
                        for (idx, organ) in tg.organs.prefix(5).enumerated() {
                            let rr = 31 - CGFloat(idx) * 2.4
                            let rRect = CGRect(x: tPt.x - rr, y: tPt.y - rr, width: rr * 2, height: rr * 2)
                            let rCol = organ.compromised ? ArenaTheme.danger : (organ.patched ? ArenaTheme.appleBlue : ArenaTheme.ecgEmerald.opacity(0.55))
                            ctx.stroke(Path(ellipseIn: rRect), with: .color(rCol), lineWidth: 1.4)
                        }
                        let innerR: CGFloat = 19
                        let innerRect = CGRect(x: tPt.x - innerR, y: tPt.y - innerR, width: innerR * 2, height: innerR * 2)
                        ctx.fill(Path(ellipseIn: innerRect), with: .color(.white))
                        ctx.draw(
                            Text("\(Int(tg.slaScore))%")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(tg.healthy ? ArenaTheme.ecgEmerald : ArenaTheme.danger),
                            at: CGPoint(x: tPt.x, y: tPt.y)
                        )
                        let shortName = owner.map { mode == .speedrun ? "\($0.name) 靶舱" : "\($0.name) 堡垒" } ?? tg.name
                        let fortTag = ctx.resolve(
                            Text(shortName)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(ArenaTheme.textPrimary)
                        )
                        let fSize = fortTag.measure(in: CGSize(width: 140, height: 20))
                        let tagY = tPt.y - fR - 11
                        let tagRect = CGRect(
                            x: tPt.x - fSize.width * 0.5 - 7,
                            y: tagY - fSize.height * 0.5 - 2.5,
                            width: fSize.width + 14,
                            height: fSize.height + 5
                        )
                        ctx.fill(Path(roundedRect: tagRect, cornerRadius: 8), with: .color(Color.white.opacity(0.94)))
                        ctx.stroke(Path(roundedRect: tagRect, cornerRadius: 8), with: .color(Color.black.opacity(0.07)), lineWidth: 1)
                        ctx.draw(fortTag, at: CGPoint(x: tPt.x, y: tagY))
                    }
                } else {
                    let coreR: CGFloat = 62
                    let coreRect = CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
                    ctx.fill(Path(ellipseIn: coreRect), with: .color(.white))
                    for (idx, organ) in primaryTarget.organs.prefix(5).enumerated() {
                        let rr = 60 - CGFloat(idx) * 3.8
                        let rRect = CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2)
                        let rCol = organ.compromised ? ArenaTheme.danger : (organ.patched ? ArenaTheme.appleBlue : ArenaTheme.ecgEmerald.opacity(0.55))
                        ctx.stroke(Path(ellipseIn: rRect), with: .color(rCol), lineWidth: organ.compromised || organ.patched ? 2.0 : 1.3)
                    }
                    let innerR: CGFloat = 41
                    let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
                    ctx.fill(Path(ellipseIn: innerRect), with: .color(.white))
                    ctx.stroke(Path(ellipseIn: innerRect), with: .color(ArenaTheme.appleBlue.opacity(0.16)), lineWidth: 1)

                    let centerLabel = mode == .lastStand
                        ? "人类防线堡垒"
                        : (mode == .grail ? "中央圣杯堡垒" : primaryTarget.name)
                    ctx.draw(
                        Text(centerLabel)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(ArenaTheme.textPrimary),
                        at: CGPoint(x: center.x, y: primaryTarget.hitLocation.isEmpty ? center.y : center.y - 6)
                    )
                    if !primaryTarget.hitLocation.isEmpty {
                        ctx.draw(
                            Text(primaryTarget.hitLocation)
                                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(ArenaTheme.appleBlue),
                            at: CGPoint(x: center.x, y: center.y + 8)
                        )
                    }
                }

                // Gladiator Seat Nodes
                for seat in seats {
                    guard let pt = seatPoints[seat.id] else { continue }
                    let r: CGFloat = 23
                    let nodeRect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                    let ringColor = seat.outOfMana ? ArenaTheme.danger : Color(hex: seat.teamColor)

                    if seat.holdsGrail {
                        let hr = r + 6.5
                        ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - hr, y: pt.y - hr, width: hr * 2, height: hr * 2)), with: .color(ArenaTheme.grailGold.opacity(0.65)), lineWidth: 2.2)
                    }
                    if !seat.outOfMana && isRunning {
                        let orbitR = r + 9.5
                        for e in 0..<3 {
                            let ang = now * 2.6 + Double(e) * (Double.pi * 2 / 3)
                            let ex = pt.x + CGFloat(cos(ang)) * orbitR
                            let ey = pt.y + CGFloat(sin(ang)) * orbitR
                            ctx.fill(Path(ellipseIn: CGRect(x: ex - 2, y: ey - 2, width: 4, height: 4)), with: .color(ringColor))
                        }
                    }

                    ctx.fill(Path(ellipseIn: nodeRect), with: .color(.white))
                    ctx.stroke(
                        Path(ellipseIn: nodeRect),
                        with: .color(ringColor),
                        lineWidth: seat.id == focusedSeatID ? 3.2 : 2.2
                    )

                    let initials = seat.outOfMana ? "402" : String(seat.name.prefix(2)).uppercased()
                    ctx.draw(
                        Text(initials)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(seat.outOfMana ? ArenaTheme.danger : ArenaTheme.textPrimary),
                        at: pt
                    )

                    // Frosted white capsule backing behind Seat Name & Score
                    let labelStr = "\(seat.holdsGrail ? "👑 " : "")\(seat.name) · \(seat.score)"
                    let pillW = max(78, CGFloat(labelStr.count) * 7.2 + 16)
                    let pillRect = CGRect(x: pt.x - pillW * 0.5, y: pt.y + r + 5, width: pillW, height: 19)
                    ctx.fill(Path(roundedRect: pillRect, cornerRadius: 9.5), with: .color(Color.white.opacity(0.92)))
                    ctx.stroke(Path(roundedRect: pillRect, cornerRadius: 9.5), with: .color(Color.black.opacity(0.07)), lineWidth: 1)
                    ctx.draw(
                        Text(labelStr)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ArenaTheme.textPrimary),
                        at: CGPoint(x: pt.x, y: pillRect.midY)
                    )
                }

                // Foreground Beam Callout Pills (drawn above rings & nodes so zero characters are occluded)
                for (mid, vfxType, label) in deferredBeamTags {
                    let resolved = ctx.resolve(
                        Text(label)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(vfxType.color)
                    )
                    let mSize = resolved.measure(in: CGSize(width: 240, height: 24))
                    let pillRect = CGRect(
                        x: mid.x - mSize.width * 0.5 - 7,
                        y: mid.y - mSize.height * 0.5 - 2.5,
                        width: mSize.width + 14,
                        height: mSize.height + 5
                    )
                    ctx.fill(Path(roundedRect: pillRect, cornerRadius: 8), with: .color(Color.white.opacity(0.95)))
                    ctx.stroke(Path(roundedRect: pillRect, cornerRadius: 8), with: .color(vfxType.color.opacity(0.32)), lineWidth: 1)
                    ctx.draw(resolved, at: mid)
                }
            }
        }
    }
}
