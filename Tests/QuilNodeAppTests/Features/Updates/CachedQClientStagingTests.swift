import Foundation
import QuilNodeCore
import QuilNodeShared
import XCTest

@testable import QuilNodeApp

final class CachedQClientStagingTests: XCTestCase {
    func testRetryRequiresMatchingCommitAndUnmodifiedBinary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let commit = String(repeating: "a", count: 40)
        let stage = root.appendingPathComponent("source-aaaaaaaa-fixture")
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        let binary = stage.appendingPathComponent("qclient")
        try Data("compiled fixture".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        let artifact = SignedArtifactActivation(
            kind: .qclient, trust: .pinnedSource, releaseVersion: "2.1.0.25.102",
            reportedVersion: "2.1.0.25.102", binaryFileName: "qclient",
            sha256: try XCTUnwrap(ReleaseChecker.sha256(of: binary)), signatureIndices: [],
            branch: "v2.1.0.25", commit: commit
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifest = stage.appendingPathComponent("qclient-install.json")
        try encoder.encode(QClientActivationManifest(qclient: artifact)).write(to: manifest)
        let node = InstalledNodeBuildParser.parse(
            symlinkTarget: "node-2.1.0.25.102-source-12345678-darwin-arm64")
        let head = GitBranchHead(name: "v2.1.0.25", commit: commit, committedAt: Date(), subject: "fixture")
        XCTAssertEqual(
            try ReleaseChecker.cachedSourceQClientManifest(installed: node, head: head, root: root)?
                .resolvingSymlinksInPath(),
            manifest.resolvingSymlinksInPath()
        )
        try Data("changed fixture".utf8).write(to: binary)
        XCTAssertNil(try ReleaseChecker.cachedSourceQClientManifest(installed: node, head: head, root: root))
    }
}
