import Darwin
import Foundation
import XCTest

@testable import QuilNodeShared

final class LocalFileSecurityTests: XCTestCase {
    func testBoundedReadsRejectLinksAndSpecialFiles() throws {
        let root = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let payload = root.appendingPathComponent("payload.log")
        try Data("first\nsecond\nthird\n".utf8).write(to: payload)
        XCTAssertEqual(chmod(payload.path, 0o600), 0)
        XCTAssertEqual(
            try BoundedLocalData.read(from: payload, maximumBytes: 1_024),
            Data("first\nsecond\nthird\n".utf8)
        )
        XCTAssertEqual(
            try BoundedLocalData.readTail(
                from: payload,
                maximumFileBytes: 1_024,
                maximumTailBytes: 6
            ),
            Data("third\n".utf8)
        )

        let hardLink = root.appendingPathComponent("payload-hard-link.log")
        XCTAssertEqual(link(payload.path, hardLink.path), 0)
        XCTAssertThrowsError(try BoundedLocalData.read(from: payload, maximumBytes: 1_024))
        XCTAssertEqual(unlink(hardLink.path), 0)

        let symbolicLink = root.appendingPathComponent("payload-symbolic-link.log")
        XCTAssertEqual(symlink(payload.path, symbolicLink.path), 0)
        XCTAssertThrowsError(try BoundedLocalData.read(from: symbolicLink, maximumBytes: 1_024))

        let fifo = root.appendingPathComponent("payload.fifo")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        XCTAssertThrowsError(
            try BoundedLocalData.readTail(
                from: fifo,
                maximumFileBytes: 1_024,
                maximumTailBytes: 64
            )
        )
    }

    func testPersistedPathsStayInsidePrivateApplicationStorage() throws {
        let root = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let staging = root.appendingPathComponent("UpdateStaging", isDirectory: true)
        let operation = staging.appendingPathComponent("source-deadbeef", isDirectory: true)
        try createPrivateDirectory(staging)
        try createPrivateDirectory(operation)
        let log = operation.appendingPathComponent("build.log")
        try Data("compiler output".utf8).write(to: log)
        XCTAssertEqual(chmod(log.path, 0o600), 0)

        XCTAssertEqual(
            TrustedLocalFile.validate(
                log,
                inside: staging,
                relativeDepth: 2,
                allowedFileNames: ["build.log"]
            ),
            log.standardizedFileURL
        )

        let outside = root.deletingLastPathComponent().appendingPathComponent("outside-secret")
        try Data("not a build log".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        XCTAssertNil(
            TrustedLocalFile.validate(
                outside,
                inside: staging,
                relativeDepth: 2,
                allowedFileNames: ["build.log"]
            )
        )

        let linked = operation.appendingPathComponent("linked.log")
        XCTAssertEqual(symlink(outside.path, linked.path), 0)
        XCTAssertNil(
            TrustedLocalFile.validate(
                linked,
                inside: staging,
                relativeDepth: 2,
                allowedPathExtensions: ["log"]
            )
        )

        XCTAssertEqual(chmod(operation.path, 0o755), 0)
        XCTAssertNil(
            TrustedLocalFile.validate(
                log,
                inside: staging,
                relativeDepth: 2,
                allowedFileNames: ["build.log"]
            )
        )
    }

    func testPrivateAtomicWritesReplaceLinksWithoutTouchingTheirTargets() throws {
        let root = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let state = root.appendingPathComponent("State", isDirectory: true)
        try PrivateLocalFileSystem.ensureDirectory(at: state)
        let outside = root.appendingPathComponent("outside.txt")
        try Data("unchanged".utf8).write(to: outside)
        let destination = state.appendingPathComponent("state.json")
        XCTAssertEqual(symlink(outside.path, destination.path), 0)

        try PrivateLocalFileSystem.write(Data("replacement".utf8), atomicallyTo: destination)
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "unchanged")
        XCTAssertEqual(
            try BoundedLocalData.read(from: destination, maximumBytes: 1_024),
            Data("replacement".utf8)
        )

        let linkedDirectory = root.appendingPathComponent("LinkedState", isDirectory: true)
        XCTAssertEqual(symlink(state.path, linkedDirectory.path), 0)
        XCTAssertThrowsError(try PrivateLocalFileSystem.ensureDirectory(at: linkedDirectory))

        let captureLink = state.appendingPathComponent("capture.log")
        XCTAssertEqual(symlink(outside.path, captureLink.path), 0)
        XCTAssertThrowsError(try PrivateLocalFileSystem.openCaptureFile(at: captureLink))
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "unchanged")
    }

    func testDescriptorRelativeTrustedReadRejectsEscapes() throws {
        let root = try makePrivateDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent("UpdateStaging", isDirectory: true)
        let operation = staging.appendingPathComponent("source-safe", isDirectory: true)
        try PrivateLocalFileSystem.ensureDirectory(at: staging)
        try PrivateLocalFileSystem.ensureDirectory(at: operation)
        let manifest = operation.appendingPathComponent("activation.json")
        try PrivateLocalFileSystem.write(Data("{}".utf8), atomicallyTo: manifest)

        XCTAssertEqual(
            try TrustedLocalFile.read(
                manifest,
                inside: staging,
                relativeDepth: 2,
                allowedFileNames: ["activation.json"],
                maximumBytes: 1_024
            ),
            Data("{}".utf8)
        )
        let outside = root.appendingPathComponent("activation.json")
        try PrivateLocalFileSystem.write(Data("secret".utf8), atomicallyTo: outside)
        XCTAssertThrowsError(
            try TrustedLocalFile.read(
                outside,
                inside: staging,
                relativeDepth: 2,
                allowedFileNames: ["activation.json"],
                maximumBytes: 1_024
            )
        )
    }

    private func makePrivateDirectory() throws -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("quilnode-local-file-test-\(UUID().uuidString)", isDirectory: true)
        try createPrivateDirectory(root)
        return root
    }

    private func createPrivateDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        XCTAssertEqual(chmod(url.path, 0o700), 0)
    }
}
