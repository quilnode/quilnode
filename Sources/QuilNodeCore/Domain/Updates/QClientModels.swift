import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

public struct OfficialQClientRelease: Equatable, Sendable {
    public var releaseVersion: String
    public var binaryFileName: String
    public var digestPublished: Bool
    public var signatureIndices: [Int]

    public init(
        releaseVersion: String,
        binaryFileName: String,
        digestPublished: Bool,
        signatureIndices: [Int]
    ) {
        self.releaseVersion = releaseVersion
        self.binaryFileName = binaryFileName
        self.digestPublished = digestPublished
        self.signatureIndices = signatureIndices
    }
}

public enum QClientReleaseManifestParser {
    public static func latest(
        in manifest: String,
        platform: String = "darwin-arm64"
    ) -> OfficialQClientRelease? {
        let lines = manifest.split(whereSeparator: \.isNewline).map(String.init)
        let escapedPlatform = NSRegularExpression.escapedPattern(for: platform)
        let pattern = #"^qclient-([0-9]+(?:\.[0-9]+){2,})-"# + escapedPlatform + #"$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let releases = lines.compactMap { line -> (NodeVersion, String)? in
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                match.range == range,
                let versionRange = Range(match.range(at: 1), in: line),
                let version = NodeVersion(String(line[versionRange]))
            else { return nil }
            return (version, line)
        }
        guard let selected = releases.max(by: { $0.0 < $1.0 }) else { return nil }
        let releaseVersion = selected.0.display
        let binaryFileName = selected.1
        let signaturePrefix = "\(binaryFileName).dgst.sig."
        let signatures = Set(
            lines.compactMap { line -> Int? in
                guard line.hasPrefix(signaturePrefix),
                    line.dropFirst(signaturePrefix.count).allSatisfy(\.isNumber)
                else { return nil }
                return Int(line.dropFirst(signaturePrefix.count))
            }
        ).sorted()
        return OfficialQClientRelease(
            releaseVersion: releaseVersion,
            binaryFileName: binaryFileName,
            digestPublished: lines.contains("\(binaryFileName).dgst"),
            signatureIndices: signatures
        )
    }
}

public enum QClientRuntimeVersionParser {
    /// qclient release filenames and runtime versions are not currently the
    /// same namespace (for example a release may report `2.1.0-p22`). Preserve
    /// both values instead of pretending they match.
    public static func parse(_ output: String) -> String? {
        QClientVersion.parse(output)
    }
}

public enum QClientCompatibility {
    /// Source clients must match the selected immutable commit (the node
    /// build's commit, or the protocol branch candidate for a client-only update).
    public static func isCurrent(
        _ client: ManagedQClientStatus?, nodeVersion: String?, nodeCommit: String?
    ) -> Bool {
        guard let client, client.isReady else { return false }
        if let nodeCommit {
            guard client.trust == .pinnedSource,
                nodeCommit.count >= 8, let commit = client.commit, commit.count == 40,
                sameProtocol(client.releaseVersion, nodeVersion)
            else { return false }
            return commit.hasPrefix(nodeCommit)
        }
        return client.trust == .officialSigned
            && isCompatible(qclientReleaseVersion: client.releaseVersion, nodeVersion: nodeVersion)
    }

    public static func isUsable(
        _ client: ManagedQClientStatus?, nodeVersion: String?, nodeCommit: String?
    ) -> Bool {
        if isCurrent(client, nodeVersion: nodeVersion, nodeCommit: nodeCommit) { return true }
        guard let client, client.isReady, client.trust == .pinnedSource, nodeCommit != nil,
            let runtime = client.reportedVersion, let version = NodeVersion(runtime),
            let nodeVersion, let node = NodeVersion(nodeVersion), version >= node,
            sameProtocol(runtime, nodeVersion)
        else { return false }
        return true
    }

    private static func sameProtocol(_ first: String?, _ second: String?) -> Bool {
        guard let first, let second, let lhs = NodeVersion(first), let rhs = NodeVersion(second),
            lhs.components.count >= 4, rhs.components.count >= 4
        else { return false }
        return Array(lhs.components.prefix(4)) == Array(rhs.components.prefix(4))
    }

    /// Numeric protocol matching only. Source reuse must also establish
    /// provenance with `isCurrent`; a shared prefix alone is insufficient.
    public static func isCompatible(
        qclientReleaseVersion: String?,
        nodeVersion: String?
    ) -> Bool {
        guard let qclientReleaseVersion,
            let nodeVersion,
            let client = NodeVersion(qclientReleaseVersion),
            let node = NodeVersion(nodeVersion),
            client.components.count >= 4,
            node.components.count >= client.components.count
        else { return false }
        return Array(node.components.prefix(client.components.count)) == client.components
    }
}

public struct ManagedQClientStatus: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case missing
        case verified
        case invalid
    }

    public var state: State
    public var releaseVersion: String?
    public var reportedVersion: String?
    public var binaryFileName: String?
    public var trust: ArtifactTrustKind?
    public var commit: String?
    public var sha256: String?
    public var signatureCount: Int
    public var installedAt: Date?
    public var detail: String

    public init(
        state: State,
        releaseVersion: String? = nil,
        reportedVersion: String? = nil,
        binaryFileName: String? = nil,
        trust: ArtifactTrustKind? = nil,
        commit: String? = nil,
        sha256: String? = nil,
        signatureCount: Int = 0,
        installedAt: Date? = nil,
        detail: String
    ) {
        self.state = state
        self.releaseVersion = releaseVersion
        self.reportedVersion = reportedVersion
        self.binaryFileName = binaryFileName
        self.trust = trust
        self.commit = commit
        self.sha256 = sha256
        self.signatureCount = signatureCount
        self.installedAt = installedAt
        self.detail = detail
    }

    public var isReady: Bool { state == .verified }
}
