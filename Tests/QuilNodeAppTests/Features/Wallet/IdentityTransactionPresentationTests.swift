import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class IdentityTransactionPresentationTests: XCTestCase {
    func testLegacyImportExplainsMigrationWithoutChangingRuntime() {
        let presentation = IdentityTransactionPresentation.make(
            for: .importKeyset(
                PendingKeysetImport(
                    selectedDirectory: URL(fileURLWithPath: "/preview/keyset"),
                    inspection: legacyInspection,
                    suggestedName: "Seniority identity"
                )
            )
        )

        XCTAssertEqual(presentation.kind, .importKeyset)
        XCTAssertTrue(presentation.supportsDisposition)
        XCTAssertEqual(presentation.stages.map(\.title), ["Inspect", "Preserve", "Prepare", "Activate"])
        XCTAssertEqual(
            presentation.stages(for: .recoveryOnly).map(\.title),
            ["Inspect", "Preserve", "Prepare", "Store"]
        )
        XCTAssertEqual(fact("migration", in: presentation).state, .attention)
        XCTAssertEqual(fact("fingerprint", in: presentation).privacyField, .recoveryMetadata)
        XCTAssertEqual(fact("entries", in: presentation).privacyField, .recoveryMetadata)
        XCTAssertEqual(Set(presentation.untouched.map(\.id)), ["stores", "config", "binary"])
    }

    func testCurrentImportDoesNotInventMigration() {
        let inspection = KeysetInspection(
            format: .current25,
            health: .ready,
            requiresMigration: false,
            keyCount: 9,
            keyTypes: ["proving", "wallet"],
            fingerprint: "fingerprint",
            warnings: [],
            hasConfig: true,
            hasKeys: true
        )
        let presentation = IdentityTransactionPresentation.make(
            for: .importKeyset(
                PendingKeysetImport(
                    selectedDirectory: URL(fileURLWithPath: "/preview/keyset"),
                    inspection: inspection,
                    suggestedName: "Current identity"
                )
            )
        )

        XCTAssertEqual(fact("migration", in: presentation).value, "Not required")
        XCTAssertEqual(fact("migration", in: presentation).state, .verified)
    }

    func testAdoptionPromisesNoIdentitySwitch() {
        let presentation = IdentityTransactionPresentation.make(for: .adopt(keyset(isActive: true)))

        XCTAssertEqual(presentation.kind, .adopt)
        XCTAssertFalse(presentation.supportsDisposition)
        XCTAssertTrue(presentation.detail.localizedCaseInsensitiveContains("without switching"))
        XCTAssertEqual(presentation.moments.last?.title, "After")
        XCTAssertTrue(
            presentation.moments.last?.detail.localizedCaseInsensitiveContains("same running identity") == true)
    }

    func testActivationAlwaysSurfacesRollbackAndStorePreservation() {
        let presentation = IdentityTransactionPresentation.make(for: .activate(keyset(isActive: false)))

        XCTAssertEqual(presentation.kind, .activate)
        XCTAssertTrue(presentation.changes.contains { $0.id == "recovery-copy" })
        XCTAssertTrue(presentation.untouched.contains { $0.id == "stores" })
        XCTAssertEqual(presentation.primaryTitle, "Switch & verify")
    }

    private var legacyInspection: KeysetInspection {
        KeysetInspection(
            format: .legacyPre25,
            health: .migrationRequired,
            requiresMigration: true,
            keyCount: 11,
            keyTypes: ["proving", "consensus", "wallet"],
            fingerprint: "fingerprint",
            warnings: [],
            hasConfig: true,
            hasKeys: true
        )
    }

    private func keyset(isActive: Bool) -> ManagedKeyset {
        ManagedKeyset(
            name: "Seniority identity",
            format: .legacyPre25,
            health: .migrationRequired,
            isActive: isActive,
            isManaged: true,
            requiresMigration: true,
            keyCount: 11,
            keyTypes: ["proving", "consensus", "wallet"],
            sourceLabel: "Imported legacy keyset",
            automaticRecoveryCopies: 1,
            fingerprint: "fingerprint"
        )
    }

    private func fact(
        _ id: String,
        in presentation: IdentityTransactionPresentation
    ) -> IdentityTransactionFact {
        presentation.facts.first(where: { $0.id == id })!
    }
}
