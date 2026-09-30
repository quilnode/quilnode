import CryptoKit
import Foundation
import QuilNodeCore
import XCTest

@testable import QuilNodeApp

final class SourceCheckoutIntegrityTests: XCTestCase {
    private static let datasetPath =
        "node/execution/intrinsics/global/compat/mainnet_244200_seniority.json"

    func testVerifiedSameCommitCheckoutCanBeReusedWithoutRewritingInputs() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        let commit = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable, ["-C", fixture.repository.path, "rev-parse", "HEAD"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let dataset = fixture.repository.appendingPathComponent(Self.datasetPath)
        let before = try dataset.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        XCTAssertTrue(ReleaseChecker.canReusePinnedSourceCheckout(fixture.repository, commit: commit))
        let remote = "https://invalid.local/no-network-needed.git"
        _ = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable, ["-C", fixture.repository.path, "remote", "add", "origin", remote]
        )
        try ReleaseChecker.prepareSourceRepository(
            fixture.repository, repositoryURL: remote,
            head: GitBranchHead(name: "fixture", commit: commit, committedAt: Date(), subject: "fixture"),
            startedAt: Date(), progress: { _ in }
        )
        XCTAssertEqual(
            try dataset.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, before)
        XCTAssertFalse(
            ReleaseChecker.canReusePinnedSourceCheckout(fixture.repository, commit: String(repeating: "0", count: 40)))
        try Data("tampered\n".utf8).write(to: fixture.repository.appendingPathComponent("tracked.txt"))
        XCTAssertFalse(ReleaseChecker.canReusePinnedSourceCheckout(fixture.repository, commit: commit))
    }

    func testSameCommitCacheRejectsDatasetAndDependencyTampering() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        let commit = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable, ["-C", fixture.repository.path, "rev-parse", "HEAD"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let dataset = fixture.repository.appendingPathComponent(Self.datasetPath)
        try Data("invalid dataset".utf8).write(to: dataset)
        XCTAssertFalse(ReleaseChecker.canReusePinnedSourceCheckout(fixture.repository, commit: commit))
        try fixture.payload.write(to: dataset)
        let lock = fixture.repository.appendingPathComponent("Cargo.lock")
        let original = try String(contentsOf: lock, encoding: .utf8)
        try Data(original.replacingOccurrences(of: "version = \"0.1.0\"", with: "version = \"9.9.9\"").utf8).write(
            to: lock)
        XCTAssertFalse(ReleaseChecker.canReusePinnedSourceCheckout(fixture.repository, commit: commit))
    }

    func testHydratedDatasetIsAcceptedWithoutMachineGitLFSFilters() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }

        XCTAssertNoThrow(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository,
                hydratedSeniorityDataset: fixture.pointer
            )
        )
    }

    func testAnotherTrackedModificationIsRejected() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        try Data("changed\n".utf8).write(
            to: fixture.repository.appendingPathComponent("tracked.txt"),
            options: .atomic
        )

        XCTAssertThrowsError(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository,
                hydratedSeniorityDataset: fixture.pointer
            )
        )
    }

    func testStagedModificationIsRejected() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        try Data("staged\n".utf8).write(
            to: fixture.repository.appendingPathComponent("tracked.txt"),
            options: .atomic
        )
        _ = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable,
            ["-C", fixture.repository.path, "add", "tracked.txt"]
        )

        XCTAssertThrowsError(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository,
                hydratedSeniorityDataset: fixture.pointer
            )
        )
    }

    func testHydratedDatasetTamperingIsRejected() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        let dataset = fixture.repository.appendingPathComponent(Self.datasetPath)
        var tampered = fixture.payload
        tampered[0] ^= 0xff
        try tampered.write(to: dataset, options: .atomic)

        XCTAssertThrowsError(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository,
                hydratedSeniorityDataset: fixture.pointer
            )
        )
    }

    func testApprovedCargoRepairRequiresItsExactDigest() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        let lockURL = fixture.repository.appendingPathComponent("Cargo.lock")
        let original = try String(contentsOf: lockURL, encoding: .utf8)
        try Data(original.replacingOccurrences(of: "dependencies = [\n \"helper\",\n]\n", with: "").utf8)
            .write(to: lockURL, options: .atomic)
        let digest = try ReleaseChecker.validatedSourceCargoLockfileSHA256(repository: fixture.repository)
        XCTAssertNoThrow(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository, hydratedSeniorityDataset: fixture.pointer, cargoLockfileSHA256: digest
            ))
        XCTAssertThrowsError(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository, hydratedSeniorityDataset: fixture.pointer, cargoLockfileSHA256: "incorrect"
            ))
        XCTAssertThrowsError(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository, hydratedSeniorityDataset: fixture.pointer
            ))
    }

    func testCargoPackageTamperingIsRejectedEvenWithItsNewDigest() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.repository) }
        let lockURL = fixture.repository.appendingPathComponent("Cargo.lock")
        let original = try String(contentsOf: lockURL, encoding: .utf8)
        let tampered = Data(original.replacingOccurrences(of: "version = \"0.1.0\"", with: "version = \"0.2.0\"").utf8)
        try tampered.write(to: lockURL, options: .atomic)
        let digest = SHA256.hash(data: tampered).map { String(format: "%02x", $0) }.joined()
        XCTAssertThrowsError(
            try ReleaseChecker.verifyPinnedCheckoutIsUnmodified(
                fixture.repository, hydratedSeniorityDataset: fixture.pointer, cargoLockfileSHA256: digest
            ))
    }

    private func makeFixture() throws -> (
        repository: URL,
        pointer: GitLFSPointer,
        payload: Data
    ) {
        let repository = FileManager.default.temporaryDirectory
            .appendingPathComponent("quilnode-source-integrity-\(UUID().uuidString)", isDirectory: true)
        let dataset = repository.appendingPathComponent(Self.datasetPath)
        try FileManager.default.createDirectory(
            at: dataset.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = Data((0..<16_384).map { UInt8($0 % 251) })
        let oid = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let pointer = GitLFSPointer(oid: oid, size: payload.count)
        let pointerText = """
            version https://git-lfs.github.com/spec/v1
            oid sha256:\(oid)
            size \(payload.count)
            """
        try Data(pointerText.utf8).write(to: dataset, options: .atomic)
        try Data("fixture\n".utf8).write(
            to: repository.appendingPathComponent("tracked.txt"),
            options: .atomic
        )
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
        try Data(lock.utf8).write(to: repository.appendingPathComponent("Cargo.lock"), options: .atomic)
        try Data("\(Self.datasetPath) filter=lfs diff=lfs merge=lfs -text\n".utf8).write(
            to: repository.appendingPathComponent(".gitattributes"),
            options: .atomic
        )
        _ = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable,
            ["-C", repository.path, "init", "-q"]
        )
        _ = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable,
            ["-C", repository.path, "add", ".gitattributes", "tracked.txt", "Cargo.lock", Self.datasetPath]
        )
        _ = try ReleaseChecker.runChecked(
            ReleaseChecker.gitExecutable,
            [
                "-C", repository.path,
                "-c", "user.name=QuilNode Tests",
                "-c", "user.email=tests@invalid.local",
                "commit", "-q", "-m", "fixture",
            ]
        )
        try payload.write(to: dataset, options: .atomic)
        return (repository, pointer, payload)
    }
}
