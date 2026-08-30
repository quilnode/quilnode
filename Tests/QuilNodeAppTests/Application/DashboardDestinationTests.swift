import XCTest

@testable import QuilNodeApp

final class DashboardDestinationTests: XCTestCase {
    func testRemediationDestinationsNeverWaitForInitialTelemetry() {
        XCTAssertFalse(DashboardDestination.overview.waitsForInitialTelemetry)
        XCTAssertFalse(DashboardDestination.recovery.waitsForInitialTelemetry)
        XCTAssertFalse(DashboardDestination.updates.waitsForInitialTelemetry)
        XCTAssertFalse(DashboardDestination.diagnostics.waitsForInitialTelemetry)
    }

    func testLiveObservationDestinationsWaitForTheFirstCompleteSample() {
        XCTAssertTrue(DashboardDestination.activity.waitsForInitialTelemetry)
        XCTAssertTrue(DashboardDestination.network.waitsForInitialTelemetry)
        XCTAssertTrue(DashboardDestination.identity.waitsForInitialTelemetry)
    }
}
