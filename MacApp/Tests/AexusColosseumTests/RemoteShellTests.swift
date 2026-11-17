import XCTest
import AppKit
import SwiftTerm
@testable import AexusColosseum

final class RemoteShellTests: XCTestCase {
    private let host = PlatformHost(name: "PTY test", role: .attacker)

    @MainActor
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition(), "Timed out waiting for terminal state")
    }

    @MainActor
    private func text(_ view: LocalProcessTerminalView) -> String {
        String(decoding: view.getBufferAsData(), as: UTF8.self)
    }

    @MainActor
    private var ready: String {
        "printf '\\033]0;\(RemoteShell.readyTitle)\\007'; "
    }

    @MainActor
    func testPTYRendersANSIUnicodeAndCarriageReturnAndAcceptsInput() async throws {
        let shell = RemoteShell()
        defer { shell.stop() }
        shell.launch(host: host, executable: "/bin/sh", arguments: ["-c", ready + #"""
            stty -echo
            test -t 0 && test -t 1 && printf 'PTY_OK\r\n'
            printf '\033[32m中文 terminal\033[0m\r\n'
            printf 'progress 10%%\r\033[2Kprogress 100%%\r\n'
            IFS= read -r value
            printf 'INPUT=%s\r\n' "$value"
            exec /bin/cat
            """#])
        try await waitUntil { shell.connected }
        let view = try XCTUnwrap(shell.terminal)
        try await waitUntil { self.text(view).contains("progress 100%") }
        let rendered = text(view)
        XCTAssertTrue(rendered.contains("PTY_OK"))
        XCTAssertTrue(rendered.contains("中文 terminal"))
        XCTAssertFalse(rendered.contains("progress 10%"), "Carriage return must replace the current line")
        XCTAssertFalse(rendered.contains("\u{1b}"), "ANSI bytes must not appear as text")
        XCTAssertFalse(rendered.contains(RemoteShell.readyTitle), "The readiness handshake is not console output")
        view.send(txt: "直接输入\r")
        try await waitUntil { self.text(view).contains("INPUT=直接输入") }
    }

    @MainActor
    func testReconnectIgnoresRetiredSessionAndStopsItsProcess() async throws {
        let shell = RemoteShell()
        defer { shell.stop() }
        shell.launch(host: host, executable: "/bin/sh", arguments: ["-c", ready + "exec /bin/cat"])
        try await waitUntil { shell.connected }
        let old = try XCTUnwrap(shell.terminal)

        shell.launch(host: host, executable: "/bin/sh", arguments: ["-c", ready + "exec /bin/cat"])
        let current = try XCTUnwrap(shell.terminal)
        XCTAssertFalse(old === current)
        XCTAssertEqual(shell.state, .connecting)
        shell.setTerminalTitle(source: old, title: RemoteShell.readyTitle)
        XCTAssertEqual(shell.state, .connecting)
        shell.processTerminated(source: old, exitCode: 0)
        XCTAssertEqual(shell.state, .connecting)
        try await waitUntil { shell.connected && !old.process.running }
        shell.processTerminated(source: old, exitCode: 255)
        XCTAssertTrue(shell.connected)
    }

    @MainActor
    func testLaunchFailureAndRemoteExitNeverReportConnected() async throws {
        let shell = RemoteShell()
        defer { shell.stop() }
        shell.launch(host: host, executable: "/nonexistent/aexus-terminal", arguments: [])
        try await waitUntil {
            if case .failed = shell.state { return true }
            if case .closed = shell.state { return true }
            return false
        }
        XCTAssertFalse(shell.connected)
        shell.launch(host: host, executable: "/bin/sh", arguments: ["-c", "printf 'connection rejected\\n'; exit 7"])
        try await waitUntil { shell.state == .closed(7) }
        XCTAssertFalse(shell.connected)
        XCTAssertTrue(text(try XCTUnwrap(shell.terminal)).contains("connection rejected"))
    }

    @MainActor
    func testLiveArenaShellInputResizeAndInterrupt() async throws {
        guard ProcessInfo.processInfo.environment["AEXUS_TERMINAL_INTEGRATION"] == "1" else {
            throw XCTSkip("Set AEXUS_TERMINAL_INTEGRATION=1 for the real Arena SSH session")
        }
        let shell = RemoteShell()
        defer { shell.stop() }
        let hosts = try await PlatformAPI.hosts()
        let kali = try XCTUnwrap(hosts.first { $0.tags.contains("kali-vm") })
        XCTAssertNil(kali.docker, "The training attacker must be a real Kali VM")
        shell.start(host: kali)
        try await waitUntil(timeout: 25) { shell.connected }
        let view = try XCTUnwrap(shell.terminal)
        view.send(txt: "printf '\\033[32mARENA_%s\\033[0m\\r\\n' TERMINAL_OK; test -t 0 && test -t 1 && printf 'PTY_%s\\r\\n' OK\r")
        try await waitUntil(timeout: 10) {
            self.text(view).contains("ARENA_TERMINAL_OK") && self.text(view).contains("PTY_OK")
        }
        view.setFrameSize(NSSize(width: 1000, height: 500))
        let size = view.getWindowSize()
        view.send(txt: "printf 'SIZE='; stty size\r")
        try await waitUntil(timeout: 10) {
            self.text(view).contains("SIZE=\(size.ws_row) \(size.ws_col)")
        }
        view.send(txt: "sleep 30\r")
        try await Task.sleep(nanoseconds: 300_000_000)
        shell.sendControlC()
        view.send(txt: "printf 'INTERRUPT_%s\\r\\n' OK\r")
        try await waitUntil(timeout: 10) { self.text(view).contains("INTERRUPT_OK") }
        XCTAssertTrue(shell.connected)
        view.send(txt: "printf 'HOST=%s\\r\\n' \"$(hostname)\"; systemd-detect-virt\r")
        try await waitUntil(timeout: 10) {
            self.text(view).contains("HOST=arena-kali") && self.text(view).contains("kvm")
        }
        view.send(txt: "exit\r")
        try await waitUntil(timeout: 10) { shell.state == .closed(0) }
    }
}
