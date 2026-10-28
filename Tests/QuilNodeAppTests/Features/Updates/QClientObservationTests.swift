import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class QClientObservationTests: XCTestCase {
    func testUnknownClientIsNotAdvertisedAsMissingOrAnAvailableUpdate() {
        let snapshot = fixture(client: nil)
        XCTAssertEqual(snapshot.qclientInstallationLabel, "Unavailable")
        XCTAssertEqual(snapshot.qclientUpdateStatusLabel, "Check unavailable")
    }

    func testOnlyAnObservedMissingClientIsAdvertisedAsNotInstalled() {
        let snapshot = fixture(client: .init(state: .missing, detail: "No managed client"))
        XCTAssertEqual(snapshot.qclientInstallationLabel, "Not installed")
        XCTAssertEqual(snapshot.qclientUpdateStatusLabel, "Not installed")
    }

    func testVerifiedAndInvalidClientRemainDistinct() {
        let verified = fixture(client: .init(state: .verified, releaseVersion: "2.1.0.25.109", detail: "Verified"))
        XCTAssertEqual(verified.qclientInstallationLabel, "2.1.0.25.109")
        let invalid = fixture(client: .init(state: .invalid, detail: "Provenance unavailable"))
        XCTAssertEqual(invalid.qclientInstallationLabel, "Needs repair")
        XCTAssertEqual(invalid.qclientUpdateStatusLabel, "Needs repair")
    }

    @MainActor
    func testUnavailableClientCannotStartInstallation() {
        let checker = ReleaseChecker(preview: ())
        checker.state = .available(fixture(client: nil))
        checker.requestInstallQClient()
        XCTAssertNil(checker.operationTask)
        XCTAssertEqual(checker.operation, .idle)
    }

    private func fixture(client: ManagedQClientStatus?) -> UpdateCenterSnapshot {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let head = GitBranchHead(
            name: "v2.1.0.25", commit: String(repeating: "a", count: 40), committedAt: date, subject: "Fixture")
        return UpdateCenterSnapshot(
            signed: .init(
                version: "2.1.0.24", binaryFileName: "node", digestPublished: true, signatureIndices: [],
                manifestModifiedAt: date),
            source: .init(
                newestAnyBranch: head, highestVersionBranch: head, approvedDevelopment: nil, approvalIssue: nil,
                branchCount: 1, commitsBehind: 0),
            installed: .init(
                build: .init(version: "2.1.0.25.109", kind: .source, commit: head.commit, fileName: "node"),
                sha256: nil, installedFileModifiedAt: date),
            qclient: .init(
                available: nil, installed: client, checkedAt: date, error: client == nil ? "Service reconnecting" : nil),
            checkedAt: date
        )
    }
}
