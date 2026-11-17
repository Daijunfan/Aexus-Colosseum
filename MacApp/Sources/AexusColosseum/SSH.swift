import Foundation

enum SSHError: LocalizedError {
    case launch(String)
    case timeout(String)
    case failed(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .launch(let message): return "无法启动 SSH：\(message)"
        case .timeout(let what): return "\(what)超时，请检查服务器状态"
        case .failed(let message): return message
        case .badResponse(let message): return message
        }
    }
}

/// Runs commands on bupt208 (host) and Arena (guest) through the system SSH
/// client.  Everything is asynchronous and never blocks the main actor.
enum SSH {
    static var home: String { NSHomeDirectory() }
    static var guestConfig: String { "\(home)/.ssh/arena-hosts.conf" }
    static var guestKey: String { "\(home)/.ssh/id_ed25519_arena" }
    static var knownHosts: String { "\(home)/.ssh/arena_known_hosts" }

    static func hostctl(_ command: String, timeout: TimeInterval = 30) async throws -> String {
        let remote = "python3 /home/djf/arena/hostctl.py \(command)"
        return try await run("/usr/bin/ssh", [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-o", "ServerAliveInterval=15",
            "bupt208", remote
        ], timeout: timeout, label: "服务器控制")
    }

    static func arena(_ command: String, timeout: TimeInterval = 60) async throws -> String {
        // Acceptance checks can run `arenactl` directly against a local Docker
        // host instead of SSHing to Arena.  Unset in normal use.
        if let ctl = ProcessInfo.processInfo.environment["AEXUS_LOCAL_CTL"], !ctl.isEmpty {
            var arguments = command
            if arguments.hasPrefix("arenactl ") {
                arguments = String(arguments.dropFirst("arenactl ".count))
            }
            let script = "'\(ctl.replacingOccurrences(of: "'", with: "'\\''"))' \(arguments)"
            return try await run("/bin/sh", ["-c", script],
                                 timeout: timeout, label: "实验环境")
        }
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "UserKnownHostsFile=\(knownHosts)",
            "-o", "ServerAliveInterval=15"
        ]
        args += ["-J", "bupt208", "-p", "22004", "-i", guestKey,
                 "ubuntu@127.0.0.1"]
        args.append(command)
        return try await run("/usr/bin/ssh", args, timeout: timeout, label: "实验环境")
    }

    private static func run(_ executable: String, _ arguments: [String],
                            timeout: TimeInterval, label: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["LC_ALL"] = "en_US.UTF-8"
            process.environment = environment

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.standardInput = FileHandle.nullDevice

            let collector = OutputCollector()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.append(handle.availableData, to: .stdout)
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.append(handle.availableData, to: .stderr)
            }

            let state = ResumeState()
            let timeoutItem = DispatchWorkItem {
                if process.isRunning { process.terminate() }
                if state.claim() {
                    continuation.resume(throwing: SSHError.timeout(label))
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            process.terminationHandler = { finished in
                timeoutItem.cancel()
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                collector.append(outPipe.fileHandleForReading.availableData, to: .stdout)
                collector.append(errPipe.fileHandleForReading.availableData, to: .stderr)
                guard state.claim() else { return }
                let stdout = collector.stdout
                let stderr = collector.stderr
                if finished.terminationStatus == 0 {
                    continuation.resume(returning: stdout)
                } else {
                    let text = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallback = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: SSHError.failed(
                        Self.friendly(text.isEmpty ? fallback : text)))
                }
            }

            do {
                try process.run()
            } catch {
                timeoutItem.cancel()
                if state.claim() {
                    continuation.resume(throwing: SSHError.launch(error.localizedDescription))
                }
            }
        }
    }

    private static func friendly(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("Permission denied") {
            return "SSH 认证失败，请确认密钥仍被服务器接受"
        }
        if text.contains("Connection refused") || text.contains("Connection timed out") {
            return "无法连接服务器，请检查网络或启动 Arena"
        }
        if text.contains("Host key verification failed") {
            return "主机密钥校验失败，请更新 known_hosts"
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        return String(lines.suffix(4).joined(separator: "\n")).isEmpty ? "SSH 命令执行失败" :
            String(lines.suffix(4).joined(separator: "\n"))
    }

    private enum Stream { case stdout, stderr }

    private final class OutputCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var outData = Data()
        private var errData = Data()

        func append(_ data: Data, to stream: Stream) {
            guard !data.isEmpty else { return }
            lock.lock()
            switch stream {
            case .stdout: outData.append(data)
            case .stderr: errData.append(data)
            }
            lock.unlock()
        }

        var stdout: String {
            lock.lock(); defer { lock.unlock() }
            return String(data: outData, encoding: .utf8) ?? ""
        }

        var stderr: String {
            lock.lock(); defer { lock.unlock() }
            return String(data: errData, encoding: .utf8) ?? ""
        }
    }

    private final class ResumeState: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }
}

// MARK: - API

enum ArenaAPI {
    private static let decoder = JSONDecoder()

    static func hostInfo() async throws -> VMInfo {
        let text = try await SSH.hostctl("info", timeout: 25)
        return try decode(text)
    }

    static func startVM() async throws -> VMInfo {
        let text = try await SSH.hostctl("start", timeout: 330)
        return try decode(text)
    }

    static func stopVM() async throws -> VMInfo {
        let text = try await SSH.hostctl("stop", timeout: 330)
        return try decode(text)
    }

    static func kaliInfo() async throws -> VMInfo {
        try decode(try await SSH.hostctl("kali-info", timeout: 25))
    }

    static func startKali() async throws -> VMInfo {
        try decode(try await SSH.hostctl("kali-start", timeout: 330))
    }

    static func stopKali() async throws -> VMInfo {
        try decode(try await SSH.hostctl("kali-stop", timeout: 330))
    }

    static func list() async throws -> ArenaListResponse {
        let text = try await SSH.arena("arenactl list --json", timeout: 90)
        return try decode(text)
    }

    static func info() async throws -> ArenaHostInfo {
        let text = try await SSH.arena("arenactl info --json", timeout: 45)
        return try decode(text)
    }

    static func library() async throws -> TrainingLibraryResponse {
        try decode(try await SSH.arena("arenactl library --json", timeout: 30))
    }

    static func start(_ id: String) async throws -> ArenaActionResponse {
        let text = try await SSH.arena("arenactl start \(safe(id)) --json", timeout: 1800)
        return try decode(text)
    }

    static func stop(_ id: String) async throws -> ArenaActionResponse {
        let text = try await SSH.arena("arenactl stop \(safe(id)) --json", timeout: 300)
        return try decode(text)
    }

    static func stopAll() async throws -> ArenaActionResponse {
        let text = try await SSH.arena("arenactl stop-all --json", timeout: 600)
        return try decode(text)
    }

    static func install(_ id: String) async throws -> ArenaActionResponse {
        // Pulling images can take a long time on a cold cache.
        let text = try await SSH.arena("arenactl install \(safe(id)) --json", timeout: 3600)
        return try decode(text)
    }

    static func remove(_ id: String) async throws -> ArenaActionResponse {
        let text = try await SSH.arena("arenactl remove \(safe(id)) --json", timeout: 900)
        return try decode(text)
    }

    static func logs(_ id: String, tail: Int = 160) async throws -> String {
        let text = try await SSH.arena("arenactl logs \(safe(id)) --tail \(tail) --json", timeout: 60)
        let response: ArenaLogsResponse = try decode(text)
        if !response.ok { throw SSHError.badResponse(response.error ?? "读取日志失败") }
        return response.logs ?? ""
    }

    private static func safe(_ id: String) -> String {
        id.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func decode<T: Decodable>(_ text: String) throws -> T {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let data = String(trimmed[start...]).data(using: .utf8) else {
            throw SSHError.badResponse("服务器返回了无法解析的数据")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SSHError.badResponse("解析服务器响应失败：\(error.localizedDescription)")
        }
    }
}
