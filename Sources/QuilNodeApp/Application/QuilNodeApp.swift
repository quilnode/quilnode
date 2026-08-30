import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@main
struct QuilNodeApp: App {
    @NSApplicationDelegateAdaptor(QuilNodeAppDelegate.self) private var appDelegate
    @StateObject private var monitor: NodeMonitor
    @StateObject private var services: NodeServices
    @StateObject private var lifecycle: NodeLifecycleController
    @StateObject private var history: NodeHistoryStore
    @StateObject private var releaseChecker: ReleaseChecker
    @StateObject private var privacyMode: PrivacyModeController
    @StateObject private var themeController: ThemeController
    @StateObject private var walletManager: WalletManager
    @StateObject private var installationCoordinator: InstallationCoordinator
    @StateObject private var networkReadiness: NetworkReadinessCoordinator
    @StateObject private var commandCenter: DashboardCommandCenter
    @StateObject private var milestoneVisibility: ProtocolMilestoneVisibilityStore
    @StateObject private var appUpdates: AppUpdateController
    private let designPreviewMode: String?

    @MainActor
    init() {
        #if DEBUG
            designPreviewMode = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--design-preview=") }
                .map { String($0.dropFirst("--design-preview=".count)) }
        #else
            designPreviewMode = nil
        #endif

        LegacyPreferencesMigrator.migrateIfNeeded()
        let monitor = NodeMonitor()
        let services = NodeServices()
        let lifecycle = NodeLifecycleController()
        let history = NodeHistoryStore()
        let releaseChecker = ReleaseChecker()
        let walletManager = WalletManager()
        let installationCoordinator = InstallationCoordinator()
        let networkReadiness = NetworkReadinessCoordinator()
        let commandCenter = DashboardCommandCenter()
        let milestoneVisibility = ProtocolMilestoneVisibilityStore()
        let appUpdates = AppUpdateController()
        _monitor = StateObject(wrappedValue: monitor)
        _services = StateObject(wrappedValue: services)
        _lifecycle = StateObject(wrappedValue: lifecycle)
        _history = StateObject(wrappedValue: history)
        _releaseChecker = StateObject(wrappedValue: releaseChecker)
        _privacyMode = StateObject(wrappedValue: PrivacyModeController())
        _themeController = StateObject(wrappedValue: ThemeController())
        _walletManager = StateObject(wrappedValue: walletManager)
        _installationCoordinator = StateObject(wrappedValue: installationCoordinator)
        _networkReadiness = StateObject(wrappedValue: networkReadiness)
        _commandCenter = StateObject(wrappedValue: commandCenter)
        _milestoneVisibility = StateObject(wrappedValue: milestoneVisibility)
        _appUpdates = StateObject(wrappedValue: appUpdates)

        // Scene content is lazy on macOS: after a user closes every dashboard
        // window, neither WindowGroup nor the menu popover necessarily exists.
        // Boot the idempotent coordinators from the App lifetime itself so
        // monitoring and protocol alerts truly survive closed windows.
        if designPreviewMode == nil {
            Task { @MainActor in
                monitor.start()
                await services.start(monitor: monitor, history: history)
                await lifecycle.refreshServiceStatus()
                releaseChecker.start(monitor: monitor, services: services)
                walletManager.start()
                installationCoordinator.start()
                networkReadiness.start(monitor: monitor)
            }
        }
    }

    var body: some Scene {
        WindowGroup("QuilNode Dashboard", id: "dashboard") {
            primarySceneContent
        }
        .defaultSize(width: 980, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            QuilNodeCommands(
                commandCenter: commandCenter,
                privacyMode: privacyMode,
                themeController: themeController,
                appUpdates: appUpdates
            )
        }

        Settings {
            QuilNodeSettingsView()
                .environmentObject(privacyMode)
                .environmentObject(themeController)
                .environmentObject(networkReadiness)
                .environmentObject(commandCenter)
                .environmentObject(appUpdates)
                .quilThemed(themeController.selectedTheme)
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(monitor)
                .environmentObject(services)
                .environmentObject(lifecycle)
                .environmentObject(history)
                .environmentObject(releaseChecker)
                .environmentObject(privacyMode)
                .environmentObject(themeController)
                .environmentObject(walletManager)
                .environmentObject(installationCoordinator)
                .environmentObject(networkReadiness)
                .environmentObject(commandCenter)
                .environmentObject(appUpdates)
                .quilThemed(themeController.selectedTheme)
                .task {
                    guard designPreviewMode == nil else { return }
                    monitor.start()
                    await services.start(monitor: monitor, history: history)
                    await lifecycle.refreshServiceStatus()
                    releaseChecker.start(monitor: monitor, services: services)
                    walletManager.start()
                    installationCoordinator.start()
                    networkReadiness.start(monitor: monitor)
                }
        } label: {
            HStack(spacing: 2.5) {
                MenuBarBrandMark(size: 15)
                Circle()
                    .fill(menuBarStatusTint)
                    .frame(width: 4.5, height: 4.5)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(menuBarAccessibilityStatus)
            .task {
                guard designPreviewMode == nil else { return }
                // The menu-bar label exists even when every dashboard window
                // is closed and the popover has never been opened. Starting
                // coordinators here keeps monitoring and metadata alerts alive
                // for the full app lifetime; each coordinator is idempotent.
                monitor.start()
                await services.start(monitor: monitor, history: history)
                await lifecycle.refreshServiceStatus()
                releaseChecker.start(monitor: monitor, services: services)
                walletManager.start()
                installationCoordinator.start()
            }
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var primarySceneContent: some View {
        #if DEBUG
            if designPreviewMode == "onboarding-identity" {
                OnboardingDesignPreviewHost()
                    .frame(minWidth: 900, minHeight: 680)
            } else if designPreviewMode == "menu-bar" {
                MenuBarDesignPreviewHost(privacyEnabled: false)
            } else if designPreviewMode == "menu-bar-private" {
                MenuBarDesignPreviewHost(privacyEnabled: true)
            } else if designPreviewMode == "network-inbound-setup" {
                InboundSetupDesignPreviewHost(initialStep: .listenerProfile)
            } else if designPreviewMode == "network-inbound-firewall" {
                InboundSetupDesignPreviewHost(initialStep: .firewall)
            } else if designPreviewMode == "network-inbound-router" {
                InboundSetupDesignPreviewHost(initialStep: .router)
            } else if designPreviewMode == "network-inbound-proof" {
                InboundSetupDesignPreviewHost(initialStep: .inboundProof)
            } else if designPreviewMode == "network-inbound-private" {
                InboundSetupDesignPreviewHost(initialStep: .listenerProfile, privacyEnabled: true)
            } else if designPreviewMode == "network-inbound-custom" {
                InboundSetupDesignPreviewHost(initialStep: .listenerProfile, profileKind: .custom)
            } else if designPreviewMode == "identity-transaction-import" {
                IdentityTransactionDesignPreviewHost(mode: .importKeyset)
            } else if designPreviewMode == "identity-transaction-recovery" {
                IdentityTransactionDesignPreviewHost(mode: .importRecoveryOnly)
            } else if designPreviewMode == "identity-transaction-create" {
                IdentityTransactionDesignPreviewHost(mode: .create)
            } else if designPreviewMode == "identity-transaction-activate" {
                IdentityTransactionDesignPreviewHost(mode: .activate)
            } else if designPreviewMode == "identity-transaction-private" {
                IdentityTransactionDesignPreviewHost(mode: .importKeyset, privacyEnabled: true)
            } else if designPreviewMode == "operator-interlock-restart" {
                OperatorInterlockDesignPreviewHost(mode: .restart)
            } else if designPreviewMode == "operator-interlock-firewall" {
                OperatorInterlockDesignPreviewHost(mode: .firewall)
            } else if designPreviewMode == "operator-interlock-updates" {
                OperatorInterlockDesignPreviewHost(mode: .updates)
            } else if designPreviewMode == "operator-interlock-quit" {
                OperatorInterlockDesignPreviewHost(mode: .quit)
            } else if designPreviewMode == "theme-library" {
                ThemeLibraryDesignPreviewHost()
            } else if designPreviewMode == "build-evidence" {
                BuildEvidenceDesignPreviewHost()
                    .quilThemed(.quilNode)
            } else {
                dashboardSceneContent
            }
        #else
            dashboardSceneContent
        #endif
    }

    private var dashboardSceneContent: some View {
        DashboardView()
            .environmentObject(monitor)
            .environmentObject(services)
            .environmentObject(lifecycle)
            .environmentObject(history)
            .environmentObject(releaseChecker)
            .environmentObject(privacyMode)
            .environmentObject(themeController)
            .environmentObject(walletManager)
            .environmentObject(installationCoordinator)
            .environmentObject(networkReadiness)
            .environmentObject(commandCenter)
            .environmentObject(milestoneVisibility)
            .environmentObject(appUpdates)
            .quilThemed(themeController.selectedTheme)
            .task {
                monitor.start()
                await services.start(monitor: monitor, history: history)
                await lifecycle.refreshServiceStatus()
                releaseChecker.start(monitor: monitor, services: services)
                walletManager.start()
                installationCoordinator.start()
                networkReadiness.start(monitor: monitor)
            }
            .frame(minWidth: 820, minHeight: 640)
    }

    private var menuBarStatusTint: Color {
        if monitor.observationPhase == .checkingProcess {
            return themeController.selectedTheme.colors.info
        }
        if monitor.observationPhase == .loadingTelemetry, monitor.snapshot.isRunning {
            return themeController.selectedTheme.colors.success
        }
        return themeController.selectedTheme.colors.health(monitor.snapshot.health)
    }

    private var menuBarAccessibilityStatus: String {
        let presentation = NodeObservationPresentation(
            phase: monitor.observationPhase,
            snapshot: monitor.snapshot
        )
        return "QuilNode: \(presentation.accessibilityStatus)"
    }
}
