import Foundation

public struct WidgetNodeSnapshot: Codable, Equatable, Sendable {
    public var collectedAt: Date
    public var isRunning: Bool
    public var health: String
    public var version: String?
    public var frame: UInt64
    public var peers: Int
    public var archivePeers: Int
    public var pendingJoins: Int
    public var activeShards: Int
    public var totalAllocations: Int
    public var cpuPercent: Double?
    public var memoryMB: Double?
    public var seniority: Int64

    public init(
        collectedAt: Date,
        isRunning: Bool,
        health: String,
        version: String?,
        frame: UInt64,
        peers: Int,
        archivePeers: Int,
        pendingJoins: Int,
        activeShards: Int,
        totalAllocations: Int,
        cpuPercent: Double?,
        memoryMB: Double?,
        seniority: Int64
    ) {
        self.collectedAt = collectedAt
        self.isRunning = isRunning
        self.health = health
        self.version = version
        self.frame = frame
        self.peers = peers
        self.archivePeers = archivePeers
        self.pendingJoins = pendingJoins
        self.activeShards = activeShards
        self.totalAllocations = totalAllocations
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.seniority = seniority
    }

    public static let placeholder = WidgetNodeSnapshot(
        collectedAt: Date(),
        isRunning: true,
        health: "syncing",
        version: "2.1.0.25",
        frame: 743_500,
        peers: 60,
        archivePeers: 5,
        pendingJoins: 9,
        activeShards: 0,
        totalAllocations: 9,
        cpuPercent: 8.4,
        memoryMB: 1_650,
        seniority: 0
    )
}

public enum WidgetSnapshotStore {
    public static let appGroupIdentifier = "group.com.quilnode.app"
    public static let filename = "widget-node-snapshot.json"

    public static var groupContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    public static var fallbackDirectoryURL: URL {
        let base =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("QuilNode", isDirectory: true)
    }

    public static func saveFallback(_ snapshot: WidgetNodeSnapshot) throws {
        let data = try JSONEncoder.widgetEncoder.encode(snapshot)
        try PrivateLocalFileSystem.ensureDirectory(at: fallbackDirectoryURL)
        let destination = fallbackDirectoryURL.appendingPathComponent(filename)
        try PrivateLocalFileSystem.write(data, atomicallyTo: destination)
    }

    /// Mirrors the already-sanitized fallback snapshot through the App Group
    /// container API. Launching `/bin/cp` for this job loses the app's App Group
    /// entitlement and makes macOS treat the copy as cross-app data access.
    public static func mirrorFallbackToGroup() throws {
        let source = fallbackDirectoryURL.appendingPathComponent(filename)
        guard let groupDirectory = groupContainerURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let destination = groupDirectory.appendingPathComponent(filename)
        let data = try BoundedLocalData.read(from: source, maximumBytes: 64 * 1_024)
        try PrivateLocalFileSystem.write(data, atomicallyTo: destination)
    }

    public static func save(_ snapshot: WidgetNodeSnapshot) throws {
        try saveFallback(snapshot)
        try mirrorFallbackToGroup()
    }

    public static func load() -> WidgetNodeSnapshot? {
        var directories: [URL] = []
        if let groupContainerURL { directories.append(groupContainerURL) }
        directories.append(fallbackDirectoryURL)

        for directory in directories {
            let url = directory.appendingPathComponent(filename)
            guard let data = try? BoundedLocalData.read(from: url, maximumBytes: 64 * 1_024) else { continue }
            if let snapshot = try? JSONDecoder.widgetDecoder.decode(
                WidgetNodeSnapshot.self,
                from: data
            ) {
                return snapshot
            }
        }
        return nil
    }
}

private extension JSONEncoder {
    static var widgetEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var widgetDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
