import SwiftUI
import AppKit

/// Connections belong to the application, so copied addresses keep working
/// when the user navigates away from a lab or its workspace.
@MainActor
final class LabConnections {
    private struct Route: Hashable {
        let target: PlatformHost
        let port: Int
    }
    private var tunnels: [Route: SSHTunnel] = [:]

    func tunnel(target: PlatformHost, port: Int) -> SSHTunnel {
        let route = Route(target: target, port: port)
        if let tunnel = tunnels[route] { return tunnel }
        let tunnel = SSHTunnel()
        tunnels[route] = tunnel
        return tunnel
    }

    func close(hostIDs: Set<String>) {
        for route in Array(tunnels.keys) where hostIDs.contains(route.target.id) {
            tunnels.removeValue(forKey: route)?.close()
        }
    }

    func closeStoppedLabs(runningIDs: Set<String>) {
        let stopped = Set(tunnels.keys.map(\.target.id).filter {
            $0.hasPrefix("lab-") && !runningIDs.contains(String($0.dropFirst(4)))
        })
        close(hostIDs: stopped)
    }

    func closeAll() {
        for tunnel in tunnels.values { tunnel.close() }
        tunnels.removeAll()
    }
}

extension AppState {
    func labHost(_ lab: Lab) -> PlatformHost {
        let machine = hosts.first { $0.tags.contains("training-target") }
        return PlatformHost(id: "lab-\(lab.id)", name: "Arena · \(lab.name)", role: .target,
                            address: machine?.address ?? "", ports: lab.access.map(\.port),
                            source: "catalog")
    }

    func macURL(for access: LabAccess, target: PlatformHost) async -> URL? {
        guard access.isWeb else { return nil }
        do {
            let port = try await connections.tunnel(target: target, port: access.port)
                .connect(target: target, remotePort: access.port)
            return URL(string: access.address(port: port))
        } catch {
            present(error)
            return nil
        }
    }

    func openOnMac(_ access: LabAccess, lab: Lab) async {
        if let url = await macURL(for: access, target: labHost(lab)) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Both views of an endpoint are labelled explicitly: the remote attack host
/// uses its range address; the Mac uses a checked application-owned SSH tunnel.
struct LabAccessRow: View {
    @EnvironmentObject private var app: AppState
    let access: LabAccess
    let target: PlatformHost
    let running: Bool
    @ObservedObject var tunnel: SSHTunnel
    @State private var working = false

    private var localPort: Int? {
        if case .ready(let port) = tunnel.state { return port }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label(access.label, systemImage: access.isWeb ? "globe" : "network")
                    .font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary)
                Spacer()
                Text(access.isWeb ? access.scheme.uppercased() : "TCP 服务")
                    .font(ArenaType.micro).foregroundStyle(ArenaTheme.textTertiary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac 访问").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                if let port = localPort {
                    Text(access.address(port: port))
                        .font(ArenaType.mono).foregroundStyle(ArenaTheme.textPrimary)
                        .textSelection(.enabled).lineLimit(2)
                    Text("此地址在你的 Mac 上有效，保持应用运行。")
                        .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                } else {
                    Text(running ? "连接后生成本机访问地址" : "环境启动后可连接")
                        .font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary)
                }
            }
            HStack(spacing: 8) {
                GhostButton(title: access.isWeb ? "在 Mac 打开" : "连接到 Mac",
                            systemImage: access.isWeb ? "safari" : "link", busy: working,
                            enabled: running) { connect(open: access.isWeb, copy: false) }
                Button("复制 Mac 地址") { connect(open: false, copy: true) }
                    .buttonStyle(.plain).font(ArenaType.caption.weight(.semibold))
                    .foregroundStyle(ArenaTheme.accent)
                    .disabled(!running || working)
            }
            if let port = localPort, let command = access.clientCommand(port: port) {
                CopyChip(text: command, label: "复制客户端命令")
                    .help("将 YOUR_USER 替换成实际用户名")
            }
            if case .failed(let message) = tunnel.state {
                Text(message).font(ArenaType.caption).foregroundStyle(ArenaTheme.danger)
                    .lineLimit(3)
            }
            Divider()
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arena 内网 · 攻击机使用")
                        .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                    Text(target.address.isEmpty ? "正在同步靶机地址…" : access.address(host: target.address))
                        .font(ArenaType.mono).foregroundStyle(ArenaTheme.textSecondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
                if !target.address.isEmpty {
                    CopyChip(text: access.address(host: target.address), label: "复制内网地址")
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(ArenaTheme.tint(0.025)))
    }

    private func connect(open: Bool, copy: Bool) {
        guard !working else { return }
        working = true
        Task {
            defer { working = false }
            do {
                let port = try await tunnel.connect(target: target, remotePort: access.port)
                let address = access.address(port: port)
                if copy {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(address, forType: .string)
                    app.show(ActivityBanner(text: "已复制 Mac 可用地址", success: true))
                }
                if open, let url = URL(string: address) { NSWorkspace.shared.open(url) }
            } catch {
                // The connection state carries the error next to its endpoint.
            }
        }
    }
}
