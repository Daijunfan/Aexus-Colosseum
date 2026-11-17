import SwiftUI

/// Creates a self-contained AWD arena: up to five teams, each with up to
/// three service machines and three attacker machines.  The server registers
/// every machine and leaves it stopped; the event detail screen starts and
/// verifies only the teams the operator needs.
struct ArenaEventCreateSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    var onCreated: ((ArenaEvent) -> Void)? = nil

    @State private var name = "Arena 竞技场"
    @State private var teams = 5
    @State private var services = 1
    @State private var attackers = 1

    private var totalMachines: Int { teams * (services + attackers) }
    private var busy: Bool { app.awdBusy.contains("global:create") }
    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    nameSection
                    compositionSection
                    previewSection
                    resourceNote
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
            }
            divider
            footer
        }
        .frame(width: 720, height: 760)
        .background(ArenaTheme.background)
    }

    private var divider: some View {
        Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ARENA AWD · MANAGED TOPOLOGY")
                    .font(ArenaType.micro)
                    .tracking(1.4)
                    .foregroundStyle(ArenaTheme.accent)
                Text("生成竞技场")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text("由 Arena 自动创建服务机与攻击机。生成后全部保持停止，验证通过再按队启动。")
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer()
            RoundIconButton(systemImage: "xmark", help: "关闭") { dismiss() }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    // MARK: Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "竞技场名称")
            TextField("例如：周五夜间 AWD", text: $name)
                .textFieldStyle(.plain)
                .font(ArenaType.body)
                .foregroundStyle(ArenaTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(ArenaTheme.tint(0.035)))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(ArenaTheme.tint(0.1), lineWidth: 0.8))
        }
    }

    // MARK: Composition

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "编成", trailing: "最多 5 队 · 每队 3 + 3")
            counterRow(title: "队伍", subtitle: "每支队伍独立防守与进攻",
                       value: $teams, range: 1...5, tint: ArenaTheme.accent)
            counterRow(title: "服务机", subtitle: "每队的 Web 靶标，独立端口",
                       value: $services, range: 1...3, tint: ArenaTheme.ember)
            counterRow(title: "攻击机", subtitle: "每队的 Kali 工作台，可互相渗透",
                       value: $attackers, range: 1...3, tint: ArenaTheme.accentBright)
        }
    }

    private func counterRow(title: String, subtitle: String,
                            value: Binding<Int>, range: ClosedRange<Int>,
                            tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.1))
                Image(systemName: title == "队伍" ? "person.3.fill"
                      : (title == "服务机" ? "server.rack" : "bolt.fill"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary)
                Text(subtitle).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer()
            HStack(spacing: 3) {
                ForEach(range, id: \.self) { option in
                    Button {
                        withAnimation(Motion.disclosure) { value.wrappedValue = option }
                    } label: {
                        Text("\(option)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(value.wrappedValue == option ? .white : ArenaTheme.textSecondary)
                            .frame(width: 30, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(value.wrappedValue == option ? tint : ArenaTheme.tint(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(option)")
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(ArenaTheme.tint(0.025)))
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ArenaTheme.tint(0.022)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.07), lineWidth: 0.8))
    }

    // MARK: Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "拓扑预览", trailing: "\(teams) 队 · \(totalMachines) 台机器")
            HStack(spacing: 10) {
                ForEach(0..<teams, id: \.self) { index in
                    teamPreview(index + 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                legend(color: ArenaTheme.ember, text: "服务机 S1–S\(services)")
                legend(color: ArenaTheme.accent, text: "攻击机 A1–A\(attackers)")
                Spacer()
                Text("生成后全部停止")
                    .font(ArenaType.micro)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ArenaTheme.tint(0.02)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.07), lineWidth: 0.8))
    }

    private func teamPreview(_ index: Int) -> some View {
        VStack(spacing: 8) {
            Text("队 \(index)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ArenaTheme.textSecondary)
            HStack(spacing: 5) {
                ForEach(0..<services, id: \.self) { _ in
                    machineDot(color: ArenaTheme.ember, symbol: "server.rack")
                }
            }
            HStack(spacing: 5) {
                ForEach(0..<attackers, id: \.self) { _ in
                    machineDot(color: ArenaTheme.accent, symbol: "bolt.fill")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(ArenaTheme.tint(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.06), lineWidth: 0.8))
    }

    private func machineDot(color: Color, symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 15, height: 15)
            .background(Circle().fill(color.opacity(0.13)))
            .overlay(Circle().strokeBorder(color.opacity(0.28), lineWidth: 0.7))
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).font(ArenaType.micro).foregroundStyle(ArenaTheme.textTertiary)
        }
    }

    private var resourceNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "apple.logo")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArenaTheme.textTertiary)
                .padding(.top, 1)
            Text("机器命名统一以 Arena 开头，服务机与攻击机分别标注。服务机 1.5 GB / 1.5 核，攻击机 2 GB / 1.5 核；只有启动的队伍才占用资源。")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(ArenaTheme.tint(0.025)))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(teams) 支队伍 · \(totalMachines) 台机器")
                .font(ArenaType.caption)
                .foregroundStyle(ArenaTheme.textTertiary)
            Spacer()
            GhostButton(title: "取消") { dismiss() }
            AccentButton(title: "生成竞技场", systemImage: "sparkles",
                         busy: busy, enabled: canSubmit) { submit() }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    private func submit() {
        guard canSubmit else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if let event = await app.createArenaEvent(name: trimmed, teams: teams,
                                                      services: services, attackers: attackers) {
                onCreated?(event)
                dismiss()
            }
        }
    }
}
