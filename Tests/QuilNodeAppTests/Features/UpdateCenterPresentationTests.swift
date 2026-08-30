import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class UpdateCenterPresentationTests: XCTestCase {
    func testChannelsPreserveAssuranceOrder() {
        let channels = UpdateChannelPresentation.make(
            snapshot: makeSnapshot(),
            isInstalling: false,
            hasStagedUpdate: false
        )

        XCTAssertEqual(channels.map(\.kind), [.signed, .approved, .raw])
        XCTAssertEqual(channels.map(\.assurance), [.highest, .approved, .experimental])
    }

    func testApprovedMarkerPinsExactActionCandidate() {
        let channels = UpdateChannelPresentation.make(
            snapshot: makeSnapshot(),
            isInstalling: false,
            hasStagedUpdate: false
        )
        let approved = channels.first { $0.kind == .approved }

        XCTAssertEqual(approved?.commit, approvedCommit)
        XCTAssertEqual(approved?.evidence, "subpatch 62 · v2.1.0.25")
        XCTAssertEqual(approved?.action.state, .ready)
    }

    func testRunningOperationBlocksEveryInstallAction() {
        let channels = UpdateChannelPresentation.make(
            snapshot: makeSnapshot(),
            isInstalling: true,
            hasStagedUpdate: false
        )

        XCTAssertTrue(channels.allSatisfy { !$0.action.isEnabled })
    }

    func testOlderSignedChannelIsDescribedAsInstalledAhead() {
        var snapshot = makeSnapshot()
        snapshot.signed.version = "2.1.0.24"
        let signed = UpdateChannelPresentation.make(
            snapshot: snapshot,
            isInstalling: false,
            hasStagedUpdate: false
        ).first { $0.kind == .signed }

        XCTAssertEqual(signed?.state, .installedAhead)
        XCTAssertFalse(signed?.action.isEnabled ?? true)
        XCTAssertTrue(signed?.action.message.localizedCaseInsensitiveContains("no downgrade") ?? false)
    }

    func testFlightPlanCollapsesImplementationStepsWithoutLosingSafetyBoundary() {
        XCTAssertEqual(UpdateFlightStage.current(for: .compileNode), .acquire)
        XCTAssertEqual(UpdateFlightStage.current(for: .sealPlan), .stage)
        XCTAssertEqual(UpdateFlightStage.current(for: .switchRuntime), .activate)
        XCTAssertEqual(UpdateFlightStage.current(for: .healthGate), .health)
        XCTAssertEqual(UpdateFlightStage.activate.section, .activation)
        XCTAssertEqual(UpdateFlightStage.stage.section, .preparation)
    }

    private let installedCommit = "6471adf100000000000000000000000000000000"
    private let approvedCommit = "89b2c7a300000000000000000000000000000000"

    private func makeSnapshot() -> UpdateCenterSnapshot {
        let date = Date(timeIntervalSince1970: 1_777_000_000)
        let raw = GitBranchHead(
            name: "dev",
            commit: "d1f3e9c200000000000000000000000000000000",
            committedAt: date,
            subject: "Continue protocol work"
        )
        return UpdateCenterSnapshot(
            signed: SignedReleaseInfo(
                version: "2.1.0.25.59",
                binaryFileName: "node-2.1.0.25.59-darwin-arm64",
                digestPublished: true,
                signatureIndices: Array(0..<9),
                manifestModifiedAt: date
            ),
            source: SourceReleaseInfo(
                newestAnyBranch: raw,
                highestVersionBranch: GitBranchHead(
                    name: "v2.1.0.25",
                    commit: approvedCommit,
                    committedAt: date,
                    subject: "Approve subpatch 62"
                ),
                approvedDevelopment: ApprovedDevelopmentReleaseInfo(
                    version: "2.1.0.25.62",
                    subpatch: 62,
                    branch: "v2.1.0.25",
                    commit: approvedCommit,
                    committedAt: date,
                    subject: "Approve subpatch 62",
                    branchHeadCommit: approvedCommit,
                    unapprovedCommitsAhead: 0
                ),
                approvalIssue: nil,
                branchCount: 4,
                commitsBehind: 8
            ),
            installed: InstalledReleaseInfo(
                build: InstalledNodeBuild(
                    version: "2.1.0.25.58",
                    kind: .source,
                    commit: installedCommit,
                    fileName: "node-2.1.0.25.58-source-6471adf1-darwin-arm64"
                ),
                sha256: String(repeating: "a", count: 64),
                installedFileModifiedAt: date
            ),
            qclient: QClientUpdateInfo(
                available: nil,
                installed: nil,
                checkedAt: date,
                error: nil
            ),
            checkedAt: date
        )
    }
}
