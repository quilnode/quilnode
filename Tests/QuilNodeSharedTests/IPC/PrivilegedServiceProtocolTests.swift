import XCTest

@testable import QuilNodeShared

final class PrivilegedServiceProtocolTests: XCTestCase {
    func testEveryActionRoundTripsThroughTheSharedWireContract() throws {
        for action in PrivilegedServiceAction.allCases {
            let request = PrivilegedServiceRequest(
                action: action,
                manifestPath: "/private/tmp/candidate.json",
                operationID: "operation-id",
                nodeUpdatePolicy: .approvedDevelopment
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
            XCTAssertEqual(decoded.nodeUpdatePolicy, .approvedDevelopment)
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
            operationStage: .probingRuntime,
            serviceBuild: PrivilegedServiceProtocol.currentServiceBuild,
            authorizationRequired: true,
            nodeUpdatePolicy: .signedStable
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
        XCTAssertEqual(decoded.operationStage, .probingRuntime)
        XCTAssertEqual(
            decoded.serviceBuild,
            PrivilegedServiceProtocol.currentServiceBuild
        )
        XCTAssertEqual(decoded.authorizationRequired, true)
        XCTAssertEqual(decoded.nodeUpdatePolicy, .signedStable)
        XCTAssertLessThan(encoded.count, PrivilegedServiceProtocol.maximumResponseBytes)
    }

    func testAutomaticUpdatePoliciesPermitOnlyTheirExplicitChannels() {
        XCTAssertTrue(AutomaticNodeUpdatePolicy.signedStable.permitsPasswordlessActivation(channel: "signed"))
        XCTAssertFalse(
            AutomaticNodeUpdatePolicy.signedStable.permitsPasswordlessActivation(channel: "approved-dev")
        )

        XCTAssertTrue(
            AutomaticNodeUpdatePolicy.approvedDevelopment.permitsPasswordlessActivation(
                channel: "approved-dev"
            )
        )
        XCTAssertFalse(
            AutomaticNodeUpdatePolicy.approvedDevelopment.permitsPasswordlessActivation(channel: "raw-dev")
        )

        XCTAssertTrue(
            AutomaticNodeUpdatePolicy.bleedingEdge.permitsPasswordlessActivation(channel: "raw-dev")
        )
        XCTAssertFalse(
            AutomaticNodeUpdatePolicy.bleedingEdge.permitsPasswordlessActivation(channel: "source")
        )
    }
}
