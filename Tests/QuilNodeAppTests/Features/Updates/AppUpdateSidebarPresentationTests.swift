import XCTest

@testable import QuilNodeApp

final class AppUpdateSidebarPresentationTests: XCTestCase {
    func testRoutineChecksNeverOccupyPersistentNavigation() {
        for phase in [
            AppUpdatePhase.ready,
            .checking,
            .current,
            .unavailable(message: "fixture"),
            .failed(message: "fixture"),
        ] {
            XCTAssertNil(
                AppUpdateSidebarPresentation(
                    phase: phase,
                    availableVersion: nil,
                    canCheck: true
                )
            )
        }
    }

    func testConfirmedUpdateIsActionableAndNamesItsVersion() throws {
        let presentation = try XCTUnwrap(
            AppUpdateSidebarPresentation(
                phase: .updateAvailable(version: "0.1.0-alpha.3"),
                availableVersion: "0.1.0-alpha.3",
                canCheck: true
            )
        )

        XCTAssertEqual(presentation.title, "App update")
        XCTAssertEqual(presentation.detail, "0.1.0-alpha.3")
        XCTAssertEqual(presentation.tone, .available)
        XCTAssertFalse(presentation.showsProgress)
        XCTAssertTrue(presentation.isEnabled)
    }

    func testInstallTransactionKeepsAStableProgressAffordance() throws {
        for phase in [AppUpdatePhase.downloading, .preparing, .installing] {
            let presentation = try XCTUnwrap(
                AppUpdateSidebarPresentation(
                    phase: phase,
                    availableVersion: "0.1.0-alpha.3",
                    canCheck: false
                )
            )
            XCTAssertEqual(presentation.detail, "0.1.0-alpha.3")
            XCTAssertEqual(presentation.tone, .progress)
            XCTAssertTrue(presentation.showsProgress)
            XCTAssertFalse(presentation.isEnabled)
        }
    }

    func testFailedInstallRemainsVisibleOnlyForAKnownCandidate() throws {
        XCTAssertNil(
            AppUpdateSidebarPresentation(
                phase: .failed(message: "fixture"),
                availableVersion: nil,
                canCheck: true
            )
        )

        let retry = try XCTUnwrap(
            AppUpdateSidebarPresentation(
                phase: .failed(message: "fixture"),
                availableVersion: "0.1.0-alpha.3",
                canCheck: true
            )
        )
        XCTAssertEqual(retry.tone, .failure)
        XCTAssertEqual(retry.detail, "Try again")
        XCTAssertTrue(retry.isEnabled)
    }
}
