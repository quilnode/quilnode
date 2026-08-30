import XCTest

@testable import QuilNodeApp

final class DashboardLayoutClassTests: XCTestCase {
    func testLayoutClassesUseAvailableContentWidth() {
        XCTAssertEqual(DashboardLayoutClass(contentWidth: 0), .compact)
        XCTAssertEqual(DashboardLayoutClass(contentWidth: 859), .compact)
        XCTAssertEqual(DashboardLayoutClass(contentWidth: 860), .regular)
        XCTAssertEqual(DashboardLayoutClass(contentWidth: 1_119), .regular)
        XCTAssertEqual(DashboardLayoutClass(contentWidth: 1_120), .wide)
    }
}
