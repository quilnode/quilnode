import Foundation
import XCTest

@testable import QuilNodeApp

final class BoundedProcessExecutionTests: XCTestCase {
    func testOutputLimitDoesNotLimitFilesCreatedByCommand() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quilnode-output-pump-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let artifact = directory.appendingPathComponent("artifact.bin")

        _ = try ReleaseChecker.runChecked(
            "/bin/dd",
            ["if=/dev/zero", "of=\(artifact.path)", "bs=65536", "count=1"],
            currentDirectory: directory,
            timeout: 5,
            maximumOutputBytes: 4_096
        )

        XCTAssertEqual(
            try artifact.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            65_536,
            "The console-output budget must never become a process-wide artifact-size limit."
        )
    }

    func testExcessiveConsoleOutputIsStillBounded() {
        XCTAssertThrowsError(
            try ReleaseChecker.runChecked(
                "/usr/bin/yes",
                [String(repeating: "x", count: 256)],
                timeout: 5,
                maximumOutputBytes: 4_096
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("secure build-output limit"))
        }
    }
}
