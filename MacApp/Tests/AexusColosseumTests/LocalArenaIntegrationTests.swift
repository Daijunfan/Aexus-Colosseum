import XCTest
import SwiftUI
import AppKit
@testable import AexusColosseum

/// Optional end-to-end check against a real `arenactl` + Docker host.
/// Enable it with:
///
///   AEXUS_LOCAL_ARENA=1 \
///   AEXUS_LOCAL_EVENT=e-xxxxxxxx \
///   AEXUS_ARENA_HOST=127.0.0.1 AEXUS_ARENA_PORT=... AEXUS_ARENA_USER=djf \
///   AEXUS_ARENA_KEY=~/.colima/_lima/_config/user \
///   swift test --filter LocalArenaIntegrationTests
final class LocalArenaIntegrationTests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    func testRealArenaRoundTrip() async throws {
        guard env["AEXUS_LOCAL_ARENA"] == "1" else {
            throw XCTSkip("set AEXUS_LOCAL_ARENA=1 to run against a real arena")
        }
        let eventID = try XCTUnwrap(env["AEXUS_LOCAL_EVENT"])

        let events = try await PlatformAPI.events()
        let event = try XCTUnwrap(events.first { $0.id == eventID })
        XCTAssertEqual(event.awd, true)
        XCTAssertEqual(event.teams.count, 2)
        XCTAssertTrue(event.teams.allSatisfy { $0.allServices.count == 1 && $0.allAttackers.count == 1 })

        let teams = try await PlatformAPI.awdStatus(eventID: eventID)
        let t1 = try XCTUnwrap(teams.first { $0.id == "t1" })
        XCTAssertTrue(t1.verified, "a passing team must remain verified after stop")
        XCTAssertNotNil(t1.verifiedDetail)
        XCTAssertFalse(t1.running)
        XCTAssertEqual(t1.services.first?.state, "exited")
        XCTAssertEqual(t1.services.first?.port, 19200)
        XCTAssertEqual(teams.first { $0.id == "t2" }?.verified, false)

        let invite = try await PlatformAPI.invite(eventID)
        XCTAssertEqual(invite.invite?.id, eventID)
        XCTAssertNotNil(invite.invite?.createdAt, "invite timestamps must decode")
    }

    /// The exact state the event detail page renders from: after `verify` a
    /// passing team must appear as verified even though it is stopped again.
    @MainActor
    func testAppStatePublishesVerifiedTeam() async throws {
        guard env["AEXUS_LOCAL_ARENA"] == "1" else {
            throw XCTSkip("set AEXUS_LOCAL_ARENA=1 to run against a real arena")
        }
        let eventID = try XCTUnwrap(env["AEXUS_LOCAL_EVENT"])
        let app = AppState()
        app.events = try await PlatformAPI.events()
        app.hosts = try await PlatformAPI.hosts()
        await app.refreshAWDStatus(for: eventID)

        let teams = try XCTUnwrap(app.awdTeams[eventID])
        let t1 = try XCTUnwrap(teams.first { $0.id == "t1" })
        XCTAssertTrue(t1.verified)
        XCTAssertEqual(t1.verifiedDetail?.contains("HTTP 302"), true)
        XCTAssertFalse(t1.running)
        XCTAssertEqual(t1.services.first?.state, "exited")
        XCTAssertNotNil(app.events.first { $0.id == eventID })
        XCTAssertEqual(app.generalHosts.count, 0, "AWD machines must stay out of the general host list")
    }

    /// Renders the real AWD panel offscreen with live server data, so the
    /// "verified team is visible on the page" requirement can be inspected
    /// without opening a window.
    @MainActor
    func testAWDControlPanelRendersVerifiedTeam() async throws {
        guard env["AEXUS_LOCAL_ARENA"] == "1" else {
            throw XCTSkip("set AEXUS_LOCAL_ARENA=1 to run against a real arena")
        }
        let eventID = try XCTUnwrap(env["AEXUS_LOCAL_EVENT"])
        let app = AppState()
        app.events = try await PlatformAPI.events()
        app.hosts = try await PlatformAPI.hosts()
        await app.refreshAWDStatus(for: eventID)
        let event = try XCTUnwrap(app.events.first { $0.id == eventID })

        let content = AWDControlPanel(event: event)
            .environmentObject(app)
            .frame(width: 1060)
            .padding(24)
            .background(ArenaTheme.background)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let cgImage = try XCTUnwrap(renderer.cgImage, "SwiftUI could not render the AWD panel")
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let url = URL(fileURLWithPath: env["AEXUS_SNAPSHOT"] ?? "/tmp/arena-awd-panel.png")
        try png.write(to: url)
        XCTAssertGreaterThan(png.count, 10_000)
        print("AWD panel snapshot: \(url.path)")
    }
}
