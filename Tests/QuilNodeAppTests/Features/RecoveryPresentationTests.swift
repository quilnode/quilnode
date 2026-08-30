import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class RecoveryPresentationTests: XCTestCase {
    func testManagedIdentitySeparatesRollbackFromOperatorBackup() {
        let keyset = makeKeyset(
            isManaged: true,
            automaticRecoveryCopies: 1,
            lastExternalBackupAt: nil
        )
        let presentation = RecoveryWorkspacePresentation.make(inventory: inventory(with: keyset))

        XCTAssertEqual(presentation.recommendation.kind, .createSeparateBackup)
        XCTAssertEqual(stage(.activePackage, in: presentation).state, .verified)
        XCTAssertEqual(stage(.automaticRollback, in: presentation).state, .verified)
        XCTAssertEqual(stage(.separateBackup, in: presentation).state, .recommended)
        XCTAssertEqual(stage(.automaticRollback, in: presentation).privacyField, .recoveryMetadata)
        XCTAssertNil(stage(.separateBackup, in: presentation).privacyField)
    }

    func testRecordedExternalBackupChangesMaintenanceRecommendation() {
        let keyset = makeKeyset(
            isManaged: true,
            automaticRecoveryCopies: 2,
            lastExternalBackupAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let presentation = RecoveryWorkspacePresentation.make(inventory: inventory(with: keyset))

        XCTAssertEqual(presentation.recommendation.kind, .maintainCoverage)
        XCTAssertEqual(stage(.separateBackup, in: presentation).state, .verified)
        XCTAssertEqual(stage(.separateBackup, in: presentation).privacyField, .localTimestamp)
    }

    func testUnmanagedActiveIdentityPrioritizesProtection() {
        let keyset = makeKeyset(
            isManaged: false,
            automaticRecoveryCopies: 0,
            lastExternalBackupAt: nil
        )
        let presentation = RecoveryWorkspacePresentation.make(inventory: inventory(with: keyset))

        XCTAssertEqual(presentation.recommendation.kind, .protectActive)
        XCTAssertEqual(stage(.activePackage, in: presentation).state, .review)
        XCTAssertTrue(presentation.readinessDetail.localizedCaseInsensitiveContains("secure local"))
    }

    func testEmptyInventoryDoesNotPromiseRecovery() {
        let presentation = RecoveryWorkspacePresentation.make(inventory: WalletInventory())

        XCTAssertEqual(presentation.recommendation.kind, .addIdentity)
        XCTAssertEqual(presentation.storedIdentityCount, 0)
        XCTAssertTrue(presentation.stages.allSatisfy { $0.state != .verified })
    }

    private func stage(
        _ layer: RecoveryLayer,
        in presentation: RecoveryWorkspacePresentation
    ) -> RecoveryLayerPresentation {
        presentation.stages.first(where: { $0.layer == layer })!
    }

    private func inventory(with keyset: ManagedKeyset) -> WalletInventory {
        WalletInventory(
            keysets: [keyset],
            activeKeysetID: keyset.id,
            serviceSupportsTransactions: true,
            recoveryVaultHealthy: true
        )
    }

    private func makeKeyset(
        isManaged: Bool,
        automaticRecoveryCopies: Int,
        lastExternalBackupAt: Date?
    ) -> ManagedKeyset {
        ManagedKeyset(
            name: "My seniority identity",
            format: .current25,
            health: .ready,
            isActive: true,
            isManaged: isManaged,
            keyCount: 9,
            keyTypes: ["proving", "consensus"],
            sourceLabel: "Adopted from existing node",
            lastActivatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastExternalBackupAt: lastExternalBackupAt,
            automaticRecoveryCopies: automaticRecoveryCopies,
            fingerprint: "public-fingerprint"
        )
    }
}
