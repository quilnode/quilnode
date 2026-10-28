import XCTest

@testable import QuilNodeCore

final class ListenerEvidenceTests: XCTestCase {
    func testUnavailableInspectionNeverClaimsRequiredPortsAreMissing() {
        var node = NodeSnapshot.empty
        node.isRunning = true
        node.processID = 42
        let inspection = NetworkLocalInspection(processID: 42, listenerInspectionError: "Inspection unavailable")
        let result = NetworkReadinessEvaluator.evaluate(node: node, inspection: inspection)
        XCTAssertEqual(result.state, .inspecting)
        XCTAssertTrue(result.missingMasterPorts.isEmpty)
    }

    func testInboundMetricsRemainValidWhenMacOSDoesNotExposeSockets() {
        var node = NodeSnapshot.empty
        node.isRunning = true
        node.processID = 42
        node.inboundConnectionsEstablished = 8
        let result = NetworkReadinessEvaluator.evaluate(node: node, inspection: .empty)
        XCTAssertEqual(result.state, .inboundVerified)
        XCTAssertTrue(result.detail.contains("could not be inspected"))
    }

    func testPriorProcessListenersCannotValidateOrBlameItsReplacement() {
        var node = NodeSnapshot.empty
        node.isRunning = true
        node.processID = 43
        let previous = NetworkLocalInspection(processID: 42, tcpListeners: [8336, 8340], inspectionSucceeded: true)
        XCTAssertEqual(NetworkReadinessEvaluator.evaluate(node: node, inspection: previous).state, .inspecting)
        let emptyPrevious = NetworkLocalInspection(processID: 42, inspectionSucceeded: true)
        XCTAssertEqual(NetworkReadinessEvaluator.evaluate(node: node, inspection: emptyPrevious).state, .inspecting)
    }

    func testVerifiedIncompleteProcessInspectionStillReportsRealMissingPort() {
        var node = NodeSnapshot.empty
        node.isRunning = true
        node.processID = 42
        node.inboundConnectionsEstablished = 8
        let inspection = NetworkLocalInspection(processID: 42, tcpListeners: [8336], inspectionSucceeded: true)
        let result = NetworkReadinessEvaluator.evaluate(node: node, inspection: inspection)
        XCTAssertEqual(result.state, .localConfigurationIssue)
        XCTAssertEqual(result.missingMasterPorts, [8340])
    }
}
