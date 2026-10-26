import Foundation
import XCTest

@testable import QuilNodeHelperKit

final class QClientCommandResultTests: XCTestCase {
    func testReadResultPreservesPartialOutputButStrictRunnerStillFails() throws {
        let args = ["-c", "printf 'Claimable prover rewards: unavailable (fixture)'; exit 1"]
        let result = try QuilNodeHelper.runCommand(
            URL(fileURLWithPath: "/bin/sh"), args, timeout: 2,
            currentDirectory: URL(fileURLWithPath: "/tmp")
        )
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertFalse(result.timedOut)
        XCTAssertTrue(result.output.contains("Claimable prover rewards"))
        XCTAssertThrowsError(
            try QuilNodeHelper.run(
                URL(fileURLWithPath: "/bin/sh"), args, timeout: 2,
                currentDirectory: URL(fileURLWithPath: "/tmp")
            ))
    }

    func testTimeoutRetainsCompletedOutput() throws {
        let result = try QuilNodeHelper.runCommand(
            URL(fileURLWithPath: "/bin/sh"), ["-c", "printf 'completed component'; sleep 5"], timeout: 0.15,
            currentDirectory: URL(fileURLWithPath: "/tmp")
        )
        XCTAssertTrue(result.timedOut)
        XCTAssertEqual(result.output, "completed component")
    }
}
