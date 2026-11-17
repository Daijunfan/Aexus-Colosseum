import SwiftUI
import AppKit

// MARK: - Brand Mark (Apple Squircle Icon — Matching Aexus Spear)

struct ArenaMark: View {
    var size: CGFloat = 34
    var glow: Bool = false

    var body: some View {
        PitEmblemView(size: size, glow: glow)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct PitEmblemView: View {
    var size: CGFloat = 34
    var glow: Bool = false

    private static let cachedMark: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppMark", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
    }

    var body: some View {
        Group {
            if let image = Self.cachedMark {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.14, green: 0.15, blue: 0.19),
                                Color(red: 0.06, green: 0.06, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: max(1, size * 0.04))
                        .padding(size * 0.18)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: size * 0.44, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF5A36"), ArenaTheme.appleBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.black.opacity(0.10), lineWidth: 0.75))
        .shadow(
            color: Color.black.opacity(glow ? 0.16 : 0.10),
            radius: size * 0.18,
            x: 0,
            y: size * 0.07
        )
    }
}

// MARK: - Apple App Store Squircle Tile Icon (64pt Card Icon)

struct SquircleIconTile: View {
    var symbol: String
    var colors: [Color]
    var size: CGFloat = 62
    var glowing: Bool = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
    }

    var body: some View {
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: colors.isEmpty ? [ArenaTheme.appleBlue, ArenaTheme.appleBlueDeep] : colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.02), Color.black.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Image(systemName: symbol)
                .font(.system(size: size * 0.68, weight: .bold))
                .foregroundStyle(.white.opacity(0.10))
                .offset(x: size * 0.16, y: size * 0.18)
                .clipped()

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: size * 0.58, height: size * 0.58)
                .blur(radius: size * 0.16)
                .offset(x: -size * 0.16, y: -size * 0.18)

            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.20), radius: size * 0.035, y: size * 0.02)

            shape.strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
        .shadow(
            color: (colors.first ?? .black).opacity(glowing ? 0.22 : 0.11),
            radius: glowing ? size * 0.18 : size * 0.11,
            x: 0,
            y: size * 0.06
        )
    }
}

// MARK: - Apple Storefront Headers & Filter Pills

struct ApplePageHeader: View {
    var kicker: String
    var title: String
    var subtitle: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kicker.uppercased())
                    .font(ArenaType.microBold)
                    .tracking(1.5)
                    .foregroundStyle(ArenaTheme.textTertiary)
                Text(title)
                    .font(ArenaType.pageTitle)
                    .tracking(-0.8)
                    .foregroundStyle(ArenaTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(ArenaTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let trailing {
                trailing
            }
        }
    }
}

struct AppleSectionHeader: View {
    var stepNumber: String? = nil
    var title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let stepNumber {
                Text(stepNumber)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(ArenaTheme.appleBlue)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(ArenaTheme.appleBlue.opacity(0.11)))
                    .overlay(Circle().strokeBorder(ArenaTheme.appleBlue.opacity(0.22), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(ArenaTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(ArenaTheme.textSecondary)
                }
            }
            Spacer()
            if let action, let actionTitle {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ArenaTheme.appleBlue)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.97))
            }
        }
    }
}

struct AppleFilterPill: View {
    let title: String
    var count: Int? = nil
    var symbol: String? = nil
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selected ? .white.opacity(0.84) : ArenaTheme.textTertiary)
                }
            }
            .foregroundStyle(selected ? .white : ArenaTheme.textSecondary)
            .padding(.horizontal, 13)
            .frame(height: 31)
            .background(
                Capsule()
                    .fill(selected ? ArenaTheme.appleBlue : (hovering ? Color.white : Color.white.opacity(0.76)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(selected ? Color.white.opacity(0.20) : Color.black.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(selected ? 0.11 : 0.025), radius: 5, y: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hovering = $0 }
    }
}

/// App Store "OPEN / GET" style capsule action button
struct AppleOpenPill: View {
    var title: String = "OPEN"
    var active: Bool = false
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(active ? .white : ArenaTheme.appleBlue)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            active
                                ? ArenaTheme.appleBlue.opacity(hovering ? 0.90 : 1)
                                : Color(red: 0.925, green: 0.945, blue: 0.988).opacity(hovering ? 1 : 0.85)
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            active ? Color.white.opacity(0.18) : ArenaTheme.appleBlue.opacity(0.14),
                            lineWidth: 1
                        )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .onHover { hovering = $0 }
    }
}

struct AppleSearchField: View {
    @Binding var text: String
    var placeholder: String = "搜索靶标、CVE 编号或智能体…"
    var width: CGFloat = 248
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(focused ? ArenaTheme.appleBlue : ArenaTheme.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(ArenaTheme.textPrimary)
                .focused($focused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ArenaTheme.textTertiary)
                }
                .buttonStyle(PressStyle(scale: 0.90))
            }
        }
        .padding(.horizontal, 11)
        .frame(width: width, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(focused ? Color.white : Color.black.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    focused ? ArenaTheme.appleBlue.opacity(0.55) : Color.black.opacity(0.055),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(focused ? 0.05 : 0), radius: 5, y: 2)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// Wrapping flow layout matching Apple's App Store category filter rails.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? max(0, x - spacing), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Shared Atoms & Buttons (Backward Compatible Across All Views)

struct StatusDot: View {
    var color: Color
    var pulsing: Bool = false
    @State private var animate = false

    var body: some View {
        ZStack {
            if pulsing {
                Circle().fill(color.opacity(0.22))
                    .frame(width: 13, height: 13)
                    .scaleEffect(animate ? 1.25 : 0.65)
                    .opacity(animate ? 0.15 : 0.65)
            }
            Circle().fill(color)
                .frame(width: 6.5, height: 6.5)
        }
        .onAppear {
            guard pulsing else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct Chip: View {
    var text: String
    var color: Color = ArenaTheme.textSecondary
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.09))
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(filled ? 0 : 0.18), lineWidth: 1)
            )
    }
}

struct DifficultyDots: View {
    var level: Int
    var color: Color = ArenaTheme.appleBlue

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index < level ? color : Color.black.opacity(0.10))
                    .frame(width: 5, height: 5)
            }
        }
        .help("难度 \(level) / 4")
    }
}

struct SectionLabel: View {
    var text: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(ArenaType.microBold)
                .tracking(1.35)
                .foregroundStyle(ArenaTheme.textTertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(ArenaType.caption)
                    .foregroundStyle(ArenaTheme.textTertiary)
            }
        }
    }
}

struct AccentButton: View {
    var title: String
    var systemImage: String? = nil
    var busy: Bool = false
    var enabled: Bool = true
    var wide: Bool = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if busy {
                    ProgressView().controlSize(.small).tint(.white)
                        .scaleEffect(0.75)
                        .frame(width: 12, height: 12)
                } else if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 11.5, weight: .semibold))
                }
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: wide ? .infinity : nil)
            .padding(.horizontal, wide ? 18 : 15)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(enabled ? ArenaTheme.appleBlue.opacity(hovering ? 0.90 : 1.0) : Color.black.opacity(0.14))
                    .shadow(color: ArenaTheme.appleBlue.opacity(hovering && enabled ? 0.28 : 0.14),
                            radius: 8, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled || busy)
        .onHover { hovering = $0 }
    }
}

struct GhostButton: View {
    var title: String
    var systemImage: String? = nil
    var tint: Color = ArenaTheme.textPrimary
    var busy: Bool = false
    var enabled: Bool = true
    var wide: Bool = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if busy {
                    ProgressView().controlSize(.small).tint(tint)
                        .scaleEffect(0.7).frame(width: 12, height: 12)
                } else if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 11.5, weight: .semibold))
                }
                Text(title).font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(enabled ? tint : ArenaTheme.textQuaternary)
            .frame(maxWidth: wide ? .infinity : nil)
            .padding(.horizontal, 14)
            .padding(.vertical, 7.5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(hovering ? 0.98 : 0.85))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.black.opacity(hovering ? 0.12 : 0.075), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, y: 1.5)
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled || busy)
        .onHover { hovering = $0 }
    }
}

struct RoundIconButton: View {
    var systemImage: String
    var tint: Color = ArenaTheme.textPrimary
    var size: CGFloat = 31
    var help: String = ""
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? ArenaTheme.appleBlue : tint)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(Color.white.opacity(hovering ? 0.98 : 0.76))
                )
                .overlay(Circle().strokeBorder(Color.black.opacity(hovering ? 0.11 : 0.07), lineWidth: 1))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct Meter: View {
    var fraction: Double
    var tint: Color = ArenaTheme.appleBlue

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.06))
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
    }
}

struct LabGlyph: View {
    var lab: Lab
    var color: Color
    var size: CGFloat = 56

    var body: some View {
        SquircleIconTile(
            symbol: glyph,
            colors: palette(for: lab.category, base: color),
            size: size
        )
    }

    private func palette(for category: String, base: Color) -> [Color] {
        switch category {
        case "ai": return [Color(hex: "6366F1"), Color(hex: "4338CA")]
        case "web": return [Color(hex: "0EA5E9"), Color(hex: "0369A1")]
        case "cve": return [Color(hex: "EF4444"), Color(hex: "B91C1C")]
        case "network": return [Color(hex: "14B8A6"), Color(hex: "0F766E")]
        case "redteam": return [Color(hex: "F97316"), Color(hex: "C2410C")]
        case "cloud": return [Color(hex: "3B82F6"), Color(hex: "1D4ED8")]
        case "binary": return [Color(hex: "8B5CF6"), Color(hex: "5B21B6")]
        case "forensics": return [Color(hex: "10B981"), Color(hex: "047857")]
        default: return [base, base.opacity(0.75)]
        }
    }

    private var glyph: String {
        if lab.running { return "waveform.path.ecg" }
        switch lab.category {
        case "web": return "globe"
        case "cve": return "bolt.shield.fill"
        case "network": return "point.3.connected.trianglepath.dotted"
        case "redteam": return "scope"
        case "cloud": return "cloud.fill"
        case "binary": return "cpu.fill"
        case "forensics": return "magnifyingglass"
        case "ai": return "sparkles"
        default: return "shippingbox.fill"
        }
    }
}

struct CopyChip: View {
    var text: String
    var label: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(Motion.hover) { copied = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                await MainActor.run { withAnimation(Motion.hover) { copied = false } }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(copied ? "已复制" : label)
                    .font(ArenaType.caption)
            }
            .foregroundStyle(copied ? ArenaTheme.success : ArenaTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule().fill(Color.black.opacity(0.05))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .help("复制 \(text)")
    }
}
