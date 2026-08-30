import Foundation
import XCTest

@testable import QuilNodeHelperKit

final class ServiceConfigurationTests: XCTestCase {
    func testServiceConfigurationRoundTripsWithoutWeakeningTheRequirement() throws {
        let installedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let configuration = ServiceConfiguration(
            controllerUID: 501,
            controllerRequirement: "anchor trusted and identifier \"com.quilnode.app\"",
            installedAt: installedAt
        )

        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(ServiceConfiguration.self, from: encoded)

        XCTAssertEqual(decoded.controllerUID, 501)
        XCTAssertEqual(decoded.controllerRequirement, configuration.controllerRequirement)
        XCTAssertEqual(decoded.installedAt, installedAt)
    }
}
