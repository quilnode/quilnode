#if DEBUG
    import SwiftUI

    #if canImport(QuilNodeCore)
        import QuilNodeCore
    #endif

    struct InboundSetupDesignPreviewHost: View {
        @StateObject private var monitor = NodeMonitor()
        @StateObject private var network = NetworkReadinessCoordinator()

        let initialStep: InboundSetupStep
        var privacyEnabled = false
        var profileKind: NetworkPortProfileKind = .recommendedResidential

        var body: some View {
            InboundSetupAssistantView(
                previewWorkspace: Self.workspace,
                initialStep: initialStep,
                profileKind: profileKind
            )
            .environmentObject(monitor)
            .environmentObject(network)
            .redacted(reason: privacyEnabled ? .privacy : [])
        }

        private static let workspace: NetworkWorkspacePresentation = {
            let snapshot = NodeSnapshot(
                isRunning: true,
                peers: 248,
                inboundConnectionsEstablished: 0,
                localWorkerCount: 8
            )
            let inspection = NetworkLocalInspection(
                localIPv4: "192.0.2.49",
                gatewayIPv4: "192.0.2.1",
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
                browserURL: URL(string: "https://192.0.2.1/"),
                checkedAt: Date(timeIntervalSince1970: 1_787_928_000),
                title: "Gateway web service responded",
                detail: "A local web service responds on the detected default gateway."
            )
            let firewall = ManagedFirewallStatus(
                globalEnabled: true,
                blockAllEnabled: false,
                stealthEnabled: true,
                nodeRule: .missing,
                managedByQuilNode: false
            )
            return .make(
                snapshot: snapshot,
                assessment: NetworkReadinessAssessment(
                    state: .waitingForEvidence,
                    title: "Waiting for inbound evidence",
                    detail: "Local listeners are ready; the external boundary is not proven."
                ),
                inspection: inspection,
                gateway: gateway,
                routerAccess: access,
                firewall: firewall,
                portPlan: .residentialTCP(localWorkerCount: 8)
            )
        }()
    }
#endif
