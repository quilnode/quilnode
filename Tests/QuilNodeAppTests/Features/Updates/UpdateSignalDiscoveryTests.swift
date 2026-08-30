import XCTest

@testable import QuilNodeApp

final class UpdateSignalDiscoveryTests: XCTestCase {
    func testRemoteReferenceFingerprintInputIsCanonical() throws {
        let first = String(repeating: "a", count: 40)
        let second = String(repeating: "b", count: 40)
        let output = """
            \(second)\trefs/heads/v2.1.0.25
            \(first)\trefs/heads/dev
            """

        XCTAssertEqual(
            try ReleaseChecker.canonicalRemoteReferences(output),
            [
                "\(first)\trefs/heads/dev",
                "\(second)\trefs/heads/v2.1.0.25",
            ]
        )
    }

    func testRemoteReferenceParserRejectsTraversalAndMalformedObjectIDs() {
        XCTAssertThrowsError(
            try ReleaseChecker.canonicalRemoteReferences(
                "\(String(repeating: "a", count: 40))\trefs/heads/../private"
            )
        )
        XCTAssertThrowsError(
            try ReleaseChecker.canonicalRemoteReferences("not-a-commit\trefs/heads/dev")
        )
    }

    func testConditionalSignalAcceptsOnlyTheProtocolDefinedEmptyResponse() {
        XCTAssertTrue(boundedResponseBodyIsValid(statusCode: 304, data: Data()))
        XCTAssertFalse(boundedResponseBodyIsValid(statusCode: 200, data: Data()))
        XCTAssertTrue(boundedResponseBodyIsValid(statusCode: 200, data: Data("manifest".utf8)))
    }
}
