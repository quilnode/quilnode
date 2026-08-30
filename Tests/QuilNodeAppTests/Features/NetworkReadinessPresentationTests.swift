import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class NetworkReadinessPresentationTests: XCTestCase {
    func testInboundEvidenceIsSeparatedFromCurrentPeerCount() {
        let presentation = makePresentation(
            snapshot: NodeSnapshot(
                isRunning: true,
                peers: 248,
                inboundConnectionsEstablished: 9
            ),
            assessment: NetworkReadinessAssessment(
                state: .inboundVerified,
                title: "Inbound peer traffic verified",
                detail: "Observed locally"
            )
        )

        XCTAssertEqual(presentation.stage(.internetBoundary).state, .verified)
        XCTAssertEqual(presentation.stage(.inboundPeers).value, "248")
        XCTAssertTrue(presentation.stage(.inboundPeers).detail.contains("not unique peers"))
        XCTAssertEqual(presentation.routerTasks[1].state, .complete)
    }

    func testPeerMeshAloneDoesNotClaimInboundReachability() {
        let presentation = makePresentation(
            snapshot: NodeSnapshot(isRunning: true, peers: 248),
            assessment: NetworkReadinessAssessment(
                state: .waitingForEvidence,
                title: "Waiting for inbound evidence",
                detail: "Listening locally"
            )
        )

        XCTAssertEqual(presentation.stage(.inboundPeers).state, .active)
        XCTAssertEqual(presentation.stage(.internetBoundary).state, .waiting)
        XCTAssertFalse(presentation.inboundEvidence)
        XCTAssertEqual(presentation.routerTasks[1].state, .manual)
    }

    func testNetworkIdentifiersAndPortsRemainPrivacyClassified() {
        let presentation = makePresentation(
            snapshot: NodeSnapshot(isRunning: true, peers: 1),
            assessment: NetworkReadinessAssessment(
                state: .waitingForEvidence,
                title: "Waiting",
                detail: "Waiting"
            )
        )

        XCTAssertEqual(presentation.stage(.listeners).privacyField, .networkPort)
        XCTAssertEqual(presentation.stage(.gateway).privacyField, .networkIdentifier)
        XCTAssertEqual(presentation.stage(.inboundPeers).privacyField, .networkActivity)
    }

    func testInboundSetupKeepsRouterManualUntilTrafficIsObserved() {
        let presentation = makePresentation(
            snapshot: NodeSnapshot(isRunning: true, peers: 248),
            assessment: NetworkReadinessAssessment(
                state: .waitingForEvidence,
                title: "Waiting",
                detail: "Waiting"
            )
        )

        XCTAssertEqual(
            InboundSetupPresentation.steps(from: presentation).map(\.state),
            [.verified, .verified, .manual, .waiting]
        )
        XCTAssertEqual(InboundSetupPresentation.recommendedEntryStep(from: presentation), .router)
    }

    func testInboundSetupDoesNotTreatFirewallConfigurationAsInboundProof() {
        let firewall = ManagedFirewallStatus(
            globalEnabled: true,
            blockAllEnabled: false,
            stealthEnabled: true,
            nodeRule: .missing,
            managedByQuilNode: false
        )
        let presentation = makePresentation(
            snapshot: NodeSnapshot(isRunning: true, peers: 248),
            assessment: NetworkReadinessAssessment(
                state: .waitingForEvidence,
                title: "Waiting",
                detail: "Waiting"
            ),
            firewall: firewall
        )

        let steps = InboundSetupPresentation.steps(from: presentation)
        XCTAssertEqual(steps[1].state, .needsAction)
        XCTAssertEqual(steps[2].state, .manual)
        XCTAssertEqual(steps[3].state, .waiting)
        XCTAssertEqual(InboundSetupPresentation.recommendedEntryStep(from: presentation), .firewall)
    }

    func testInboundSetupCompletesOnlyAfterLocalInboundEvidence() {
        let presentation = makePresentation(
            snapshot: NodeSnapshot(
                isRunning: true,
                peers: 248,
                inboundConnectionsEstablished: 1
            ),
            assessment: NetworkReadinessAssessment(
                state: .inboundVerified,
                title: "Verified",
                detail: "Observed locally"
            )
        )

        XCTAssertEqual(
            InboundSetupPresentation.steps(from: presentation).map(\.state),
            [.verified, .verified, .verified, .verified]
        )
        XCTAssertEqual(InboundSetupPresentation.recommendedEntryStep(from: presentation), .inboundProof)
    }

    private func makePresentation(
        snapshot: NodeSnapshot,
        assessment: NetworkReadinessAssessment,
        firewall: ManagedFirewallStatus? = nil
    ) -> NetworkWorkspacePresentation {
        let inspection = NetworkLocalInspection(
            localIPv4: "192.168.1.49",
            gatewayIPv4: "192.168.1.1",
            interfaceName: "en0",
            interfaceDisplayName: "Wi-Fi",
            firewallState: .enabled,
            tcpListeners: [8_336, 8_340],
            inspectionSucceeded: true
        )
        let gateway = GatewayRouteClassifier.assess(inspection)
        let access = RouterAccessDiscovery(
            routeSignature: gateway.signature,
            status: .confirmed,
            browserURL: URL(string: "http://192.168.1.1/"),
            checkedAt: Date(),
            title: "Gateway web service responded",
            detail: "Observed locally"
        )
        let resolvedFirewall =
            firewall
            ?? ManagedFirewallStatus(
                globalEnabled: true,
                blockAllEnabled: false,
                stealthEnabled: true,
                nodeRule: .allowed,
                managedByQuilNode: true
            )

        return .make(
            snapshot: snapshot,
            assessment: assessment,
            inspection: inspection,
            gateway: gateway,
            routerAccess: access,
            firewall: resolvedFirewall,
            portPlan: .residentialTCP(localWorkerCount: 8)
        )
    }
}
