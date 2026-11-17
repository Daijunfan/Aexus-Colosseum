import SwiftUI
import AppKit

@main
struct AexusColosseumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup("Aexus Colosseum") {
            RootView()
                .environmentObject(app)
                .environmentObject(app.pit)
                .preferredColorScheme(.light)
                .task {
                    await app.pit.bootstrap(with: app.labs)
                    await app.connect()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1520, height: 960)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    app.settingsOpen = true
                    app.selectedLabID = nil
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Divider()
                Button("放大界面 (Zoom In)") {
                    app.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("放大界面") {
                    app.zoomIn()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("缩小界面 (Zoom Out)") {
                    app.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("实际大小 (100%)") {
                    app.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)
                Divider()
            }

            CommandGroup(after: .sidebar) {
                Button("刷新状态") {
                    Task { await app.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("创建对决 (斗兽场大厅)") { app.switchMode(to: .pitArena) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("实况战场 (Live Stage)") { app.switchMode(to: .pitLive) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("全部靶标与斗士库") { app.switchMode(to: .training) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("单兵调试终端") { app.switchMode(to: .workspace) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("多队赛事管理") { app.switchMode(to: .events) }
                    .keyboardShortcut("5", modifiers: .command)
                Button("主机与拓扑") { app.switchMode(to: .hosts) }
                    .keyboardShortcut("6", modifiers: .command)
            }

            CommandMenu("战场视角") {
                Button("全局攻防态势") {
                    app.pit.autoDirectorEnabled = false
                    app.pit.activeLens = .macroArena
                }
                Button("靶机五层透视") {
                    app.pit.autoDirectorEnabled = false
                    app.pit.activeLens = .xrayOrgan
                }
                Button("目标网页实况") {
                    app.pit.autoDirectorEnabled = false
                    app.pit.activeLens = .liveWebHijack
                }
                Divider()
                Button("展开/收起底层检视台") {
                    app.pit.visorOpen.toggle()
                }
            }

            CommandMenu("服务器") {
                Button("启动 Arena 服务器") {
                    Task { await app.startServer() }
                }
                .disabled(app.serverReady || app.vmBusy)

                Button("关闭 Arena 服务器") {
                    app.confirmStopVM = true
                }
                .disabled(!app.serverRunning || app.vmBusy)

                Divider()

                Button("停止所有运行中靶标") {
                    Task { await app.stopEverything() }
                }
                .disabled(app.runningLabs.isEmpty)
            }
        }
    }
}

enum AppearanceSettings {
    static let key = "arena.appearance"
    /// Pure Apple Daylight aesthetic is the product default (matching Aexus Spear).
    static let defaultValue = "light"

    static func apply(_ value: String) {
        let appearance: NSAppearance?
        switch value {
        case "dark":
            appearance = NSAppearance(named: .darkAqua)
        case "system":
            appearance = nil
        default:
            appearance = NSAppearance(named: .aqua)
        }
        NSApp?.appearance = appearance
        for window in NSApp?.windows ?? [] {
            window.appearance = appearance
        }
    }

    static func applyCurrent() {
        apply(UserDefaults.standard.string(forKey: key) ?? defaultValue)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UserDefaults.standard.register(defaults: [AppearanceSettings.key: AppearanceSettings.defaultValue])
        AppearanceSettings.apply("light")
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
