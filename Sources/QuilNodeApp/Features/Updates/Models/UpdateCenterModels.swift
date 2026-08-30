import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct SignedReleaseInfo: Equatable, Sendable {
    var version: String
    var binaryFileName: String
    var digestPublished: Bool
    var signatureIndices: [Int]
    var manifestModifiedAt: Date?
}

struct ApprovedDevelopmentReleaseInfo: Equatable, Sendable {
    var version: String
    var subpatch: Int
    var branch: String
    var commit: String
    var committedAt: Date
    var subject: String
    var branchHeadCommit: String
    var unapprovedCommitsAhead: Int

    var head: GitBranchHead {
        GitBranchHead(name: branch, commit: commit, committedAt: committedAt, subject: subject)
    }
}

struct SourceReleaseInfo: Equatable, Sendable {
    var newestAnyBranch: GitBranchHead
    var highestVersionBranch: GitBranchHead?
    var approvedDevelopment: ApprovedDevelopmentReleaseInfo?
    var approvalIssue: String?
    var branchCount: Int
    var commitsBehind: Int?
}

struct InstalledReleaseInfo: Equatable, Sendable {
    var build: InstalledNodeBuild
    var sha256: String?
    var installedFileModifiedAt: Date?
}

struct QClientUpdateInfo: Equatable, Sendable {
    var available: OfficialQClientRelease?
    var installed: ManagedQClientStatus?
    var checkedAt: Date
    var error: String?
}

struct UpdateCenterSnapshot: Equatable, Sendable {
    var signed: SignedReleaseInfo
    var source: SourceReleaseInfo
    var installed: InstalledReleaseInfo
    var qclient: QClientUpdateInfo
    var checkedAt: Date
}

struct NodeUpdateEvent: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var timestamp: Date
    var channel: String
    var version: String
    var branch: String?
    var commit: String?
    var result: String
    var detail: String
}

struct NodeUpdateProgress: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case running
        case ready
        case succeeded
        case failed
    }

    var status: Status = .running
    var workflow: NodeUpdateWorkflow = .generic
    var step: NodeUpdateStep = .selectCandidate
    var phase: String
    var detail: String
    var fraction: Double
    var startedAt: Date
    var phaseStartedAt: Date = Date()
    var stepStartedAt: Date = Date()
    var updatedAt: Date = Date()
    var completedUnits: Int?
    var totalUnits: Int?
    var isEstimate: Bool = true
    var logURL: URL?

    var boundedFraction: Double { min(max(fraction, 0), 1) }
    var shouldAutomaticallyRevealLog: Bool {
        logURL != nil && (status == .running || status == .failed)
    }

}

struct StagedNodeUpdate: Equatable, Sendable {
    var channel: String
    var version: String
    var manifestURL: URL
}

struct UpdateOperationJournal: Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case running
        case staged
        case installed
        case failed
        case interrupted
    }

    var id: UUID
    var channel: String
    var version: String
    var branch: String?
    var commit: String?
    var phase: String
    var detail: String
    var fraction: Double
    var startedAt: Date
    var updatedAt: Date
    var status: Status
    var logPath: String?
    var manifestPath: String?
}
