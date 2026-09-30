import Foundation
import QuilNodeCore
import XCTest

@testable import QuilNodeApp

final class SourceBuildDependenciesTests: XCTestCase {
    func testPinnedUpstreamCheckoutWhenExplicitlyProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["QUILNODE_SOURCE_BUILD_TEST_REPOSITORY"] else {
            throw XCTSkip("Set QUILNODE_SOURCE_BUILD_TEST_REPOSITORY to verify a disposable upstream build checkout")
        }
        let repository = URL(fileURLWithPath: path, isDirectory: true)
        let evidence = FileManager.default.temporaryDirectory.appendingPathComponent("quilnode-lock-smoke-\(UUID())")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: evidence) }
        let sandbox = try ReleaseChecker.prepareSourceBuildSandbox(
            workspace: repository.deletingLastPathComponent(), repository: repository
        )
        let receipt = try ReleaseChecker.prepareSourceDependencies(
            repository: repository, sandbox: sandbox, logURL: evidence.appendingPathComponent("build.log")
        )
        let dataset = try ReleaseChecker.prepareSeniorityDataset(in: repository)
        try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
            repository, hydratedSeniorityDataset: dataset, cargoLockfileSHA256: receipt.resolvedSHA256
        )
        _ = try ReleaseChecker.runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile, executable: sandbox.cargoExecutable,
                arguments: ["metadata", "--frozen", "--format-version", "1"]
            ),
            currentDirectory: repository, environment: sandbox.environment, timeout: 120,
            logURL: evidence.appendingPathComponent("metadata.log")
        )
        if ProcessInfo.processInfo.environment["QUILNODE_SOURCE_BUILD_TEST_COMPILE"] == "1" {
            let commit = try ReleaseChecker.runChecked(
                ReleaseChecker.gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(ReleaseChecker.canReusePinnedSourceCheckout(repository, commit: commit))
            let head = GitBranchHead(
                name: "smoke", commit: commit, committedAt: Date(), subject: "Local build smoke test")
            try ReleaseChecker.prepareSourceRepository(
                repository, repositoryURL: "https://github.com/QuilibriumNetwork/monorepo.git", head: head,
                startedAt: Date(), progress: { _ in }
            )
            let version = try XCTUnwrap(
                ReleaseChecker.parseNodeVersion(
                    at: repository.appendingPathComponent("crates/quil-config/src/version.rs"))
            )
            let context = SourceBuildPipelineContext(
                head: head,
                repositoryURL: "https://github.com/QuilibriumNetwork/monorepo.git", startedAt: Date(),
                channel: "smoke", directory: evidence, repository: repository, sourceVersion: version,
                displayVersion: version, seniorityDataset: dataset,
                logURL: evidence.appendingPathComponent("build.log"),
                sandbox: sandbox, dependencyLock: receipt
            )
            let artifact = try ReleaseChecker.compileAndStageSourceNode(context: context) { _ in }
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: artifact.url.path))
        }
    }

    func testStaleLocalCargoGraphIsRepairedOfflineAndLockedFetchSucceeds() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.workspace) }
        let receipt = try ReleaseChecker.prepareSourceDependencies(
            repository: fixture.repository, sandbox: fixture.sandbox, logURL: fixture.logURL
        )
        XCTAssertTrue(receipt.wasRepaired)
        XCTAssertEqual(
            try ReleaseChecker.validatedSourceCargoLockfileSHA256(repository: fixture.repository),
            receipt.resolvedSHA256
        )
        let resolved = try String(contentsOf: fixture.repository.appendingPathComponent("Cargo.lock"), encoding: .utf8)
        XCTAssertFalse(resolved.contains(" \"helper\","))
        XCTAssertTrue(resolved.contains("name = \"helper\""))
        XCTAssertEqual(
            try Data(contentsOf: fixture.logURL.deletingLastPathComponent().appendingPathComponent("Cargo.lock")),
            Data(resolved.utf8)
        )
        let retry = try ReleaseChecker.prepareSourceDependencies(
            repository: fixture.repository, sandbox: fixture.sandbox, logURL: fixture.logURL
        )
        XCTAssertEqual(retry.resolvedSHA256, receipt.resolvedSHA256)
    }

    func testUnrelatedDependencyChangeFailsAndOriginalLockfileIsRestored() throws {
        let fixture = try makeFixture(helperVersion: "0.2.0")
        defer { try? FileManager.default.removeItem(at: fixture.workspace) }
        let original = try Data(contentsOf: fixture.repository.appendingPathComponent("Cargo.lock"))
        XCTAssertThrowsError(
            try ReleaseChecker.prepareSourceDependencies(
                repository: fixture.repository, sandbox: fixture.sandbox, logURL: fixture.logURL
            )
        )
        XCTAssertEqual(try Data(contentsOf: fixture.repository.appendingPathComponent("Cargo.lock")), original)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: fixture.logURL.deletingLastPathComponent().appendingPathComponent("cargo-lock-receipt.json")
                    .path))
    }

    func testOfflineArchiveMissCanContinueOnlyAfterAnApprovedLockRepair() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.workspace) }
        let mockCargo = fixture.workspace.appendingPathComponent("mock-cargo")
        let script = """
            #!/bin/sh
            if [ "$2" = "--offline" ]; then
                /usr/bin/sed -i '' '/^ "helper",$/d' Cargo.lock
                echo 'error: failed to download a pinned archive while offline' >&2
                exit 101
            fi
            if /usr/bin/grep -q '^ "helper",$' Cargo.lock; then
                echo 'error: cannot update the lock file because --locked was passed' >&2
                exit 101
            fi
            exit 0
            """
        try Data(script.utf8).write(to: mockCargo)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: mockCargo.path)
        let sandbox = PreparedSourceBuildSandbox(
            fetchProfile: fixture.sandbox.fetchProfile, compileProfile: fixture.sandbox.compileProfile,
            cargoExecutable: mockCargo.path, environment: fixture.sandbox.environment
        )
        let receipt = try ReleaseChecker.prepareSourceDependencies(
            repository: fixture.repository, sandbox: sandbox, logURL: fixture.logURL
        )
        XCTAssertTrue(receipt.wasRepaired)
        XCTAssertEqual(
            try ReleaseChecker.validatedSourceCargoLockfileSHA256(repository: fixture.repository),
            receipt.resolvedSHA256
        )
    }

    private func makeFixture(helperVersion: String = "0.1.0") throws -> (
        workspace: URL, repository: URL, sandbox: PreparedSourceBuildSandbox, logURL: URL
    ) {
        let cargo = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cargo/bin/cargo")
        guard FileManager.default.isExecutableFile(atPath: cargo.path) else { throw XCTSkip("Cargo is not installed") }
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(
            "quilnode-cargo-test-\(UUID().uuidString)")
        let repository = workspace.appendingPathComponent("repo")
        let evidence = workspace.appendingPathComponent("evidence")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        for name in ["app", "helper"] {
            let directory = repository.appendingPathComponent("\(name)/src")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("pub fn fixture() {}\n".utf8).write(to: directory.appendingPathComponent("lib.rs"))
            let version = name == "helper" ? helperVersion : "0.1.0"
            try Data("[package]\nname = \"\(name)\"\nversion = \"\(version)\"\nedition = \"2021\"\n".utf8)
                .write(to: repository.appendingPathComponent("\(name)/Cargo.toml"))
        }
        try Data("[workspace]\nresolver = \"2\"\nmembers = [\"app\", \"helper\"]\n".utf8).write(
            to: repository.appendingPathComponent("Cargo.toml"))
        let lock = """
            # This file is automatically @generated by Cargo.
            # It is not intended for manual editing.
            version = 4

            [[package]]
            name = "app"
            version = "0.1.0"
            dependencies = [
             "helper",
            ]

            [[package]]
            name = "helper"
            version = "0.1.0"

            """
        try Data(lock.utf8).write(to: repository.appendingPathComponent("Cargo.lock"))
        _ = try ReleaseChecker.runChecked(ReleaseChecker.gitExecutable, ["-C", repository.path, "init", "-q"])
        _ = try ReleaseChecker.runChecked(ReleaseChecker.gitExecutable, ["-C", repository.path, "add", "."])
        _ = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable,
            [
                "-C", repository.path, "-c", "user.name=QuilNode Tests", "-c", "user.email=tests@invalid.local",
                "commit", "-q", "-m", "fixture",
            ]
        )
        let sandbox = try ReleaseChecker.prepareSourceBuildSandbox(workspace: workspace, repository: repository)
        return (workspace, repository, sandbox, evidence.appendingPathComponent("build.log"))
    }
}
