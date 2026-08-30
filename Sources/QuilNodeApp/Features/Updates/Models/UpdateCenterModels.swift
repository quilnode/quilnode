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
    var expectedPhaseDuration: TimeInterval?
    var remainingKnownDuration: TimeInterval = 0

    var boundedFraction: Double { min(max(fraction, 0), 1) }

    func estimatedRemaining(at now: Date = Date()) -> TimeInterval? {
        guard status == .running,
            phase != "Ready to install",
            boundedFraction >= 0.08,
            boundedFraction < 0.98
        else { return nil }
        if let expectedPhaseDuration {
            let phaseElapsed = max(now.timeIntervalSince(phaseStartedAt), 0)
            var predictedPhaseDuration = max(expectedPhaseDuration, phaseElapsed * 1.12)
            if phase == "Compiling node",
                let completedUnits, let totalUnits, totalUnits > 0
            {
                let unitProgress = min(max(Double(completedUnits) / Double(totalUnits), 0.05), 0.92)
                let observedDuration = phaseElapsed / unitProgress
                predictedPhaseDuration = max(
                    phaseElapsed * 1.12,
                    expectedPhaseDuration * 0.65 + observedDuration * 0.35
                )
            }
            return max(predictedPhaseDuration - phaseElapsed + remainingKnownDuration, 5)
        }
        let elapsed = max(now.timeIntervalSince(startedAt), 1)
        return min(max((elapsed / boundedFraction) * (1 - boundedFraction), 1), 3 * 60 * 60)
    }

    func estimatedRemainingRange(at now: Date = Date()) -> ClosedRange<TimeInterval>? {
        guard let estimate = estimatedRemaining(at: now) else { return nil }
        let uncertainty = max(estimate * 0.18, 15)
        return max(estimate - uncertainty, 1)...min(estimate + uncertainty, 3 * 60 * 60)
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
