import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DashboardView: View {
    @EnvironmentObject var monitor: NodeMonitor
    @EnvironmentObject var services: NodeServices
    @EnvironmentObject var lifecycle: NodeLifecycleController
    @EnvironmentObject var history: NodeHistoryStore
    @EnvironmentObject var releaseChecker: ReleaseChecker
    @EnvironmentObject var privacyMode: PrivacyModeController
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var installationCoordinator: InstallationCoordinator
    @EnvironmentObject var networkReadiness: NetworkReadinessCoordinator
    @EnvironmentObject var commandCenter: DashboardCommandCenter
    @EnvironmentObject var milestoneVisibility: ProtocolMilestoneVisibilityStore
    @EnvironmentObject var appUpdates: AppUpdateController
    @Environment(\.quilTheme) var theme
    @Environment(\.quilMotion) var motion
    @State var diagnosticsExpanded = false
    @State var allocationsExpanded = false
    @State var historyRange: HistoryRange = .sixHours
    @State var pendingUpdatePolicy: NodeUpdatePolicy?
    @State var buildLogExpanded = false
    @State var destination: DashboardDestination = .overview
    @AppStorage("dashboardSidebarCollapsed") var sidebarCollapsed = false

    var privacyModeEnabled: Bool { privacyMode.isEnabled }

    var cpuUsage: CPUUsagePresentation {
        CPUUsagePresentation(snapshot: monitor.snapshot)
    }

    var nodeObservation: NodeObservationPresentation {
        NodeObservationPresentation(
            phase: monitor.observationPhase,
            snapshot: monitor.snapshot
        )
    }

    var sidebarWidth: CGFloat {
        sidebarCollapsed ? theme.metrics.sidebarCollapsedWidth : theme.metrics.sidebarExpandedWidth
    }

    var body: some View {
        VStack(spacing: 0) {
            ThemedWindowChrome(
                sidebarWidth: sidebarWidth,
                title: destination.title,
                systemImage: destination.systemImage,
                index: destinationIndex
            ) {
                headerActions
            }
            HStack(spacing: 0) {
                DashboardSidebar(
                    destination: $destination,
                    isCollapsed: $sidebarCollapsed,
                    snapshot: monitor.snapshot,
                    observationPhase: monitor.observationPhase,
                    onSelectDestination: handleDestinationSelection
                )
                Divider()
                VStack(spacing: 0) {
                    ZStack {
                        ThemeCanvasBackground()
                            .ignoresSafeArea()
                        ScrollView {
                            VStack(alignment: .leading, spacing: theme.metrics.panelGap * theme.metrics.spacingScale) {
                                destinationContent
                            }
                            .padding(.horizontal, destination == .overview ? 0 : theme.metrics.panelPadding + 8)
                            .padding(.top, destination == .overview ? 0 : theme.metrics.panelPadding + 4)
                            .padding(.bottom, destination == .overview ? 0 : theme.metrics.panelPadding + 12)
                        }
                    }
                    DashboardStatusFooter(
                        snapshot: monitor.snapshot,
                        observationPhase: monitor.observationPhase,
                        onOpenDiagnostics: { destination = .diagnostics }
                    )
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .redacted(reason: privacyModeEnabled ? .privacy : [])
        .onReceive(commandCenter.$latestRequest.compactMap { $0 }) { request in
            handleCommand(request.command)
        }
        .sheet(
            isPresented: Binding(
                get: {
                    guard installationCoordinator.preflight != nil else { return false }
                    return installationCoordinator.requiresFirstInstall
                        || installationCoordinator.requiresPlatformAuthorization
                        || installationCoordinator.requiresQClientSetup
                        || !walletManager.onboardingCompleted
                        || (installationCoordinator.didCompleteInstallationThisRun
                            && networkReadiness.shouldPresentInitialGuide)
                },
                set: { presented in
                    if !presented,
                        !installationCoordinator.requiresFirstInstall,
                        walletManager.inventory.activeKeyset != nil
                    {
                        walletManager.dismissOnboarding()
                    }
                }
            )
        ) {
            if installationCoordinator.requiresFirstInstall {
                FirstInstallView()
                    .environmentObject(installationCoordinator)
                    .quilThemed(theme)
                    .interactiveDismissDisabled()
            } else if installationCoordinator.requiresPlatformAuthorization {
                PlatformAuthorizationView()
                    .environmentObject(installationCoordinator)
                    .quilThemed(theme)
                    .interactiveDismissDisabled()
            } else if installationCoordinator.requiresQClientSetup {
                QClientSetupView()
                    .environmentObject(installationCoordinator)
                    .quilThemed(theme)
                    .interactiveDismissDisabled()
            } else if !walletManager.onboardingCompleted {
                WalletOnboardingView()
                    .environmentObject(walletManager)
                    .quilThemed(theme)
            } else {
                NetworkOnboardingView()
                    .environmentObject(networkReadiness)
                    .quilThemed(theme)
                    .interactiveDismissDisabled()
            }
        }
    }

    func handleDestinationSelection(_ selectedDestination: DashboardDestination) {
        guard selectedDestination == .updates else { return }
        // Navigation is not an instruction to repeat expensive network work.
        // Fresh cached results render immediately; explicit checks remain in
        // the operator's control through the Update Center button.
        releaseChecker.requestCheckIfStale()
    }

    private func handleCommand(_ command: DashboardCommand) {
        switch command {
        case .select(let selectedDestination):
            destination = selectedDestination
            handleDestinationSelection(selectedDestination)
        case .refresh:
            Task {
                await monitor.refresh(forceNodeInfo: true)
                await lifecycle.refreshServiceStatus()
            }
        case .toggleSidebar:
            withAnimation(motion.sidebar) {
                sidebarCollapsed.toggle()
            }
        }
    }

}
