import XCTest

@testable import QuilNodeHelperKit

final class HelperCommandTests: XCTestCase {
    func testEverySupportedCommandHasAStableRawValue() {
        let expected = [
            "start", "stop", "restart", "install", "activate", "rollback",
            "bootstrap", "migrate", "serve", "qclient-install", "wallet-transact",
        ]

        XCTAssertEqual(expected.compactMap(HelperAction.init(rawValue:)), HelperAction.allCases)
        XCTAssertNil(HelperAction(rawValue: "unknown"))
    }
}
