import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A local-evidence map of the complete inbound path. This surface never
/// claims that a router rule exists from configuration alone: only an inbound
/// connection observed by the node or macOS closes the Internet boundary.
struct NetworkReadinessView: View {
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass
    @EnvironmentObject var monitor: NodeMonitor
    @EnvironmentObject var network: NetworkReadinessCoordinator

    @State var inboundSetupStep: InboundSetupStep?
    @State private var selectedStage: NetworkStageKind = .gateway

    var compactLayout = false

    private var presentation: NetworkWorkspacePresentation {
        .make(
            snapshot: monitor.snapshot,
            assessment: network.assessment,
            inspection: network.inspection,
            gateway: network.gatewayRoute,
            routerAccess: network.routerAccess,
            firewall: network.firewall,
            portPlan: network.portPlan
        )
    }

    var body: some View {
        Group {
            if compactLayout || !dashboardLayoutClass.isWide {
                VStack(alignment: .leading, spacing: 12) {
                    workspace
                    inspector
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    workspace
                        .frame(maxWidth: .infinity)
                    inspector
                        .frame(width: 300)
                }
            }
        }
        .sheet(item: $inboundSetupStep) { initialStep in
            InboundSetupAssistantView(initialStep: initialStep)
        }
        .onChange(of: presentation.stages.map(\.kind)) { _, kinds in
            if !kinds.contains(selectedStage) {
                selectedStage = .gateway
            }
        }
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetworkReadinessHeader(
                presentation: presentation,
                isRefreshing: network.isRefreshing,
                refresh: { Task { await network.refresh(forceRouterProbe: true) } },
                customizePorts: showPortEditor,
                copyPlan: copyPlan
            )

            NetworkReadinessPathView(
                stages: presentation.stages,
                selectedStage: $selectedStage
            )

            NetworkEvidenceLedger(
                stages: presentation.stages,
                selectedStage: $selectedStage,
                refresh: { Task { await network.refresh(forceRouterProbe: true) } }
            )

            NetworkRouterTaskView(
                tasks: presentation.routerTasks,
                profileTitle: network.activePortProfile.title,
                customizePorts: showPortEditor
            )
        }
    }

    private var inspector: some View {
        NetworkStageInspector(
            presentation: presentation,
            selectedStage: selectedStage,
            isConfiguringFirewall: network.isConfiguringFirewall,
            firewallError: network.firewallError,
            openGateway: openRouter,
            copyValue: copy,
            customizePorts: showPortEditor,
            configureFirewall: performFirewallAction,
            openFirewallSettings: openFirewallSettings
        )
    }

    private func showPortEditor() {
        network.clearPortProfileError()
        inboundSetupStep = .listenerProfile
    }
}
