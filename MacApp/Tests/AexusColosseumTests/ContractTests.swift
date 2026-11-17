import XCTest
@testable import AexusColosseum

/// Decodes the exact JSON that `arenactl` prints for a full AWD lifecycle.
/// The fixtures are captured by `arena-server/tests/awd_simulation_test.sh`
/// (`ARENA_CAPTURE=...`), so a server-side field rename fails here instead of
/// silently blanking a screen in the app.
final class ContractTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "missing fixture \(name).json")
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    func testEventListCarriesAWDAndAllTeamMachines() throws {
        let response = try decode(EventsResponse.self, "events")
        XCTAssertTrue(response.ok)
        let event = try XCTUnwrap(response.events?.first)
        XCTAssertEqual(event.awd, true, "Arena-managed events must decode `awd`")
        XCTAssertEqual(event.teams.count, 5)
        let team = try XCTUnwrap(event.teams.first)
        XCTAssertEqual(team.allServices.count, 2)
        XCTAssertEqual(team.allAttackers.count, 2)
    }

    func testAWDCreateResponse() throws {
        let created = try decode(AWDCreateResponse.self, "awd_create")
        XCTAssertTrue(created.ok)
        XCTAssertEqual(created.count, 20)
        XCTAssertEqual(created.hosts?.count, 20)
        XCTAssertEqual(created.event?.awd, true)
        let names = created.hosts?.map(\.name) ?? []
        XCTAssertTrue(names.allSatisfy { $0.hasPrefix("Arena 队 ") })
        let containers = created.hosts?.compactMap { $0.docker?.container } ?? []
        XCTAssertEqual(containers.count, 20)
        XCTAssertTrue(containers.allSatisfy { $0.hasPrefix("Arena-awd-") })
    }

    func testAWDStartResponseKeepsPartialDetails() throws {
        let started = try decode(AWDActionResponse.self, "awd_start")
        let actions = try XCTUnwrap(started.started)
        XCTAssertEqual(actions.count, 4)
        XCTAssertTrue((started.errors ?? []).isEmpty)
        XCTAssertEqual(actions.first?.team, "t1")
        XCTAssertEqual(actions.first?.container?.hasPrefix("Arena-awd-"), true)
    }

    func testAWDStopResponse() throws {
        let stopped = try decode(AWDActionResponse.self, "awd_stop")
        let containers = try XCTUnwrap(stopped.stopped)
        XCTAssertEqual(containers.count, 4)
        XCTAssertTrue(containers.allSatisfy { $0.hasPrefix("Arena-awd-") })
        XCTAssertTrue((stopped.errors ?? []).isEmpty)
    }

    func testAWDVerifyResponse() throws {
        let verify = try decode(AWDVerifyResponse.self, "awd_verify")
        XCTAssertTrue(verify.ok)
        let t1 = try XCTUnwrap(verify.results.first { $0.teamId == "t1" })
        XCTAssertTrue(t1.ok)
        XCTAssertEqual(t1.untested, false)
        XCTAssertEqual(t1.services.count, 2)
        XCTAssertEqual(t1.services.first?.httpOk, true)
        XCTAssertEqual(t1.services.first?.httpStatus, 200)
        XCTAssertEqual(t1.services.first?.port, 19200)
        XCTAssertEqual(t1.attackers.count, 2)
        XCTAssertEqual(t1.attackers.first?.state, "running")
    }

    func testAWDStatusResponse() throws {
        let status = try decode(AWDStatusResponse.self, "awd_status")
        XCTAssertTrue(status.ok)
        XCTAssertEqual(status.teams.count, 5)
        let t1 = try XCTUnwrap(status.teams.first { $0.id == "t1" })
        XCTAssertTrue(t1.running)
        XCTAssertTrue(t1.ready)
        XCTAssertTrue(t1.verified)
        XCTAssertEqual(t1.services.first?.state, "running")
        XCTAssertEqual(t1.services.first?.httpStatus, 200)
        let t2 = try XCTUnwrap(status.teams.first { $0.id == "t2" })
        XCTAssertFalse(t2.running)
    }

    func testInviteCarriesTimestamps() throws {
        let response = try decode(InviteResponse.self, "invite")
        let invite = try XCTUnwrap(response.invite)
        // Regression: without CodingKeys these two were always nil and then
        // dropped from the re-encoded JSON shown by the share sheet.
        XCTAssertNotNil(invite.createdAt)
        XCTAssertNotNil(invite.teams?.first?.target?.hostId)
        XCTAssertNotNil(invite.teams?.first?.attacker?.name)
        XCTAssertEqual(invite.teams?.count, 5)
        XCTAssertFalse(invite.notes?.isEmpty ?? true)
    }
}
