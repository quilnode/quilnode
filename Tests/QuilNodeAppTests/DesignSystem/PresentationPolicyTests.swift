import XCTest

@testable import QuilNodeApp

final class PresentationPolicyTests: XCTestCase {
    func testPrivacyVocabularyUsesFixedLengthMasks() {
        XCTAssertEqual(PrivacyField.activeShardCount.mask.text, "***")
        XCTAssertEqual(PrivacyField.quilBalance.mask.text, "*****")
        XCTAssertEqual(PrivacyField.networkIdentifier.mask.text, "**********")

        XCTAssertEqual(Set(PrivacyField.allCases.map(\.accessibilityName)).count, PrivacyField.allCases.count)
    }

    func testEpochEstimateWaitsForCrediblePaceEvidence() {
        XCTAssertEqual(EpochEstimateFormatter.compact(framesRemaining: 720, framesPerMinute: nil), "ETA learning")
        XCTAssertEqual(
            EpochEstimateFormatter.detailed(framesRemaining: 720, framesPerMinute: 0.01), "ETA learning local pace")
    }
}
