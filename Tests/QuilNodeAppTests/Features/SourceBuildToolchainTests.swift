import Foundation
import XCTest

@testable import QuilNodeApp

final class SourceBuildToolchainTests: XCTestCase {
    func testRecommendedParallelismPreservesCapacityWithoutStarvingNativeBuilds() {
        XCTAssertEqual(SourceBuildToolchain.recommendedParallelJobs(availableProcessors: 1), 1)
        XCTAssertEqual(SourceBuildToolchain.recommendedParallelJobs(availableProcessors: 4), 3)
        XCTAssertEqual(SourceBuildToolchain.recommendedParallelJobs(availableProcessors: 10), 8)
        XCTAssertEqual(SourceBuildToolchain.recommendedParallelJobs(availableProcessors: 32), 30)
        XCTAssertEqual(
            SourceBuildToolchain.recommendedParallelJobs(
                availableProcessors: 10,
                thermalState: .serious
            ),
            1
        )
    }

    func testApprovedWorkspaceAdoptsMatchingLegacyCacheButRawStaysSeparated() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "quilnode-workspace-selection-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("source-12345678", isDirectory: true)
        let repository = legacy.appendingPathComponent("repo", isDirectory: true)
        let commit = String(repeating: "a", count: 40)
        try FileManager.default.createDirectory(
            at: repository.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: repository.appendingPathComponent("target", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data((repository.path + "\n").utf8).write(
            to: legacy.appendingPathComponent(".repository-path")
        )
        try Data((commit + "\n").utf8).write(
            to: repository.appendingPathComponent(".git/HEAD")
        )

        let approved = try ReleaseChecker.sourceBuildWorkspace(
            cacheDomain: "approved",
            legacyCommit: commit,
            root: root
        )
        let raw = try ReleaseChecker.sourceBuildWorkspace(
            cacheDomain: "raw",
            legacyCommit: commit,
            root: root
        )

        XCTAssertEqual(approved.standardizedFileURL, legacy.standardizedFileURL)
        XCTAssertEqual(raw.lastPathComponent, "raw-source-v1")
        XCTAssertNotEqual(approved.standardizedFileURL, raw.standardizedFileURL)
    }

    func testDependencyDiscoveryUsesStableFormulaPrefix() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "quilnode-native-toolchain-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let searchRoot = root.appendingPathComponent("homebrew/opt", isDirectory: true)
        let formula = searchRoot.appendingPathComponent("example", isDirectory: true)
        try createSafeFile(formula.appendingPathComponent("lib/libexample.a"))
        try createSafeFile(formula.appendingPathComponent("include/example.h"))

        let discovered = try SourceBuildToolchain.dependencyRoot(
            name: "Example",
            formula: "example",
            requiredFiles: ["lib/libexample.a", "include/example.h"],
            searchRoots: [searchRoot]
        )

        XCTAssertEqual(discovered.standardizedFileURL, formula.standardizedFileURL)
    }

    func testDependencyDiscoveryRejectsMissingOrWritableArtifacts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "quilnode-native-toolchain-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let searchRoot = root.appendingPathComponent("homebrew/opt", isDirectory: true)
        let archive = searchRoot.appendingPathComponent("example/lib/libexample.a")
        try createSafeFile(archive)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o666],
            ofItemAtPath: archive.path
        )

        XCTAssertThrowsError(
            try SourceBuildToolchain.dependencyRoot(
                name: "Example",
                formula: "example",
                requiredFiles: ["lib/libexample.a", "include/example.h"],
                searchRoots: [searchRoot]
            )
        )
    }

    func testDependencyDiscoveryRejectsFormulaSymlinkOutsideApprovedPrefix() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "quilnode-native-toolchain-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let searchRoot = root.appendingPathComponent("homebrew/opt", isDirectory: true)
        let outside = root.appendingPathComponent("untrusted/example", isDirectory: true)
        try createSafeFile(outside.appendingPathComponent("lib/libexample.a"))
        try FileManager.default.createDirectory(at: searchRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: searchRoot.appendingPathComponent("example"),
            withDestinationURL: outside
        )

        XCTAssertThrowsError(
            try SourceBuildToolchain.dependencyRoot(
                name: "Example",
                formula: "example",
                requiredFiles: ["lib/libexample.a"],
                searchRoots: [searchRoot]
            )
        )
    }

    private func createSafeFile(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("fixture".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: url.path
        )
    }
}
