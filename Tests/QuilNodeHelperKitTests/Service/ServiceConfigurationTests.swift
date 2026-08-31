import Foundation
import XCTest

@testable import QuilNodeHelperKit
@testable import QuilNodeShared

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

    func testAutomaticUpdatePolicyRecordRoundTrips() throws {
        let updatedAt = Date(timeIntervalSince1970: 2_000_000_100)
        let record = AutomaticNodeUpdatePolicyRecord(
            policy: .approvedDevelopment,
            updatedAt: updatedAt
        )

        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(
            AutomaticNodeUpdatePolicyRecord.self,
            from: encoded
        )

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.policy, .approvedDevelopment)
        XCTAssertEqual(decoded.updatedAt, updatedAt)
    }

    func testDurableOperationRecordDecodesBeforeAndAfterStageReporting() throws {
        let legacy = Data(
            #"{"id":"op","action":"qclientInstall","state":"running","message":"Accepted","startedAt":0,"updatedAt":0}"#.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let legacyRecord = try decoder.decode(ServiceOperationRecord.self, from: legacy)
        XCTAssertNil(legacyRecord.stage)

        let staged = ServiceOperationRecord(
            id: "op",
            action: "qclientInstall",
            idempotencyKey: "artifact-sha",
            state: .running,
            stage: .probingRuntime,
            message: "Checking qclient version",
            startedAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let encoded = try JSONEncoder().encode(staged)
        XCTAssertEqual(try JSONDecoder().decode(ServiceOperationRecord.self, from: encoded).stage, .probingRuntime)
    }
}
