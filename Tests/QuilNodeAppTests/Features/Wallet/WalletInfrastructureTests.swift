import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class WalletInfrastructureTests: XCTestCase {
    func testCompatibilityClassifierRecognizesOnlyServiceProtocolFailures() {
        XCTAssertTrue(
            WalletServiceCompatibility.requiresUpgrade(
                for: "The passwordless service is not available"
            ))
        XCTAssertTrue(
            WalletServiceCompatibility.requiresUpgrade(
                for: "Invalid passwordless service response: walletInventory"
            ))
        XCTAssertFalse(
            WalletServiceCompatibility.requiresUpgrade(
                for: "The selected keyset is incomplete"
            ))
    }

    func testTransactionStagingUsesPrivateDirectoriesAndFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("quilnode-wallet-staging-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let staging = WalletTransactionStaging(rootDirectory: root)
        let directory = try staging.makeDirectory()
        let manifest = WalletTransactionManifest(
            kind: .create,
            displayName: "Test identity",
            confirmedBackupResponsibility: true
        )
        let manifestURL = try staging.write(manifest, in: directory)

        XCTAssertEqual(permissions(at: root), 0o700)
        XCTAssertEqual(permissions(at: directory), 0o700)
        XCTAssertEqual(permissions(at: manifestURL), 0o600)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            WalletTransactionManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        XCTAssertEqual(decoded.id, manifest.id)
        XCTAssertEqual(decoded.kind, .create)
    }

    private func permissions(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }
}
