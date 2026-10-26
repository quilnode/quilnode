import XCTest

@testable import QuilNodeCore

final class QClientCompatibilityTests: XCTestCase {
    private let commit = String(repeating: "a", count: 40)

    func testVersionBannersAndAmbiguousResponses() {
        XCTAssertEqual(QClientRuntimeVersionParser.parse("qclient 2.1.0.25.102\n"), "2.1.0.25.102")
        XCTAssertEqual(QClientRuntimeVersionParser.parse("qclient version: 2.1.0-p25\n"), "2.1.0-p25")
        XCTAssertNil(QClientRuntimeVersionParser.parse("error: qclient 2.1.0.25.102"))
        XCTAssertNil(QClientRuntimeVersionParser.parse("qclient 2.1.0.25.102\nqclient 2.1.0.25.103"))
    }

    func testBaseProtocolMatchCannotReuseAnOldSourceClient() {
        let client = ManagedQClientStatus(
            state: .verified, releaseVersion: "2.1.0.25", reportedVersion: "2.1.0-p25",
            trust: .pinnedSource, commit: String(repeating: "b", count: 40), detail: "fixture"
        )
        XCTAssertFalse(QClientCompatibility.isCurrent(client, nodeVersion: "2.1.0.25.102", nodeCommit: commit))
        XCTAssertFalse(QClientCompatibility.isUsable(client, nodeVersion: "2.1.0.25.102", nodeCommit: commit))
    }

    func testCurrentSourceClientAndNewerClientForSameProtocol() {
        let client = ManagedQClientStatus(
            state: .verified, releaseVersion: "2.1.0.25.102", reportedVersion: "2.1.0.25.102",
            trust: .pinnedSource, commit: commit, detail: "fixture"
        )
        XCTAssertTrue(QClientCompatibility.isCurrent(client, nodeVersion: "2.1.0.25.102", nodeCommit: "aaaaaaaa"))
        XCTAssertFalse(QClientCompatibility.isCurrent(client, nodeVersion: "2.1.0.26.1", nodeCommit: commit))
        XCTAssertTrue(QClientCompatibility.isUsable(client, nodeVersion: "2.1.0.25.101", nodeCommit: "bbbbbbbb"))
        XCTAssertFalse(QClientCompatibility.isUsable(client, nodeVersion: "2.1.0.25.103", nodeCommit: "bbbbbbbb"))
    }
}
