import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

public struct GitLFSPointer: Equatable, Sendable {
    public var oid: String
    public var size: Int

    public init(oid: String, size: Int) {
        self.oid = oid
        self.size = size
    }
}

public enum GitLFSPointerParser {
    public static func parse(_ text: String) -> GitLFSPointer? {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count == 3,
            lines[0] == "version https://git-lfs.github.com/spec/v1",
            lines[1].hasPrefix("oid sha256:"),
            lines[2].hasPrefix("size "),
            let size = Int(lines[2].dropFirst(5)), size > 0
        else { return nil }
        let oid = String(lines[1].dropFirst("oid sha256:".count))
        guard oid.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil else { return nil }
        return GitLFSPointer(oid: oid, size: size)
    }
}

public enum NodeUpdatePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case signedStable
    case approvedDevelopment
    case bleedingEdge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .manual: "Manual"
        case .signedStable: "Signed Stable"
        case .approvedDevelopment: "Approved Dev"
        case .bleedingEdge: "Raw Dev"
        }
    }
}

public struct NodeVersion: Comparable, Equatable, Sendable {
    public let components: [Int]
    public let display: String

    public init?(_ value: String) {
        let normalized = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = normalized.split(separator: ".")
        guard parts.count >= 3,
            parts.allSatisfy({ Int($0) != nil })
        else { return nil }
        components = parts.compactMap { Int($0) }
        display = normalized
    }

    public static func < (lhs: NodeVersion, rhs: NodeVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

public struct InstalledNodeBuild: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case signed
        case source
        case unknown
    }

    public var version: String?
    public var kind: Kind
    public var commit: String?
    public var fileName: String

    public init(version: String?, kind: Kind, commit: String?, fileName: String) {
        self.version = version
        self.kind = kind
        self.commit = commit
        self.fileName = fileName
    }
}

public enum InstalledNodeBuildParser {
    public static func parse(symlinkTarget: String) -> InstalledNodeBuild {
        let fileName = URL(fileURLWithPath: symlinkTarget).lastPathComponent
        let pattern = #"^node-([0-9]+(?:\.[0-9]+){2,})(?:-source-([0-9a-fA-F]{7,40}))?-darwin-arm64$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: fileName,
                range: NSRange(fileName.startIndex..., in: fileName)
            ),
            let versionRange = Range(match.range(at: 1), in: fileName)
        else {
            return InstalledNodeBuild(
                version: nil,
                kind: .unknown,
                commit: nil,
                fileName: fileName
            )
        }

        let commit: String?
        if match.range(at: 2).location != NSNotFound,
            let commitRange = Range(match.range(at: 2), in: fileName)
        {
            commit = String(fileName[commitRange]).lowercased()
        } else {
            commit = nil
        }
        return InstalledNodeBuild(
            version: String(fileName[versionRange]),
            kind: commit == nil ? .signed : .source,
            commit: commit,
            fileName: fileName
        )
    }
}

/// A repository approval marker is deliberately tiny: one positive decimal
/// sub-patch number and no additional syntax. Keeping parsing strict prevents
/// comments, shell fragments, or malformed values from becoming release input.
public enum ApprovedDevelopmentMarker {
    public static func parse(_ contents: String) -> Int? {
        let value = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
            value.count <= 9,
            value.allSatisfy(\.isNumber),
            let number = Int(value),
            number > 0
        else { return nil }
        return number
    }

    public static func version(baseVersion: String, subpatch: Int) -> String? {
        guard NodeVersion(baseVersion) != nil, subpatch > 0 else { return nil }
        return "\(baseVersion).\(subpatch)"
    }
}

public struct GitBranchHead: Equatable, Sendable {
    public var name: String
    public var commit: String
    public var committedAt: Date
    public var subject: String

    public init(name: String, commit: String, committedAt: Date, subject: String) {
        self.name = name
        self.commit = commit
        self.committedAt = committedAt
        self.subject = subject
    }

    public var version: String? {
        guard name.hasPrefix("v"), NodeVersion(name) != nil else { return nil }
        return String(name.dropFirst())
    }
}

public enum GitBranchHeadParser {
    // Expected format: unix timestamp<TAB>short ref<TAB>SHA<TAB>subject.
    public static func parse(_ output: String) -> [GitBranchHead] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let fields = rawLine.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4,
                let timestamp = TimeInterval(fields[0]),
                fields[2].count == 40,
                fields[2].allSatisfy({ $0.isHexDigit })
            else { return nil }
            return GitBranchHead(
                name: String(fields[1]),
                commit: String(fields[2]).lowercased(),
                committedAt: Date(timeIntervalSince1970: timestamp),
                subject: String(fields[3])
            )
        }
    }

    public static func newestAnyBranch(in heads: [GitBranchHead]) -> GitBranchHead? {
        heads.max { $0.committedAt < $1.committedAt }
    }

    public static func newestVersionBranch(in heads: [GitBranchHead]) -> GitBranchHead? {
        heads.compactMap { head -> (NodeVersion, GitBranchHead)? in
            guard let version = NodeVersion(head.name) else { return nil }
            return (version, head)
        }.max { $0.0 < $1.0 }?.1
    }
}

public struct UpdateActivationManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var channel: String
    public var version: String
    public var reportedVersion: String?
    public var branch: String?
    public var commit: String?
    public var binaryFileName: String
    public var sha256: String
    public var createdAt: Date
    public var signatureIndices: [Int]
    public var qclient: SignedArtifactActivation?

    public init(
        channel: String,
        version: String,
        reportedVersion: String? = nil,
        branch: String? = nil,
        commit: String? = nil,
        binaryFileName: String,
        sha256: String,
        createdAt: Date = Date(),
        signatureIndices: [Int] = [],
        qclient: SignedArtifactActivation? = nil
    ) {
        schemaVersion = 2
        self.channel = channel
        self.version = version
        self.reportedVersion = reportedVersion
        self.branch = branch
        self.commit = commit
        self.binaryFileName = binaryFileName
        self.sha256 = sha256
        self.createdAt = createdAt
        self.signatureIndices = signatureIndices
        self.qclient = qclient
    }
}
