import Foundation
import XCTest

@testable import QuilNodeHelperKit

final class QClientCommandResultTests: XCTestCase {
    func testVersionProbeTraversesParentsWithoutReadingSiblingData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let binary = root.appendingPathComponent("releases/version/probe")
        try FileManager.default.createDirectory(
            at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: binary.path)
        let sibling = root.appendingPathComponent("private-sibling")
        try Data("must remain unreadable".utf8).write(to: sibling)
        let profile = QuilNodeHelper.artifactVersionProbeProfile(binary)
        let result = try QuilNodeHelper.runCommand(
            URL(fileURLWithPath: "/usr/bin/sandbox-exec"), ["-p", profile, binary.path], timeout: 5,
            currentDirectory: URL(fileURLWithPath: "/var/empty")
        )
        XCTAssertEqual(result.exitCode, 0, result.output)
        let denied = try QuilNodeHelper.runCommand(
            URL(fileURLWithPath: "/usr/bin/sandbox-exec"), ["-p", profile, "/bin/cat", sibling.path], timeout: 5,
            currentDirectory: URL(fileURLWithPath: "/var/empty")
        )
        XCTAssertNotEqual(denied.exitCode, 0)
        XCTAssertFalse(denied.output.contains("must remain unreadable"))
    }

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
