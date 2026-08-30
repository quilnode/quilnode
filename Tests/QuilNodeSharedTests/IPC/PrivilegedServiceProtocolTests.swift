import XCTest

@testable import QuilNodeShared

final class PrivilegedServiceProtocolTests: XCTestCase {
    func testEveryActionRoundTripsThroughTheSharedWireContract() throws {
        for action in PrivilegedServiceAction.allCases {
            let request = PrivilegedServiceRequest(
                action: action,
                manifestPath: "/private/tmp/candidate.json",
                operationID: "operation-id"
            )
            let encoded = try JSONEncoder().encode(request)
            let decoded = try JSONDecoder().decode(
                PrivilegedServiceRequest.self,
                from: encoded
            )

            XCTAssertEqual(decoded.protocolVersion, PrivilegedServiceProtocol.version)
            XCTAssertEqual(decoded.action, action)
            XCTAssertEqual(decoded.manifestPath, request.manifestPath)
            XCTAssertEqual(decoded.operationID, request.operationID)
            XCTAssertLessThan(encoded.count, PrivilegedServiceProtocol.maximumRequestBytes)
        }
    }

    func testResponseRoundTripsSecurityBoundaryFields() throws {
        let response = PrivilegedServiceResponse(
            success: false,
            message: "Fresh authorization is required.",
            serviceUser: nil,
            operationID: "operation-id",
            operationState: "failed",
            serviceBuild: PrivilegedServiceProtocol.currentServiceBuild,
            authorizationRequired: true
        )

        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(
            PrivilegedServiceResponse.self,
            from: encoded
        )

        XCTAssertEqual(decoded.protocolVersion, PrivilegedServiceProtocol.version)
        XCTAssertFalse(decoded.success)
        XCTAssertNil(decoded.serviceUser)
        XCTAssertEqual(decoded.operationID, "operation-id")
        XCTAssertEqual(decoded.operationState, "failed")
        XCTAssertEqual(
            decoded.serviceBuild,
            PrivilegedServiceProtocol.currentServiceBuild
        )
        XCTAssertEqual(decoded.authorizationRequired, true)
        XCTAssertLessThan(encoded.count, PrivilegedServiceProtocol.maximumResponseBytes)
    }
}
