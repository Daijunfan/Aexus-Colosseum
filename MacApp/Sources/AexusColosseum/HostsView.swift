import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Screen

struct HostsView: View {
    @EnvironmentObject private var app: AppState
    @State private var addHostOpen = false
    @State private var editingHost: PlatformHost?
    @State private var topologySheetOpen = false
    @State private var deleteTarget: HostsDeleteTarget?
    @State private var deploying = false

    private var busy: Bool { app.platformLoading || !app.probeBusy.isEmpty }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if busy { busyStrip.transition(.opacity.combined(with: .move(edge: .top))) }
                statStrip
                HostsRatioColumns(ratio: 0.58, spacing: 18) {
                    inventory
                    topologyPanel
                }
            }
            .padding(.horizontal, 30).padding(.top, 24).padding(.bottom, 40)
            .frame(maxWidth: 1320, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(ArenaTheme.background.opacity(0.001))
        .animation(Motion.page, value: busy)
        .sheet(isPresented: $addHostOpen) { AddHostSheet().environmentObject(app) }
        .sheet(item: $editingHost) { host in
            AddHostSheet(editing: host).id(host.id).environmentObject(app)
        }
        .sheet(isPresented: $topologySheetOpen) { CreateTopologySheet().environmentObject(app) }
        .alert(deleteTitle, isPresented: deleteBinding, presenting: deleteTarget) { target in
            Button("删除", role: .destructive) { performDelete(target) }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: { target in Text(deleteMessage(target)) }
        .task(id: app.hosts.map(\.id).joined(separator: ",")) {
            // Landing on this screen should tell the truth about the hosts,
            // not show every one as "未探测".  Hosts usually arrive after the
            // screen appears, so key the task on the inventory as well.
            if app.hostProbes.isEmpty, !app.hosts.isEmpty {
                await app.probeAllHosts()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("HOSTS & TOPOLOGY").font(ArenaType.micro).tracking(2.2).foregroundStyle(ArenaTheme.accent.opacity(0.9))
                    Rectangle().fill(ArenaTheme.accent.opacity(0.4)).frame(width: 26, height: 1)
                }
                Text("主机与拓扑").font(.system(size: 38, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                Text("把攻击机、靶机和服务机绑定成一个可验证的拓扑。").font(.system(size: 13)).foregroundStyle(ArenaTheme.textSecondary)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    GhostButton(title: "导入", systemImage: "square.and.arrow.down") { importHosts() }
                    GhostButton(title: "导出", systemImage: "square.and.arrow.up", enabled: !app.hosts.isEmpty) { exportHosts() }
                    GhostButton(title: "探测全部", systemImage: "dot.radiowaves.left.and.right",
                                busy: !app.probeBusy.isEmpty, enabled: !app.hosts.isEmpty) {
                        Task { await app.probeAllHosts() }
                    }
                }
                HStack(spacing: 8) {
                    GhostButton(title: "启动 Arena-Kali", systemImage: "shippingbox", tint: ArenaTheme.accent, busy: deploying) { deployAttackBox() }
                    if app.kaliVM?.running == true {
                        GhostButton(title: "关闭 Kali", systemImage: "power", busy: app.platformLoading) {
                            Task { await app.stopKali() }
                        }
                    }
                    AccentButton(title: "添加主机", systemImage: "plus") { addHostOpen = true }
                }
            }
        }
    }

    private var busyStrip: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).scaleEffect(0.8)
            Text(app.platformLoading ? "正在与 Arena 同步主机与拓扑…" : "正在探测 \(app.probeBusy.count) 台主机…")
                .font(ArenaType.callout).foregroundStyle(ArenaTheme.textSecondary)
            Spacer()
            Text("请保持连接").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .arenaCard(radius: 12, fill: ArenaTheme.card.opacity(0.7), shadow: false)
    }

    private var statStrip: some View {
        HStack(spacing: 10) {
            statTile("\(app.generalHosts.count)", "主机数", "server.rack", ArenaTheme.textSecondary)
            statTile("\(app.attackerHosts.count)", "攻击机", "bolt.shield.fill", ArenaTheme.accent)
            statTile("\(app.targetHosts.count)", "靶机", "shield.lefthalf.filled", ArenaTheme.ember)
            statTile("\(app.generalOnlineCount)", "在线", "dot.radiowaves.left.and.right", ArenaTheme.success,
                     fraction: app.generalHosts.isEmpty ? nil : Double(app.generalOnlineCount) / Double(app.generalHosts.count))
        }
    }

    private func statTile(_ value: String, _ label: String, _ symbol: String,
                          _ tint: Color, fraction: Double? = nil) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.11))
                Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(tint)
            }.frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(ArenaTheme.textPrimary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer(minLength: 4)
            if let fraction {
                Meter(fraction: max(0, min(1, fraction)), tint: tint).frame(width: 34)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .arenaCard(radius: 13, shadow: false)
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("主机清单").font(.system(size: 17, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                Text("\(app.generalHosts.count) 台").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                Spacer()
                if !app.generalHosts.isEmpty {
                    Text("\(app.generalOnlineCount) 在线").font(ArenaType.caption)
                        .foregroundStyle(app.generalOnlineCount > 0 ? ArenaTheme.success : ArenaTheme.textTertiary)
                }
            }
            if hostGroups.isEmpty {
                emptyInventory
            } else {
                ForEach(hostGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        groupHeader(group)
                        VStack(spacing: 8) {
                            ForEach(group.hosts) { host in
                                InventoryHostCard(host: host,
                                                  onEdit: { editingHost = host },
                                                  onDelete: { deleteTarget = .host(host) })
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupHeader(_ group: HostGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: group.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(group.tint)
            Text(group.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(ArenaTheme.textSecondary)
            Text("\(group.hosts.count)").font(ArenaType.caption).foregroundStyle(ArenaTheme.textQuaternary)
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
        }.padding(.top, 2)
    }

    private var emptyInventory: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack").font(.system(size: 30, weight: .light)).foregroundStyle(ArenaTheme.textQuaternary)
            Text("还没有接入任何主机").font(.system(size: 14, weight: .semibold)).foregroundStyle(ArenaTheme.textSecondary)
            Text("添加一台主机，或启动独立的 Arena-Kali 虚拟机，再把攻击机与靶机绑定成可验证的拓扑。")
                .font(ArenaType.callout).foregroundStyle(ArenaTheme.textTertiary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            HStack(spacing: 8) {
                AccentButton(title: "添加主机", systemImage: "plus") { addHostOpen = true }
                GhostButton(title: "启动 Arena-Kali", systemImage: "shippingbox", tint: ArenaTheme.accent, busy: deploying) { deployAttackBox() }
            }.padding(.top, 2)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 34)
        .arenaCard(radius: Radius.card, fill: ArenaTheme.card.opacity(0.7))
    }

    private var hostGroups: [HostGroup] {
        var groups: [HostGroup] = []
        if !app.attackerHosts.isEmpty {
            groups.append(HostGroup(id: "attacker", title: "攻击机", symbol: "bolt.shield.fill",
                                    tint: ArenaTheme.accent, hosts: app.attackerHosts))
        }
        if !app.targetHosts.isEmpty {
            groups.append(HostGroup(id: "target", title: "靶机 / 服务机", symbol: "shield.lefthalf.filled",
                                    tint: ArenaTheme.ember, hosts: app.targetHosts))
        }
        if !app.observerHosts.isEmpty {
            groups.append(HostGroup(id: "observer", title: "观察机", symbol: "eye.fill",
                                    tint: ArenaTheme.success, hosts: app.observerHosts))
        }
        return groups
    }

    private var topologyPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("拓扑").font(.system(size: 17, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                    Text("\(app.topologies.count) 条 · \(app.readyTopologyCount) 条就绪")
                        .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                }
                Spacer(minLength: 8)
                AccentButton(title: "新建拓扑", systemImage: "plus") { topologySheetOpen = true }
            }
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
            if app.topologies.isEmpty {
                emptyTopology
            } else {
                VStack(spacing: 9) {
                    ForEach(app.topologies) { topology in
                        TopologyPanelRow(topology: topology) { deleteTarget = .topology(topology) }
                    }
                }
            }
        }.padding(16).arenaCard(radius: Radius.panel)
    }

    private var emptyTopology: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "network").font(.system(size: 22, weight: .light)).foregroundStyle(ArenaTheme.textQuaternary)
            Text("还没有拓扑").font(.system(size: 14, weight: .semibold)).foregroundStyle(ArenaTheme.textSecondary)
            Text("一条拓扑由一台攻击机和一台靶机组成。创建后可以一键检测攻击机是否能访问靶机。")
                .font(ArenaType.callout).foregroundStyle(ArenaTheme.textTertiary).fixedSize(horizontal: false, vertical: true)
            GhostButton(title: "新建拓扑", systemImage: "plus") { topologySheetOpen = true }.padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ArenaTheme.tint(0.025))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ArenaTheme.tint(0.07), lineWidth: 0.8)))
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    private var deleteTitle: String {
        switch deleteTarget {
        case .some(.host(let host)): return "删除主机「\(host.name)」？"
        case .some(.topology(let topology)): return "删除拓扑「\(topology.name)」？"
        case .none: return "确认删除"
        }
    }

    private func deleteMessage(_ target: HostsDeleteTarget) -> String {
        switch target {
        case .host: return "删除后需要重新添加才能参与探测。引用该主机的拓扑会一并移除，主机上的数据不受影响。"
        case .topology: return "仅移除拓扑绑定，攻击机与靶机本身都会保留。"
        }
    }

    private func performDelete(_ target: HostsDeleteTarget) {
        deleteTarget = nil
        Task { @MainActor in
            switch target {
            case .host(let host): await app.deleteHost(host)
            case .topology(let topology): await app.deleteTopology(topology)
            }
        }
    }

    private func deployAttackBox() {
        guard !deploying else { return }
        Task { @MainActor in
            deploying = true
            await app.deployAttackHost()
            deploying = false
        }
    }

    private func importHosts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "导入主机"
        panel.prompt = "导入"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { @MainActor in
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let hosts = try HostsImport.decode(try Data(contentsOf: url))
                guard !hosts.isEmpty else { app.presentError("文件中没有可导入的主机。"); return }
                let before = app.hosts.count
                for host in hosts { await app.addHost(host) }
                let added = app.hosts.count - before
                if added > 0 {
                    app.show(ActivityBanner(text: "已导入 \(added) 台主机", success: true))
                } else if app.errorMessage == nil {
                    app.presentError("导入失败：没有主机被添加，请检查主机数据与 Arena 连接。")
                }
            } catch {
                app.presentError("导入失败：\((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
        }
    }

    private func exportHosts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "arena-hosts.json"
        panel.title = "导出主机"
        panel.prompt = "导出"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(HostsExport(hosts: app.generalHosts)).write(to: url, options: .atomic)
            app.show(ActivityBanner(text: "已导出 \(app.generalHosts.count) 台主机", success: true))
        } catch {
            app.presentError("导出失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - Two-column layout

private struct HostsRatioColumns: Layout {
    var ratio: CGFloat = 0.58
    var spacing: CGFloat = 18

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 1000
        let available = max(0, total - spacing)
        let left = available * ratio
        var height: CGFloat = 0
        if subviews.indices.contains(0) {
            height = max(height, subviews[0].sizeThatFits(ProposedViewSize(width: left, height: nil)).height)
        }
        if subviews.indices.contains(1) {
            height = max(height, subviews[1].sizeThatFits(ProposedViewSize(width: available - left, height: nil)).height)
        }
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let available = max(0, bounds.width - spacing)
        let left = available * ratio
        if subviews.indices.contains(0) {
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY),
                              proposal: ProposedViewSize(width: left, height: nil))
        }
        if subviews.indices.contains(1) {
            subviews[1].place(at: CGPoint(x: bounds.minX + left + spacing, y: bounds.minY),
                              proposal: ProposedViewSize(width: available - left, height: nil))
        }
    }
}

// MARK: - Inventory

private struct HostGroup: Identifiable {
    var id: String
    var title: String
    var symbol: String
    var tint: Color
    var hosts: [PlatformHost]
}

private struct InventoryHostCard: View {
    @EnvironmentObject private var app: AppState
    var host: PlatformHost
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var hovering = false

    private var probe: HostProbe? { app.hostProbes[host.id] }
    private var status: (text: String, color: Color) {
        guard let probe else { return ("未探测", ArenaTheme.textQuaternary) }
        return probe.online ? ("在线", ArenaTheme.success) : ("离线", ArenaTheme.danger)
    }
    private var detail: String {
        guard let probe else { return "尚未探测" }
        return probe.detail ?? probe.error ?? (probe.online ? "探测成功" : "无法连接")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(host.role.tint.opacity(0.13))
                    Image(systemName: host.role.symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(host.role.tint)
                }.frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(host.name).font(ArenaType.cardTitle).foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                        Chip(text: host.role.label, color: host.role.tint)
                    }
                    Text(host.displayAddress).font(ArenaType.mono).foregroundStyle(ArenaTheme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                HStack(spacing: 5) {
                    StatusDot(color: status.color, pulsing: probe?.online == true)
                    Text(status.text).font(ArenaType.caption.weight(.medium)).foregroundStyle(status.color)
                }
            }
            HStack(spacing: 6) {
                Chip(text: host.transportLabel, color: ArenaTheme.textTertiary)
                if let ssh = probe?.sshOk {
                    Chip(text: ssh ? "SSH OK" : "SSH 失败", color: ssh ? ArenaTheme.success : ArenaTheme.danger)
                }
                if let docker = probe?.dockerOk {
                    Chip(text: docker ? "Docker OK" : "Docker 失败", color: docker ? ArenaTheme.success : ArenaTheme.danger)
                }
                if let latency = probe?.latencyMs {
                    Text("\(latency) ms").font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary).monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(ArenaTheme.hairline).frame(height: 1)
            HStack(spacing: 8) {
                Text(detail).font(ArenaType.caption)
                    .foregroundStyle(probe?.error != nil ? ArenaTheme.danger : ArenaTheme.textTertiary)
                    .lineLimit(1).help(detail)
                Spacer(minLength: 6)
                GhostButton(title: "探测", systemImage: "dot.radiowaves.left.and.right",
                            busy: app.probeBusy.contains(host.id)) { Task { await app.probeHost(host) } }
                RoundIconButton(systemImage: "pencil", tint: ArenaTheme.textTertiary, help: "编辑主机") { onEdit() }
                RoundIconButton(systemImage: "trash", tint: ArenaTheme.textTertiary, help: "删除主机") { onDelete() }
            }
        }
        .padding(13)
        .arenaCard(radius: 14, fill: hovering ? ArenaTheme.cardHover : ArenaTheme.card)
        .onHover { value in withAnimation(Motion.hover) { hovering = value } }
    }
}

// MARK: - Topology

private struct TopologyPanelRow: View {
    @EnvironmentObject private var app: AppState
    var topology: Topology
    var onDelete: () -> Void

    private var status: (text: String, color: Color) {
        switch topology.status {
        case "ready": return ("就绪", ArenaTheme.success)
        case "partial": return ("部分可用", ArenaTheme.warning)
        case "offline": return ("离线", ArenaTheme.danger)
        default: return ("未知", ArenaTheme.textTertiary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(topology.name).font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary).lineLimit(1)
                Spacer(minLength: 6)
                Chip(text: status.text, color: status.color)
            }
            HStack(spacing: 6) {
                Image(systemName: "bolt.shield.fill").font(.system(size: 9)).foregroundStyle(ArenaTheme.accent)
                Text(app.host(topology.attacker)?.name ?? "未知攻击机")
                    .font(ArenaType.caption).foregroundStyle(ArenaTheme.textSecondary).lineLimit(1)
                Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold)).foregroundStyle(ArenaTheme.textQuaternary)
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 9)).foregroundStyle(ArenaTheme.ember)
                Text(app.host(topology.target)?.name ?? "未知靶机")
                    .font(ArenaType.caption).foregroundStyle(ArenaTheme.textSecondary).lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack(spacing: 7) {
                Spacer()
                GhostButton(title: "检测", systemImage: "waveform.path.ecg",
                            busy: app.topologyBusy.contains(topology.id)) { Task { await app.testTopology(topology.id) } }
                RoundIconButton(systemImage: "trash", tint: ArenaTheme.textTertiary, help: "删除拓扑") { onDelete() }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ArenaTheme.tint(0.025))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ArenaTheme.tint(0.06), lineWidth: 0.8)))
    }
}

private enum HostsDeleteTarget {
    case host(PlatformHost)
    case topology(Topology)
}

// MARK: - Sheet chrome & fields

private struct HostsSheetShell<Content: View>: View {
    var eyebrow: String
    var title: String
    var message: String
    var symbol: String
    var saveTitle: String
    var saveEnabled: Bool
    var busy: Bool
    var contentHeight: CGFloat
    var onCancel: () -> Void
    var onSave: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(ArenaTheme.accent.opacity(0.12))
                    Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(ArenaTheme.accent)
                }.frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow).font(ArenaType.micro).tracking(1.4).foregroundStyle(ArenaTheme.accent)
                    Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(ArenaTheme.textPrimary)
                    Text(message).font(ArenaType.callout).foregroundStyle(ArenaTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }
            .padding(20).background(ArenaTheme.backgroundTop.opacity(0.6)).hairlineDivider()
            ScrollView(showsIndicators: false) { content.padding(20) }.frame(height: contentHeight)
            HStack(spacing: 9) {
                Spacer()
                GhostButton(title: "取消", action: onCancel)
                AccentButton(title: saveTitle, systemImage: "checkmark", busy: busy,
                             enabled: saveEnabled, action: onSave)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(ArenaTheme.backgroundTop.opacity(0.6))
            .overlay(alignment: .top) { Rectangle().fill(ArenaTheme.hairline).frame(height: 1) }
        }
        .frame(width: 580).background(ArenaTheme.background)
    }
}

private struct HostsField: View {
    var label: String
    var placeholder: String
    @Binding var text: String
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(ArenaType.micro).tracking(0.8).foregroundStyle(ArenaTheme.textTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain).font(.system(size: 12.5)).foregroundStyle(ArenaTheme.textPrimary)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ArenaTheme.tint(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ArenaTheme.tint(0.09), lineWidth: 0.8))
            if let hint {
                Text(hint).font(ArenaType.caption).foregroundStyle(ArenaTheme.textQuaternary)
            }
        }
    }
}

private struct HostsFormField<Content: View>: View {
    var label: String
    var hint: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(ArenaType.micro).tracking(0.8).foregroundStyle(ArenaTheme.textTertiary)
            content
            if let hint {
                Text(hint).font(ArenaType.caption).foregroundStyle(ArenaTheme.textQuaternary)
            }
        }
    }
}

private struct HostsFormToggle: View {
    var title: String
    var caption: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ArenaType.headline).foregroundStyle(ArenaTheme.textPrimary)
                Text(caption).font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().tint(ArenaTheme.accent)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArenaTheme.tint(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.07), lineWidth: 0.8))
    }
}

private struct HostsHostPicker: View {
    var placeholder: String
    var hosts: [PlatformHost]
    @Binding var selection: String

    var body: some View {
        Picker("", selection: $selection) {
            Text(placeholder).tag("")
            ForEach(hosts) { host in
                Text("\(host.name) · \(host.displayAddress)").tag(host.id)
            }
        }
        .labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ArenaTheme.tint(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(ArenaTheme.tint(0.09), lineWidth: 0.8))
    }
}

// MARK: - Add host

private struct AddHostSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var editing: PlatformHost?

    @State private var name = ""
    @State private var role: HostRole = .target
    @State private var address = ""
    @State private var ports = ""
    @State private var sshEnabled = false
    @State private var sshUser = "root"
    @State private var sshPort = "22"
    @State private var sshKey = ""
    @State private var sshJump = ""
    @State private var dockerEnabled = false
    @State private var dockerContainer = ""
    @State private var saving = false

    init(editing: PlatformHost? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _role = State(initialValue: editing?.role ?? .target)
        _address = State(initialValue: editing?.address ?? "")
        _ports = State(initialValue: (editing?.ports ?? []).map { String($0) }.joined(separator: ", "))
        let ssh = editing?.ssh
        _sshEnabled = State(initialValue: ssh != nil)
        _sshUser = State(initialValue: ssh?.user ?? "root")
        _sshPort = State(initialValue: String(ssh?.port ?? 22))
        _sshKey = State(initialValue: ssh?.key ?? "")
        _sshJump = State(initialValue: ssh?.jump ?? "")
        let docker = editing?.docker
        _dockerEnabled = State(initialValue: docker != nil)
        _dockerContainer = State(initialValue: docker?.container ?? "")
    }

    private var canSave: Bool {
        guard !name.trimmed.isEmpty else { return false }
        let container = dockerEnabled ? dockerContainer.trimmed : ""
        return !address.trimmed.isEmpty || !container.isEmpty
    }

    private var parsedPorts: [Int] {
        ports.split(separator: ",").compactMap { Int(String($0).trimmingCharacters(in: .whitespaces)) }
    }

    var body: some View {
        HostsSheetShell(
            eyebrow: editing == nil ? "NEW HOST" : "EDIT HOST",
            title: editing == nil ? "添加主机" : "编辑主机",
            message: editing == nil
                ? "地址或 Docker 容器至少填写一项。保存后会立即出现在主机清单中。"
                : "修改名称、角色或连接方式，保存后立即更新主机清单。",
            symbol: editing == nil ? "server.rack" : "pencil",
            saveTitle: editing == nil ? "添加主机" : "保存修改",
            saveEnabled: canSave, busy: saving, contentHeight: 520,
            onCancel: { dismiss() }, onSave: save) {
            VStack(alignment: .leading, spacing: 14) {
                HostsField(label: "名称", placeholder: "例如：内网靶机 web01", text: $name)
                HostsFormField(label: "角色") {
                    Picker("角色", selection: $role) {
                        ForEach(HostRole.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
                HStack(alignment: .top, spacing: 12) {
                    HostsField(label: "地址（host / IP）", placeholder: "10.0.0.12", text: $address)
                    HostsField(label: "端口（逗号分隔）", placeholder: "22, 80, 443", text: $ports)
                        .frame(width: 180)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HostsFormToggle(title: "通过 SSH 探测", caption: "使用密钥登录获取主机指纹", isOn: $sshEnabled)
                    if sshEnabled {
                        HStack(alignment: .top, spacing: 12) {
                            HostsField(label: "用户名", placeholder: "root", text: $sshUser)
                            HostsField(label: "SSH 端口", placeholder: "22", text: $sshPort).frame(width: 130)
                        }
                        HostsField(label: "密钥路径", placeholder: "~/.ssh/id_ed25519",
                                   text: $sshKey, hint: "留空则使用 Arena 的默认密钥")
                        HostsField(label: "跳板机", placeholder: "bupt208 或 user@host", text: $sshJump)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HostsFormToggle(title: "运行在 Docker 容器中", caption: "通过容器名在 Arena 内部探测",
                                    isOn: $dockerEnabled)
                    if dockerEnabled {
                        HostsField(label: "容器名称", placeholder: "arena-attackbox",
                                   text: $dockerContainer, hint: "例如 arena-attackbox")
                    }
                }
            }
        }
    }

    private func save() {
        guard canSave, !saving else { return }
        let user = sshUser.trimmed, key = sshKey.trimmed, jump = sshJump.trimmed
        let ssh = sshEnabled ? HostSSH(port: Int(sshPort.trimmed) ?? 22,
                                       user: user.isEmpty ? "root" : user, key: key,
                                       jump: jump.isEmpty ? nil : jump) : nil
        let docker = dockerEnabled
            ? HostDocker(container: dockerContainer.trimmed, host: address.trimmed.isEmpty ? nil : address.trimmed) : nil

        if let editing {
            let host = PlatformHost(id: editing.id, name: name.trimmed, role: role,
                                    address: address.trimmed, ports: parsedPorts, ssh: ssh,
                                    docker: docker, source: editing.source, tags: editing.tags,
                                    notes: editing.notes, createdAt: editing.createdAt)
            let label = name.trimmed
            saving = true
            Task { @MainActor in
                do {
                    let saved = try await PlatformAPI.updateHost(host)
                    await app.loadPlatform()
                    if let target = app.hosts.first(where: { $0.id == editing.id }) ?? saved {
                        await app.probeHost(target)
                    }
                    app.show(ActivityBanner(text: "已保存主机 \(label)", success: true))
                    saving = false
                    dismiss()
                } catch {
                    saving = false
                    app.present(error)
                }
            }
            return
        }

        let host = PlatformHost(id: "", name: name.trimmed, role: role, address: address.trimmed,
                                ports: parsedPorts, ssh: ssh, docker: docker, source: "manual")
        saving = true
        Task { @MainActor in
            await app.addHost(host)
            saving = false
            dismiss()
        }
    }
}

// MARK: - Create topology

private struct CreateTopologySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetID = ""
    @State private var attackerID = ""
    @State private var saving = false

    private var canSave: Bool { !name.trimmed.isEmpty && !targetID.isEmpty && !attackerID.isEmpty }

    var body: some View {
        HostsSheetShell(
            eyebrow: "NEW TOPOLOGY", title: "新建拓扑",
            message: "选择一台攻击机和一台靶机。创建后会自动检测攻击机能否访问靶机。",
            symbol: "network", saveTitle: "创建拓扑",
            saveEnabled: canSave, busy: saving, contentHeight: 300,
            onCancel: { dismiss() }, onSave: save) {
            VStack(alignment: .leading, spacing: 14) {
                HostsField(label: "拓扑名称", placeholder: "例如：内网横向验证", text: $name)
                HostsFormField(label: "靶机", hint: "被攻击的一端") {
                    if app.targetHosts.isEmpty {
                        Text("还没有靶机或服务机，请先在左侧添加。")
                            .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                    } else {
                        HostsHostPicker(placeholder: "选择靶机", hosts: app.targetHosts, selection: $targetID)
                    }
                }
                HostsFormField(label: "攻击机", hint: "发起访问的一端") {
                    if app.attackerHosts.isEmpty {
                        Text("还没有攻击机，可先启动 Arena-Kali 独立虚拟机。")
                            .font(ArenaType.caption).foregroundStyle(ArenaTheme.textTertiary)
                    } else {
                        HostsHostPicker(placeholder: "选择攻击机", hosts: app.attackerHosts, selection: $attackerID)
                    }
                }
            }
        }
    }

    private func save() {
        guard canSave, !saving else { return }
        saving = true
        let topologyName = name.trimmed
        Task { @MainActor in
            await app.createTopology(name: topologyName, target: targetID, attacker: attackerID)
            saving = false
            dismiss()
        }
    }
}

// MARK: - Import / export payloads

private struct HostsExport: Encodable {
    var hosts: [PlatformHost]
}

private enum HostsImport {
    static func decode(_ data: Data) throws -> [PlatformHost] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([PlatformHost].self, from: data) { return list }
        if let envelope = try? decoder.decode(HostsEnvelope.self, from: data), let hosts = envelope.hosts {
            return hosts
        }
        throw HostsImportError.invalidFormat
    }
}

private struct HostsEnvelope: Decodable {
    var hosts: [PlatformHost]?
}

private enum HostsImportError: LocalizedError {
    case invalidFormat
    var errorDescription: String? { "JSON 结构不正确，需要主机数组或包含 hosts 字段的对象。" }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
