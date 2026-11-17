import Foundation

// MARK: - Catalog

struct CatalogCategory: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let color: String
    let blurb: String
}

struct LabAccess: Identifiable, Codable, Hashable {
    var label: String
    var port: Int
    var scheme: String
    var path: String

    var id: String { "\(scheme)-\(port)-\(path)" }

    /// Address inside the Arena network. A Mac address requires a live forward.
    var urlString: String { address() }

    func address(host: String = "127.0.0.1", port forwardedPort: Int? = nil) -> String {
        let port = forwardedPort ?? port
        let host = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        if scheme == "http" || scheme == "https" {
            let suffix = path.isEmpty ? "/" : path
            return "\(scheme)://\(host):\(port)\(suffix)"
        }
        return "\(host):\(port)"
    }

    var isWeb: Bool { scheme == "http" || scheme == "https" }

    func clientCommand(port forwardedPort: Int) -> String? {
        switch port {
        case 3306, 3307: return "mysql --host=127.0.0.1 --port=\(forwardedPort) --user=YOUR_USER -p"
        case 5432, 5433: return "psql --host=127.0.0.1 --port=\(forwardedPort) --username=YOUR_USER"
        case 6379: return "redis-cli -h 127.0.0.1 -p \(forwardedPort)"
        case 22, 2222, 8022: return "ssh -p \(forwardedPort) YOUR_USER@127.0.0.1"
        default: return nil
        }
    }
}

struct LabContainer: Identifiable, Codable, Hashable {
    var id: String
    var state: String
    var status: String
    var name: String

    var isRunning: Bool { state == "running" }
}

struct Lab: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let category: String
    let source: String
    let sourcePath: String?
    let sourceURL: String?
    let difficulty: Int
    let tags: [String]
    let summary: String
    let objectives: [String]
    let mitre: [String]
    let access: [LabAccess]
    let credentials: String
    let notes: String
    let ramMB: Int
    let cpu: Double
    let build: Bool
    let compose: String

    // Runtime (merged in by arenactl list)
    var installed: Bool
    var running: Bool
    var memBytes: Int
    var memHuman: String
    var containers: [LabContainer]
    var startedAt: String?

    var sourceLabel: String {
        switch source {
        case "curated": return "Aexus 精选"
        case "vulhub": return "Vulhub"
        default: return source.capitalized
        }
    }

    var sourceDetail: String? {
        if let path = sourcePath, !path.isEmpty { return path }
        return nil
    }

    var ramLabel: String {
        if ramMB >= 1024 {
            let gb = Double(ramMB) / 1024
            return gb == gb.rounded() ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
        }
        return "\(ramMB) MB"
    }

    var stateLabel: String {
        if running { return "运行中" }
        if installed { return "已安装" }
        return "未安装"
    }

    enum State { case running, installed, available }
    var state: State {
        if running { return .running }
        if installed { return .installed }
        return .available
    }

    var webAccess: LabAccess? { access.first(where: { $0.isWeb }) }
    var primaryAccess: LabAccess? { webAccess ?? access.first }

    private enum CodingKeys: String, CodingKey {
        case id, name, subtitle, category, source, sourcePath = "source_path"
        case sourceURL = "source_url", difficulty, tags, summary, objectives
        case mitre, access, credentials, notes, ramMB = "ram_mb", cpu, build, compose
        case installed, running, memBytes = "mem_bytes", memHuman = "mem_human"
        case containers, startedAt = "started_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        subtitle = (try? c.decodeIfPresent(String.self, forKey: .subtitle)) ?? ""
        category = (try? c.decodeIfPresent(String.self, forKey: .category)) ?? "misc"
        source = (try? c.decodeIfPresent(String.self, forKey: .source)) ?? "curated"
        sourcePath = try? c.decodeIfPresent(String.self, forKey: .sourcePath)
        sourceURL = try? c.decodeIfPresent(String.self, forKey: .sourceURL)
        difficulty = (try? c.decodeIfPresent(Int.self, forKey: .difficulty)) ?? 2
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        summary = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        objectives = (try? c.decodeIfPresent([String].self, forKey: .objectives)) ?? []
        mitre = (try? c.decodeIfPresent([String].self, forKey: .mitre)) ?? []
        access = (try? c.decodeIfPresent([LabAccess].self, forKey: .access)) ?? []
        credentials = (try? c.decodeIfPresent(String.self, forKey: .credentials)) ?? ""
        notes = (try? c.decodeIfPresent(String.self, forKey: .notes)) ?? ""
        ramMB = (try? c.decodeIfPresent(Int.self, forKey: .ramMB)) ?? 512
        cpu = (try? c.decodeIfPresent(Double.self, forKey: .cpu)) ?? 1
        build = (try? c.decodeIfPresent(Bool.self, forKey: .build)) ?? false
        compose = (try? c.decodeIfPresent(String.self, forKey: .compose)) ?? "docker-compose.yml"
        installed = (try? c.decodeIfPresent(Bool.self, forKey: .installed)) ?? false
        running = (try? c.decodeIfPresent(Bool.self, forKey: .running)) ?? false
        memBytes = (try? c.decodeIfPresent(Int.self, forKey: .memBytes)) ?? 0
        memHuman = (try? c.decodeIfPresent(String.self, forKey: .memHuman)) ?? ""
        containers = (try? c.decodeIfPresent([LabContainer].self, forKey: .containers)) ?? []
        startedAt = try? c.decodeIfPresent(String.self, forKey: .startedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encode(category, forKey: .category)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(sourcePath, forKey: .sourcePath)
        try c.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(tags, forKey: .tags)
        try c.encode(summary, forKey: .summary)
        try c.encode(objectives, forKey: .objectives)
        try c.encode(mitre, forKey: .mitre)
        try c.encode(access, forKey: .access)
        try c.encode(credentials, forKey: .credentials)
        try c.encode(notes, forKey: .notes)
        try c.encode(ramMB, forKey: .ramMB)
        try c.encode(cpu, forKey: .cpu)
        try c.encode(build, forKey: .build)
        try c.encode(compose, forKey: .compose)
        try c.encode(installed, forKey: .installed)
        try c.encode(running, forKey: .running)
        try c.encode(memBytes, forKey: .memBytes)
        try c.encode(memHuman, forKey: .memHuman)
        try c.encode(containers, forKey: .containers)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
    }
}

struct CatalogFile: Codable {
    var version: Int?
    var generatedAt: String?
    var categories: [CatalogCategory]
    var labs: [Lab]

    enum CodingKeys: String, CodingKey {
        case version, categories, labs, generatedAt = "generated_at"
    }
}

struct TrainingCollection: Decodable, Identifiable {
    var id: String
    var name: String
    var url: String
    var authority: String
    var description: String
    var status: String
    var attackboxPath: String
    var commit: String?
    var files: Int?
    var bytes: Int64?
    var error: String?
    enum CodingKeys: String, CodingKey {
        case id, name, url, authority, description, status, commit, files, bytes, error
        case attackboxPath = "attackbox_path"
    }
}

struct TrainingLibraryResponse: Decodable {
    var ok: Bool
    var status: String
    var collections: [TrainingCollection]
}

// MARK: - arenactl responses

struct ArenaListResponse: Codable {
    var ok: Bool
    var categories: [CatalogCategory]?
    var labs: [Lab]?
    var generatedAt: String?
    enum CodingKeys: String, CodingKey {
        case ok, categories, labs, generatedAt = "generated_at"
    }
}

struct ArenaActionResponse: Codable {
    var ok: Bool
    var error: String?
    var id: String?
    var running: Bool?
    var installed: Bool?
    var stoppedOthers: [String]?
    var detail: String?
    enum CodingKeys: String, CodingKey {
        case ok, error, id, running, installed, detail
        case stoppedOthers = "stopped_others"
    }
}

struct ArenaHostInfo: Codable {
    var ok: Bool
    var hostname: String?
    var uptimeSeconds: Int?
    var memTotal: Int64?
    var memAvailable: Int64?
    var diskTotal: Int64?
    var diskUsed: Int64?
    var diskFree: Int64?
    var systemDiskTotal: Int64?
    var systemDiskUsed: Int64?
    var systemDiskFree: Int64?
    var docker: String?
    var catalogLabs: Int?
    var installedLabs: Int?
    var running: [String]?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case ok, hostname, docker, running, error
        case uptimeSeconds = "uptime_seconds"
        case memTotal = "mem_total", memAvailable = "mem_available"
        case diskTotal = "disk_total", diskUsed = "disk_used", diskFree = "disk_free"
        case systemDiskTotal = "system_disk_total", systemDiskUsed = "system_disk_used", systemDiskFree = "system_disk_free"
        case catalogLabs = "catalog_labs", installedLabs = "installed_labs"
    }
}

struct ArenaLogsResponse: Codable {
    var ok: Bool
    var logs: String?
    var error: String?
}

// MARK: - Host VM

struct VMExtraDisk: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var sizeGB: Int
    enum CodingKeys: String, CodingKey { case id, name, sizeGB = "size_gb" }
}

struct VMTunnelInfo: Codable, Hashable {
    var running: Bool
    var port: Int
}

struct VMInfo: Codable {
    var ok: Bool
    var name: String?
    var exists: Bool?
    var running: Bool?
    var ready: Bool?
    var cpu: Int?
    var ramGB: Int?
    var diskGB: Int?
    var extraDisks: [VMExtraDisk]?
    var sshPort: Int?
    var tunnel: VMTunnelInfo?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case ok, name, exists, running, ready, cpu, tunnel, error
        case ramGB = "ram_gb", diskGB = "disk_gb", extraDisks = "extra_disks"
        case sshPort = "ssh_port"
    }

    var totalDiskTB: Double {
        let main = Double(diskGB ?? 0)
        let extra = Double((extraDisks ?? []).reduce(0) { $0 + $1.sizeGB })
        return ((main + extra) * 1_000_000_000) / 1_000_000_000_000
    }

    var diskSummary: String {
        let main = Double(diskGB ?? 0)
        let extra = Double((extraDisks ?? []).reduce(0) { $0 + $1.sizeGB })
        let total = main + extra
        if total >= 1000 {
            return String(format: "%.1f TB", total / 1000)
        }
        return "\(Int(total)) GB"
    }
}

// MARK: - UI helpers

enum SourceFilter: String, CaseIterable, Identifiable {
    case all, curated, vulhub
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "全部来源"
        case .curated: return "Aexus 精选"
        case .vulhub: return "Vulhub"
        }
    }
}

enum LibraryScope: Hashable {
    case all
    case running
    case installed
    case available
    case category(String)
}

/// Canonical navigation item alias (`NavItem` == `AppMode`).
typealias NavItem = AppMode
