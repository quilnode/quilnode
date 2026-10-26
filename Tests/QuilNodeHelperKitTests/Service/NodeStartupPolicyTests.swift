import Foundation
import XCTest

@testable import QuilNodeHelperKit

final class NodeStartupPolicyTests: XCTestCase {
    func testBootPolicyChangesOnlyStartupKeysAndRoundTripsWithoutChangingRuntimeIdentity() throws {
        let original: [String: Any] = [
            "Label": "com.quilibrium.node", "UserName": "_quilnode",
            "ProgramArguments": ["/opt/quilibrium/node/quilibrium-node"],
            "EnvironmentVariables": ["QUILIBRIUM_SIGNATURE_CHECK": "false"],
            "RunAtLoad": true, "KeepAlive": true,
        ]
        let disabled = QuilNodeHelper.nodeStartupPlist(original, enabled: false)
        XCTAssertEqual(disabled["RunAtLoad"] as? Bool, false)
        XCTAssertEqual(disabled["KeepAlive"] as? Bool, false)
        let restored = QuilNodeHelper.nodeStartupPlist(disabled, enabled: true)
        XCTAssertEqual(NSDictionary(dictionary: original), NSDictionary(dictionary: restored))
        XCTAssertEqual(disabled["UserName"] as? String, "_quilnode")
        XCTAssertEqual(disabled["ProgramArguments"] as? [String], original["ProgramArguments"] as? [String])
    }
}
