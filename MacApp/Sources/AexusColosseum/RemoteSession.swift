import Foundation
import Combine
import Darwin
import SwiftUI
import SwiftTerm

/// Owns one PTY-backed SSH session. Each connection gets its own terminal view
/// so a retiring process cannot change the state or output of its replacement.
@MainActor
final class RemoteShell: ObservableObject, LocalProcessTerminalViewDelegate {
    enum State: Equatable {
        case idle, connecting, connected, closed(Int32?), failed(String)
    }

    nonisolated static let readyTitle = "AEXUS_COLOSSEUM_READY"
    @Published private(set) var state: State = .idle
    @Published private(set) var terminal: LocalProcessTerminalView?
    @Published private(set) var host: PlatformHost?
    @Published private(set) var fontSize: CGFloat = 14

    var connected: Bool { state == .connected }
    var connecting: Bool { state == .connecting }
    var statusLabel: String {
        switch state {
        case .idle: return "未连接"
        case .connecting: return "正在连接"
        case .connected: return "已连接"
        case .closed(let code): return code == 0 ? "会话已结束" : "连接已断开"
        case .failed: return "连接失败"
        }
    }

    func start(host: PlatformHost) {
        do {
            let arguments = try RemoteCommand.shellArguments(for: host)
            launch(host: host, executable: "/usr/bin/ssh", arguments: arguments)
        } catch {
            stop()
            state = .failed(error.localizedDescription)
        }
    }

    /// Transport construction stays separate from the PTY lifecycle so the
    /// same lifecycle can be exercised with a local shell in regression tests.
    func launch(host: PlatformHost, executable: String, arguments: [String]) {
        stop()
        let view = LocalProcessTerminalView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 400),
            font: .monospacedSystemFont(ofSize: fontSize, weight: .regular),
            options: TerminalOptions(cursorStyle: .blinkBlock, scrollback: 10_000))
        view.appearance = NSAppearance(named: .darkAqua)
        view.nativeBackgroundColor = NSColor(hex: "15181E")
        view.nativeForegroundColor = NSColor(hex: "E6E9EF")
        view.caretColor = NSColor(hex: "E6E9EF")
        let palette: [UInt32] = [
            0x1D2129, 0xE68183, 0x8BD49C, 0xE6C384, 0x82AAFF, 0xC6A0F6, 0x7DC4E4, 0xCAD3F5,
            0x6E7B91, 0xF5A1A3, 0xA6E3A1, 0xF5D98F, 0xA8C7FF, 0xDDB6F2, 0x9FE7E5, 0xF5F7FA
        ]
        view.installColors(palette.map {
            SwiftTerm.Color(red8: UInt16(($0 >> 16) & 255), green8: UInt16(($0 >> 8) & 255),
                            blue8: UInt16($0 & 255))
        })
        view.scrollerStyle = .overlay
        // PTY output arrives off-main; invalidate native drawing in the
        // SwiftUI host without republishing the terminal's entire buffer.
        view.suspendsRenderingWhenNotVisible = false
        let viewID = ObjectIdentifier(view)
        view.setProcessOutputHandler { [weak self] in
            Task { @MainActor in
                guard let terminal = self?.terminal, ObjectIdentifier(terminal) == viewID else { return }
                terminal.needsDisplay = true
            }
        }
        view.setAccessibilityLabel("攻击机终端")
        view.processDelegate = self
        self.host = host
        terminal = view
        state = .connecting
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        view.startProcess(executable: executable, args: arguments,
                          environment: environment.map { "\($0.key)=\($0.value)" })
    }

    func stop() {
        terminal?.processDelegate = nil
        terminal?.terminate()
        terminal?.updateUiClosed()
        host = nil
        state = .idle
    }

    func clear() {
        terminal?.clearScrollback()
        if connected {
            terminal?.send([0x0c])
        } else {
            terminal?.feed(text: "\u{1b}[2J\u{1b}[H")
        }
        focus()
    }

    func sendControlC() {
        guard connected else { return }
        terminal?.send([0x03])
        focus()
    }

    func adjustFont(by amount: CGFloat) {
        fontSize = min(22, max(11, fontSize + amount))
        terminal?.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        focus()
    }

    func focus() {
        guard let terminal else { return }
        terminal.window?.makeFirstResponder(terminal)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        guard source === terminal, state == .connecting, title == Self.readyTitle else { return }
        state = .connected
        focus()
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard source === terminal else { return }
        state = .closed(exitCode)
    }

    func processFailedToStart(source: TerminalView, error: LocalProcessError) {
        guard source === terminal else { return }
        state = .failed(error.localizedDescription)
    }
}

/// SwiftTerm owns keyboard input, selection, ANSI rendering and PTY resizing.
struct RemoteTerminalView: NSViewRepresentable {
    let terminal: LocalProcessTerminalView

    func makeNSView(context: Context) -> TerminalContainerView { TerminalContainerView(terminal: terminal) }
    func updateNSView(_ view: TerminalContainerView, context: Context) {}
}

/// Give AppKit an actual resize when SwiftUI expands/collapses the workspace;
/// resizing a composited terminal layer alone stretches glyphs and loses focus.
final class TerminalContainerView: NSView {
    let terminal: LocalProcessTerminalView

    init(terminal: LocalProcessTerminalView) {
        self.terminal = terminal
        super.init(frame: terminal.frame)
        wantsLayer = true
        terminal.autoresizingMask = [.width, .height]
        addSubview(terminal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        terminal.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutSubtreeIfNeeded()
            self.window?.makeFirstResponder(self.terminal)
        }
    }
}

// MARK: - SSH tunnel for browser access

@MainActor
final class SSHTunnel: ObservableObject {
    enum State: Equatable {
        case idle, starting, ready(Int), failed(String)
    }

    @Published private(set) var state: State = .idle
    private var process: Process?
    private var pending: Task<Int, Error>?

    func connect(target: PlatformHost, remotePort: Int) async throws -> Int {
        if let pending { return try await pending.value }
        let task = Task { try await self.establish(target: target, remotePort: remotePort) }
        pending = task
        defer { pending = nil }
        return try await task.value
    }

    private func establish(target: PlatformHost, remotePort: Int) async throws -> Int {
        do {
            try Task.checkCancellation()
            if case .ready(let port) = state, process?.isRunning == true,
               FreePort.isBound(port) { return port }

            process?.terminate()
            state = .starting
            let port = FreePort.find()
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            child.arguments = try RemoteCommand.tunnelArguments(target: target, remotePort: remotePort,
                                                                localPort: port)
            child.standardInput = FileHandle.nullDevice
            child.standardOutput = FileHandle.nullDevice
            let errors = Pipe()
            child.standardError = errors
            child.terminationHandler = { [weak self] finished in
                let detail = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor in
                    guard let self, self.process === finished else { return }
                    self.state = .failed(detail.isEmpty ? "连接已断开，请重新连接" : String(detail.suffix(400)))
                }
            }
            process = child
            try child.run()
            for _ in 0..<150 {
                try await Task.sleep(nanoseconds: 100_000_000)
                guard child.isRunning else { throw SSHError.failed("SSH 转发失败，请检查连接") }
                if FreePort.isBound(port) {
                    state = .ready(port)
                    return port
                }
            }
            throw SSHError.timeout("建立 Mac 访问连接")
        } catch {
            if !Task.isCancelled {
                process?.terminate()
                process = nil
                state = .failed(error.localizedDescription)
            }
            throw error
        }
    }

    func close() {
        pending?.cancel()
        pending = nil
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        state = .idle
    }

    deinit { process?.terminate() }
}

// MARK: - Command construction

enum RemoteCommandError: LocalizedError {
    case missingDocker
    case missingSSH
    case unreachable(String)

    var errorDescription: String? {
        switch self {
        case .missingDocker: return "这台主机没有配置 Docker 容器，也没有 SSH 信息"
        case .missingSSH: return "这台主机没有配置 SSH 登录信息"
        case .unreachable(let detail): return detail
        }
    }
}

enum RemoteCommand {
    static func shellArguments(for host: PlatformHost) throws -> [String] {
        // The title sequence is emitted inside the remote shell/container,
        // after SSH authentication and docker exec have actually succeeded.
        let ready = "printf '\\033]0;\(RemoteShell.readyTitle)\\007'; "
        if let docker = host.docker, !docker.container.isEmpty {
            let command = ["docker", "exec", "-it", "-e", "TERM=xterm-256color",
                           docker.container, "sh", "-lc", ready + "exec bash -l"]
                .map(quote).joined(separator: " ")
            return arenaOptions(extraTTY: true) + [arenaDestination, command]
        }
        guard let ssh = host.clientSSH ?? host.ssh else { throw RemoteCommandError.missingSSH }
        let address = ssh.address ?? host.address
        guard !address.isEmpty else { throw RemoteCommandError.missingSSH }
        return sshArguments(ssh, address: address, tty: true)
            + [ready + "exec \"${SHELL:-/bin/sh}\" -l"]
    }

    private static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func tunnelArguments(target: PlatformHost, remotePort: Int, localPort: Int) throws -> [String] {
        if let docker = target.docker, !docker.container.isEmpty {
            // Containers publish ports on Arena's loopback.  Tunnel through
            // Arena by asking the container for its published port is not
            // available here, so callers pass the published port.
            _ = docker
        }
        if target.address.isEmpty || target.address == "127.0.0.1" || target.address == "localhost" {
            return arenaOptions(extraTTY: false) + [
                "-N",
                "-o", "ExitOnForwardFailure=yes",
                "-L", "127.0.0.1:\(localPort):127.0.0.1:\(remotePort)",
                arenaDestination
            ]
        }
        guard let ssh = target.clientSSH ?? target.ssh else {
            // No SSH details: use Arena as the jump host and let the target
            // address be resolved inside the range network.
            return arenaOptions(extraTTY: false) + [
                "-N",
                "-o", "ExitOnForwardFailure=yes",
                "-L", "127.0.0.1:\(localPort):\(target.address):\(remotePort)",
                arenaDestination
            ]
        }
        var args = sshOptions(ssh, tty: false)
        args += ["-N", "-o", "ExitOnForwardFailure=yes",
                 "-L", "127.0.0.1:\(localPort):\(target.address):\(remotePort)"]
        args.append("\(ssh.user)@\(ssh.address ?? target.address)")
        return args
    }

    private static func sshArguments(_ ssh: HostSSH, address: String, tty: Bool) -> [String] {
        var args = sshOptions(ssh, tty: tty)
        args.append("\(ssh.user)@\(address)")
        return args
    }

    private static func sshOptions(_ ssh: HostSSH, tty: Bool) -> [String] {
        var args: [String] = []
        if tty { args.append("-tt") }
        args += ["-o", "BatchMode=yes",
                 "-o", "ConnectTimeout=10",
                 "-o", "ServerAliveInterval=20",
                 "-o", "StrictHostKeyChecking=accept-new",
                 "-p", "\(ssh.port)"]
        if !ssh.key.isEmpty { args += ["-i", expand(ssh.key)] }
        if let jump = ssh.jump, !jump.isEmpty { args += ["-J", jump] }
        return args
    }

    private static var arenaDestination: String { "ubuntu@127.0.0.1" }

    private static func arenaOptions(extraTTY: Bool) -> [String] {
        var args: [String] = []
        if extraTTY { args.append("-tt") }
        args += ["-o", "BatchMode=yes",
                 "-o", "ConnectTimeout=10",
                 "-o", "ServerAliveInterval=20",
                 "-o", "StrictHostKeyChecking=accept-new",
                 "-o", "UserKnownHostsFile=\(SSH.knownHosts)",
                 "-J", "bupt208",
                 "-p", "22004",
                 "-i", SSH.guestKey]
        return args
    }

    private static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}

// MARK: - Port helpers

enum FreePort {
    static func find() -> Int {
        for _ in 0..<30 {
            let candidate = Int.random(in: 18_100...18_999)
            if !isBound(candidate) { return candidate }
        }
        return 18_999
    }

    static func isBound(_ port: Int) -> Bool {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        // Check the local bind without connecting: probing an SSH forward
        // would open and abort a database handshake on the target.
        let result = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result != 0 && errno == EADDRINUSE
    }
}
