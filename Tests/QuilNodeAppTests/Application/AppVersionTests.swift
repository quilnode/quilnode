import XCTest

@testable import QuilNodeApp

final class AppVersionTests: XCTestCase {
    func testPrereleaseLabelDoesNotReplaceTheNumericBuild() {
        let version = AppVersion(info: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "111",
            "QuilNodeReleaseVersion": "0.1.0-alpha.1",
        ])

        XCTAssertEqual(version.displayVersion, "0.1.0-alpha.1")
        XCTAssertEqual(version.build, "111")
    }

    func testOlderBundlesFallBackToTheNumericVersion() {
        let version = AppVersion(info: [
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "110",
        ])

        XCTAssertEqual(version.displayVersion, "1.0.0")
        XCTAssertEqual(version.build, "110")
    }

    func testMissingBundleMetadataUsesDevelopmentLabels() {
        let version = AppVersion(info: [:])
        XCTAssertEqual(version.displayVersion, "Development")
        XCTAssertEqual(version.build, "—")
    }

    func testBlankOrWrongTypeLabelsDoNotHideTheVersion() {
        for invalid in [" \n", 42] as [Any] {
            let version = AppVersion(info: [
                "QuilNodeReleaseVersion": invalid,
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": " ",
            ])
            XCTAssertEqual(version.displayVersion, "0.1.0")
            XCTAssertEqual(version.build, "—")
        }
    }
}
