import CryptoKit
import Foundation
import QuilNodeCore
import XCTest

@testable import QuilNodeApp

final class SourceCheckoutIntegrityTests: XCTestCase {
    private static let datasetPath =
        "node/execution/intrinsics/global/compat/mainnet_244200_seniority.json"

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
            ["-C", repository.path, "add", ".gitattributes", "tracked.txt", Self.datasetPath]
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
