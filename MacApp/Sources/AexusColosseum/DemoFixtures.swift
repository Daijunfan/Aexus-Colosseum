import Foundation

#if DEBUG
// Development-only preview data.  It is compiled into debug builds solely so
// the Arena UI can be reviewed when the lab server is unreachable; release
// builds never contain it.  Enable with AEXUS_UI=awd-demo.
@MainActor
enum DemoFixtures {
    static let eventID = "demo-awd"

    static func install(into app: AppState) {
        let teamCount = 5
        var teams: [EventTeam] = []
        var hosts: [PlatformHost] = []
        var statuses: [AWDTeamStatus] = []
        var results: [AWDVerifyResult] = []

        // 队 1 / 队 2 已通过实战验证，队 3 正在运行待验证，队 4、5 保持停止。
        let verified = [true, true, false, false, false]
        let running = [true, true, true, false, false]

        for team in 1...teamCount {
            var serviceIDs: [String] = []
            var attackerIDs: [String] = []
            var serviceStatus: [AWDHostStatus] = []
            var attackerStatus: [AWDHostStatus] = []

            for index in 1...2 {
                let id = "awd-t\(team)-s\(index)"
                serviceIDs.append(id)
                let port = 19200 + (team - 1) * 10 + index
                hosts.append(PlatformHost(
                    id: id,
                    name: "Arena 队 \(team) 服务机 S\(index)",
                    role: .target,
                    address: "10.77.90.10",
                    ports: [port],
                    docker: HostDocker(container: "Arena-awd-demo-t\(team)-s\(index)"),
                    tags: ["awd", "service"],
                    notes: "Arena 创建 · DVWA 靶标"))
                serviceStatus.append(AWDHostStatus(
                    hostId: id,
                    container: "Arena-awd-demo-t\(team)-s\(index)",
                    state: running[team - 1] ? "running" : "exited",
                    httpOk: running[team - 1] ? true : nil,
                    httpStatus: running[team - 1] ? 200 : nil,
                    port: port))
            }
            for index in 1...2 {
                let id = "awd-t\(team)-a\(index)"
                attackerIDs.append(id)
                hosts.append(PlatformHost(
                    id: id,
                    name: "Arena 队 \(team) 攻击机 A\(index)",
                    role: .attacker,
                    docker: HostDocker(container: "Arena-awd-demo-t\(team)-a\(index)"),
                    tags: ["awd", "attacker"],
                    notes: "Arena 创建 · 攻击工作台"))
                attackerStatus.append(AWDHostStatus(
                    hostId: id,
                    container: "Arena-awd-demo-t\(team)-a\(index)",
                    state: running[team - 1] ? "running" : "exited"))
            }

            let teamID = "team-\(team)"
            teams.append(EventTeam(
                id: teamID,
                name: "队 \(team)",
                services: serviceIDs,
                attackers: attackerIDs,
                verified: verified[team - 1],
                verifiedAt: verified[team - 1] ? "2026-11-15T12:00:00+08:00" : nil,
                verifiedDetail: verified[team - 1] ? "HTTP 200 · 攻击机 → 服务机 2/2 可达" : nil))
            statuses.append(AWDTeamStatus(
                id: teamID,
                name: "队 \(team)",
                running: running[team - 1],
                ready: running[team - 1],
                verified: verified[team - 1],
                services: serviceStatus,
                attackers: attackerStatus))
            if verified[team - 1] {
                results.append(AWDVerifyResult(
                    teamId: teamID,
                    ok: true,
                    detail: "HTTP 200 · 攻击机 → 服务机 2/2 可达",
                    services: serviceStatus,
                    attackers: attackerStatus))
            }
        }

        let event = ArenaEvent(
            id: eventID,
            name: "Arena 竞技场 · 演示",
            format: "awd",
            status: "running",
            teams: teams,
            hosts: hosts.map(\.id),
            observer: true,
            agents: false,
            invite: nil,
            createdAt: "2026-11-15T11:40:00+08:00",
            startedAt: "2026-11-15T11:45:00+08:00",
            endedAt: nil,
            awd: true)

        app.hosts = hosts
        app.events = [event]
        app.selectedEventID = eventID
        app.awdTeams[eventID] = statuses
        app.awdVerifyResults[eventID] = results
        app.eventStatuses[eventID] = EventStatus(
            ok: true, event: event, hosts: [], probes: [:], agents: [], activities: [], error: nil)
        app.platformLoaded = true
    }
}
#endif
