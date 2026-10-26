import Foundation
import XCTest

@testable import QuilNodeApp

final class QClientSourceVersionTests: XCTestCase {
    func testModernSourceIncludesItsSubpatchBeforeComparingWithInstalledNode() throws {
        let repository = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: repository) }
        let source = repository.appendingPathComponent("crates/quil-config/src/version.rs")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("pub fn display_version() -> &'static str { }".utf8).write(to: source)
        try Data("102\n".utf8).write(to: repository.appendingPathComponent("subpatch"))
        XCTAssertEqual(
            try ReleaseChecker.expectedQClientRuntimeVersion(repository: repository, sourceVersion: "2.1.0.25"),
            "2.1.0.25.102"
        )
        XCTAssertEqual(
            try ReleaseChecker.expectedQClientRuntimeVersion(repository: repository, sourceVersion: "2.1.0.25.102"),
            "2.1.0.25.102"
        )
        try Data("pub const VERSION_STRING: &str = \"2.1.0.25\";".utf8).write(to: source)
        XCTAssertEqual(
            try ReleaseChecker.expectedQClientRuntimeVersion(repository: repository, sourceVersion: "2.1.0.25"),
            "2.1.0.25"
        )
    }
}
