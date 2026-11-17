import XCTest
import Darwin
@testable import AexusColosseum

final class LabAccessTests: XCTestCase {
    func testPortCheckDoesNotOpenAServiceConnection() throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(listener, 0)
        defer { close(listener) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listener, $0, size) }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(listen(listener, 1), 0)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &size) }
        }
        XCTAssertTrue(FreePort.isBound(Int(UInt16(bigEndian: address.sin_port))))
        _ = fcntl(listener, F_SETFL, O_NONBLOCK)
        let client = accept(listener, nil, nil)
        if client >= 0 { close(client) }
        XCTAssertEqual(client, -1, "Checking a forward must not create an aborted database handshake")
        XCTAssertEqual(errno, EAGAIN)
    }

    func testForwardedAddressKeepsProtocolAndPathWithoutLocalizedPorts() {
        let web = LabAccess(label: "Web", port: 8443, scheme: "https", path: "/WebGoat/?lesson=1")
        XCTAssertEqual(web.address(port: 18123), "https://127.0.0.1:18123/WebGoat/?lesson=1")
        let database = LabAccess(label: "MySQL", port: 3306, scheme: "tcp", path: "")
        XCTAssertFalse(database.isWeb)
        XCTAssertEqual(database.address(host: "10.77.90.10"), "10.77.90.10:3306")
        XCTAssertEqual(database.address(port: 18124), "127.0.0.1:18124")
        XCTAssertTrue(database.clientCommand(port: 18124)?.contains("--port=18124") == true)
    }

    func testMacSSHUsesItsOwnJumpAndKeyWithoutEnteringDocker() throws {
        let host = PlatformHost(name: "Arena-Kali", role: .attacker, address: "10.77.90.20",
                                ssh: HostSSH(user: "kali", key: "/server/key"),
                                clientSSH: HostSSH(port: 22005, user: "kali", key: "~/.ssh/mac-key",
                                                   jump: "bupt208", address: "127.0.0.1"))
        let args = try RemoteCommand.shellArguments(for: host)
        XCTAssertTrue(args.contains("22005"))
        XCTAssertTrue(args.contains("bupt208"))
        XCTAssertTrue(args.contains("kali@127.0.0.1"))
        XCTAssertFalse(args.contains("/server/key"))
        XCTAssertFalse(args.joined(separator: " ").contains("docker exec"))
        let forward = try RemoteCommand.tunnelArguments(target: host, remotePort: 80, localPort: 18123)
        XCTAssertTrue(forward.contains("22005"))
        XCTAssertTrue(forward.contains("kali@127.0.0.1"))
        XCTAssertFalse(forward.contains("/server/key"))
    }

    func testForwardBindsOnlyTheMacLoopbackAndTargetsTheTrainingNetwork() throws {
        let target = PlatformHost(name: "Arena", role: .target, address: "10.77.90.10")
        let args = try RemoteCommand.tunnelArguments(target: target, remotePort: 3306, localPort: 18123)
        XCTAssertTrue(args.contains("127.0.0.1:18123:10.77.90.10:3306"))
        XCTAssertTrue(args.contains("ubuntu@127.0.0.1"))
        XCTAssertTrue(args.contains("ExitOnForwardFailure=yes"))
    }

    @MainActor
    func testLiveMacDatabaseConnectionReuseAndCleanup() async throws {
        guard ProcessInfo.processInfo.environment["AEXUS_ACCESS_INTEGRATION"] == "1" else {
            throw XCTSkip("Set AEXUS_ACCESS_INTEGRATION=1 for the real Arena MySQL endpoint")
        }
        let hosts = try await PlatformAPI.hosts()
        let target = try XCTUnwrap(hosts.first { $0.tags.contains("training-target") })
        let connections = LabConnections()
        defer { connections.closeAll() }
        let tunnel = connections.tunnel(target: target, port: 3306)
        let port = try await tunnel.connect(target: target, remotePort: 3306)
        XCTAssertTrue(tunnel === connections.tunnel(target: target, port: 3306))
        for _ in 0..<12 {
            let reused = try await tunnel.connect(target: target, remotePort: 3306)
            XCTAssertEqual(reused, port, "Repeated copying must reuse the forward without aborting database handshakes")
        }
        let greeting = try mysqlGreeting(port: port)
        XCTAssertGreaterThan(greeting.count, 5)
        XCTAssertEqual(greeting[4], 10, "Must receive a MySQL protocol 10 greeting through the actual SSH tunnel")
        connections.closeAll()
        XCTAssertEqual(tunnel.state, .idle)
        for _ in 0..<50 where FreePort.isBound(port) {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(FreePort.isBound(port))
    }

    private func mysqlGreeting(port: Int) throws -> [UInt8] {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { throw POSIXError(.ECONNREFUSED) }
        var data = [UInt8](repeating: 0, count: 128)
        let count = read(fd, &data, data.count)
        guard count > 0 else { throw POSIXError(.ETIMEDOUT) }
        return Array(data.prefix(count))
    }
}
