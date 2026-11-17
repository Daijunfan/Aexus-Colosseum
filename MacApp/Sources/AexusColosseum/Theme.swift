import SwiftUI
import AppKit

// MARK: - Hex Helpers

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        default:
            r = 0; g = 0.478; b = 1; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: CGFloat
        switch cleaned.count {
        case 8:
            r = CGFloat((value >> 24) & 0xFF) / 255
            g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8) & 0xFF) / 255
            a = CGFloat(value & 0xFF) / 255
        case 6:
            r = CGFloat((value >> 16) & 0xFF) / 255
            g = CGFloat((value >> 8) & 0xFF) / 255
            b = CGFloat(value & 0xFF) / 255
            a = 1
        default:
            r = 0.957; g = 0.957; b = 0.969; a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Pure Apple Daylight App Store Design System (Aligned 1:1 with Aexus Spear)

enum ArenaTheme {
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(hex: light)
    }

    static func tint(_ opacity: Double) -> Color {
        Color.black.opacity(opacity * 0.85)
    }

    static func shadow(_ opacity: Double) -> Color {
        Color.black.opacity(opacity * 0.22)
    }

    static func scrim(_ opacity: Double) -> Color {
        Color.white.opacity(min(0.92, 0.65 + opacity * 0.25))
    }

    // Core Apple Daylight Surfaces (#F4F4F7 cool neutral canvas + pure white cards)
    static let background = Color(red: 0.957, green: 0.957, blue: 0.969)
    static let backgroundTop = Color.white
    static let backgroundBottom = Color(red: 0.945, green: 0.952, blue: 0.968)
    static let backgroundLift = Color.white
    static let sidebar = Color(red: 0.955, green: 0.958, blue: 0.968)

    static let card = Color.white
    static let cardRaised = Color.white
    static let cardHover = Color(red: 0.972, green: 0.975, blue: 0.984)
    static let elevated = Color.white.opacity(0.90)

    // Borders & Hairlines
    static let stroke = Color.black.opacity(0.07)
    static let strokeStrong = Color.black.opacity(0.13)
    static let hairline = Color.black.opacity(0.06)

    // Apple HIG High-Contrast Ink Hierarchy (> 4.5:1 WCAG AA even at micro sizes)
    static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.118)     // #1A1A1E
    static let textSecondary = Color(red: 0.380, green: 0.384, blue: 0.416)   // #61626A
    static let textTertiary = Color(red: 0.435, green: 0.439, blue: 0.472)    // #6F7078
    static let textQuaternary = Color(red: 0.555, green: 0.560, blue: 0.592)  // #8E8F97

    // Primary Interactive Color: Apple System Blue (#007AFF)
    static let appleBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let appleBlueDeep = Color(red: 0.0, green: 0.38, blue: 0.86)
    static let accent = appleBlue
    static let accentBright = appleBlue
    static let accentDeep = appleBlueDeep
    static let ember = Color(red: 0.82, green: 0.45, blue: 0.10)
    static let gold = Color(red: 0.76, green: 0.48, blue: 0.06)

    // Semantic Status Colors (Tasteful Apple Daylight Palette)
    static let success = Color(red: 0.13, green: 0.56, blue: 0.31)            // Apple Green
    static let warning = Color(red: 0.78, green: 0.45, blue: 0.05)            // Apple Amber
    static let danger = Color(red: 0.84, green: 0.18, blue: 0.20)             // Apple Red

    // Tactical Semantic Tokens tuned for crisp Daylight Studio contrast
    static let breachCrimson = Color(red: 0.86, green: 0.18, blue: 0.20)      // #DC2E33
    static let breachCrimsonSoft = Color(red: 0.91, green: 0.25, blue: 0.27)
    static let patchCyan = Color(red: 0.0, green: 0.478, blue: 1.0)           // #007AFF Apple Blue
    static let grailGold = Color(red: 0.82, green: 0.50, blue: 0.04)          // #D1800A
    static let ecgEmerald = Color(red: 0.11, green: 0.58, blue: 0.34)         // #1C9457
    static let thoughtViolet = Color(red: 0.44, green: 0.26, blue: 0.84)      // #7042D6

    // Daylight Studio Stage aliases (replacing legacy dark obsidian surfaces)
    static let obsidianAbyss = background
    static let obsidianStage = Color(red: 0.968, green: 0.972, blue: 0.982)
    static let obsidianGlass = Color.white.opacity(0.94)
    static let obsidianRaised = Color.white
    static let obsidianVisor = Color.white.opacity(0.97)
    static let obsidianRim = Color.black.opacity(0.07)
    static let obsidianRimStrong = Color.black.opacity(0.12)

    static let pitCrimsonGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.50, blue: 1.0), Color(red: 0.0, green: 0.40, blue: 0.92)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pitCyanGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.18, green: 0.62, blue: 0.98)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let pitGoldGradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.62, blue: 0.08), Color(red: 0.82, green: 0.46, blue: 0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pitManaGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.34, green: 0.34, blue: 0.88)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let codeBackground = Color(red: 0.965, green: 0.968, blue: 0.978)

    static var windowBackground: NSColor {
        NSColor(srgbRed: 0.957, green: 0.957, blue: 0.969, alpha: 1)
    }

    static let accentGradient = LinearGradient(
        colors: [appleBlue, appleBlueDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let redGlow = RadialGradient(
        colors: [appleBlue.opacity(0.055), Color.clear],
        center: .topTrailing,
        startRadius: 0,
        endRadius: 620
    )
}

// MARK: - Spatial & Typography Rhythm

enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 42
}

enum Radius {
    static let row: CGFloat = 8
    static let control: CGFloat = 10
    static let card: CGFloat = 20
    static let panel: CGFloat = 22
    static let hero: CGFloat = 26
}

enum Motion {
    static let press = Animation.easeOut(duration: 0.12)
    static let hover = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let disclosure = Animation.spring(response: 0.32, dampingFraction: 0.92)
    static let page = Animation.easeInOut(duration: 0.18)
    static let banner = Animation.spring(response: 0.32, dampingFraction: 0.86)
}

enum ArenaType {
    static let display = Font.system(size: 40, weight: .bold)
    static let pageTitle = Font.system(size: 34, weight: .bold)
    static let section = Font.system(size: 20, weight: .bold)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let headline = Font.system(size: 13.5, weight: .semibold)
    static let body = Font.system(size: 13)
    static let callout = Font.system(size: 12)
    static let caption = Font.system(size: 11)
    static let micro = Font.system(size: 9.5, weight: .semibold)
    static let microBold = Font.system(size: 9.5, weight: .bold)
    static let mono = Font.system(size: 11.5, design: .monospaced)
}

// MARK: - Native Pointing-Hand Cursor (`👆` 小手指针，纯 SwiftUI 零视图开销、零点击拦截)

private struct PointerHoverModifier: ViewModifier {
    var enabled: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            baseHover(content)
                .pointerStyle(enabled ? .link : .default)
        } else {
            baseHover(content)
        }
    }

    private func baseHover(_ content: Content) -> some View {
        content
            .onContinuousHover { phase in
                guard enabled else {
                    if hovering {
                        hovering = false
                        NSCursor.arrow.set()
                    }
                    return
                }
                switch phase {
                case .active:
                    hovering = true
                    NSCursor.pointingHand.set()
                case .ended:
                    if hovering {
                        hovering = false
                        NSCursor.arrow.set()
                    }
                }
            }
            .onDisappear {
                if hovering {
                    hovering = false
                    NSCursor.arrow.set()
                }
            }
    }
}

extension View {
    /// Changes the macOS mouse pointer to the native pointing hand (`👆`) on hover.
    func pointerCursor(_ enabled: Bool = true) -> some View {
        modifier(PointerHoverModifier(enabled: enabled))
    }
}

// MARK: - Button Style & Surface Modifiers

struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.985
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .brightness(configuration.isPressed ? -0.015 : 0)
            .animation(Motion.press, value: configuration.isPressed)
            .pointerCursor(isEnabled)
    }
}

struct ArenaBackground: View {
    var body: some View {
        ZStack {
            ArenaTheme.background

            LinearGradient(
                colors: [
                    Color.white.opacity(0.92),
                    Color(red: 0.955, green: 0.962, blue: 0.975).opacity(0.68),
                    Color(red: 0.945, green: 0.952, blue: 0.968).opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                RadialGradient(
                    colors: [ArenaTheme.appleBlue.opacity(0.055), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 540
                )
                .frame(width: 1080, height: 1080)
                .position(x: proxy.size.width - 80, y: -120)
                .blur(radius: 40)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func arenaCard(
        radius: CGFloat = Radius.card,
        fill: Color = ArenaTheme.card,
        stroke: Color = ArenaTheme.stroke,
        shadow: Bool = true
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .shadow(color: Color.black.opacity(shadow ? 0.048 : 0), radius: 12, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(stroke, lineWidth: 1)
                )
        )
    }

    func hairlineDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
        }
    }

    /// Clean Apple Daylight elevated card (replaces dark obsidian glass).
    func pitGlassCard(
        radius: CGFloat = Radius.card,
        fill: Color = Color.white,
        rim: Color = ArenaTheme.stroke,
        glow: Color? = nil,
        glowRadius: CGFloat = 14
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .shadow(
                    color: (glow ?? .black).opacity(glow == nil ? 0.05 : 0.12),
                    radius: glowRadius,
                    x: 0,
                    y: 6
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(glow?.opacity(0.28) ?? rim, lineWidth: 1)
                )
        )
    }
}

// MARK: - Window Chrome & Universal `⌘+` / `⌘-` / `⌘0` Zoom Key Monitor

struct WindowConfigurator: NSViewRepresentable {
    var onZoomIn: (() -> Void)? = nil
    var onZoomOut: (() -> Void)? = nil
    var onZoomReset: (() -> Void)? = nil

    func makeNSView(context: Context) -> Configurator {
        let v = Configurator()
        v.onZoomIn = onZoomIn
        v.onZoomOut = onZoomOut
        v.onZoomReset = onZoomReset
        return v
    }

    func updateNSView(_ nsView: Configurator, context: Context) {
        nsView.onZoomIn = onZoomIn
        nsView.onZoomOut = onZoomOut
        nsView.onZoomReset = onZoomReset
    }

    final class Configurator: NSView {
        var onZoomIn: (() -> Void)?
        var onZoomOut: (() -> Void)?
        var onZoomReset: (() -> Void)?
        private var done = false
        private var keyMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !done else { return }
            done = true
            window.title = "Aexus Colosseum"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            window.minSize = NSSize(width: 1200, height: 780)
            window.appearance = NSAppearance(named: .aqua)
            window.backgroundColor = ArenaTheme.windowBackground
            window.toolbarStyle = .unifiedCompact
            window.titlebarSeparatorStyle = .none
            _ = window.setFrameAutosaveName("AexusColosseumMainWindow")
            if !window.setFrameUsingName("AexusColosseumMainWindow") {
                window.setContentSize(NSSize(width: 1520, height: 960))
                window.center()
            }

            // Universal keyboard monitor so ⌘+, ⌘=, ⌘-, ⌘_, and ⌘0 ALWAYS adjust UI size
            // regardless of keyboard layout, Shift modifier, or focused control.
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let cmdOnly = flags == .command || flags == [.command, .shift] || flags == [.command, .numericPad]
                guard cmdOnly else { return event }

                let chars = event.charactersIgnoringModifiers ?? ""
                switch event.keyCode {
                case 24, 69: // '=' / '+' or keypad '+'
                    self.onZoomIn?()
                    return nil
                case 27, 78: // '-' / '_' or keypad '-'
                    self.onZoomOut?()
                    return nil
                case 29, 82: // '0' or keypad '0'
                    if !flags.contains(.shift) {
                        self.onZoomReset?()
                        return nil
                    }
                default:
                    if chars == "+" || chars == "=" {
                        self.onZoomIn?()
                        return nil
                    } else if chars == "-" || chars == "_" {
                        self.onZoomOut?()
                        return nil
                    } else if chars == "0" && !flags.contains(.shift) {
                        self.onZoomReset?()
                        return nil
                    }
                }
                return event
            }
        }

        deinit {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }
    }
}
