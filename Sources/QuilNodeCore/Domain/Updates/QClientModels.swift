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
        guard
            let regex = try? NSRegularExpression(
                pattern: #"(?m)^(?:qclient version:\s*)?([0-9]+\.[0-9]+\.[0-9]+-p[0-9]+)$"#
            )
        else { return nil }
        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, range: range),
            let valueRange = Range(match.range(at: 1), in: output)
        else { return nil }
        return String(output[valueRange])
    }
}

public enum QClientCompatibility {
    /// Development subpatches extend the node's base protocol version (for
    /// example node 2.1.0.25.58 still uses qclient 2.1.0.25). A verified
    /// qclient remains compatible while its complete release-version tuple is
    /// an exact prefix of the node version. This never treats .24 as .25.
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
