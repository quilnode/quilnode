import XCTest

@testable import QuilNodeApp

final class PresentationPolicyTests: XCTestCase {
    func testPrivacyVocabularyUsesFixedLengthMasks() {
        XCTAssertEqual(PrivacyField.activeShardCount.mask.text, "***")
        XCTAssertEqual(PrivacyField.quilBalance.mask.text, "*****")
        XCTAssertEqual(PrivacyField.networkIdentifier.mask.text, "**********")

        XCTAssertEqual(Set(PrivacyField.allCases.map(\.accessibilityName)).count, PrivacyField.allCases.count)
    }

    func testPrivacyCollectionPlaceholderHasFixedDensity() {
        XCTAssertEqual(PrivacyLayoutPolicy.collectionPlaceholderCount, 3)
    }

    func testEpochEstimateWaitsForCrediblePaceEvidence() {
        XCTAssertEqual(EpochEstimateFormatter.compact(framesRemaining: 720, framesPerMinute: nil), "ETA learning")
        XCTAssertEqual(
            EpochEstimateFormatter.detailed(framesRemaining: 720, framesPerMinute: 0.01), "ETA learning local pace")
    }

    @MainActor
    func testThemeFamiliesAndLegacyDefaultMigration() {
        let modesByFamily = Dictionary(grouping: QuilTheme.builtIns, by: \.familyID)
            .mapValues { Set($0.map(\.appearance)) }
        XCTAssertTrue(modesByFamily.values.allSatisfy { $0 == Set([.light, .dark]) })
        XCTAssertEqual(QuilTheme.quilNode.familyID, "quilnode.default")
        XCTAssertEqual(QuilTheme.classic.name, "Quilibrium")

        let suiteName = "ThemeControllerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated theme defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("quil.classic", forKey: "selectedQuilThemeID")
        XCTAssertEqual(
            ThemeController.migratedInitialThemeSelection(defaults: defaults),
            QuilTheme.quilNode.familyID
        )

        defaults.set("omarchy.nord", forKey: "selectedQuilThemeID")
        XCTAssertEqual(
            ThemeController.migratedInitialThemeSelection(defaults: defaults),
            "omarchy.nord",
            "The one-time migration must never overwrite later explicit choices"
        )
    }
}
