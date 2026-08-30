import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
private final class QuilNodeAppDelegate: NSObject, NSApplicationDelegate {
    private var quitInterlockPresenter: ApplicationQuitInterlockPresenter?

    #if DEBUG
        private var designPreviewWindow: NSWindow?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        ApplicationIcon.installForCurrentProcess()
        #if DEBUG
            presentStandaloneDesignPreviewIfRequested()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UpdateActivityGuard.shared.isInstalling else { return .terminateNow }
        guard quitInterlockPresenter == nil else { return .terminateLater }

        let presenter = ApplicationQuitInterlockPresenter()
        quitInterlockPresenter = presenter
        presenter.present { [weak self, weak sender] shouldQuit in
            self?.quitInterlockPresenter = nil
            sender?.reply(toApplicationShouldTerminate: shouldQuit)
        }
        return .terminateLater
    }

    #if DEBUG
        /// SwiftUI intentionally restores a previously closed WindowGroup as
        /// closed. Visual-regression launches need a deterministic window, so
        /// preview-only modes use an isolated hosting window and never start
        /// production coordinators.
        private func presentStandaloneDesignPreviewIfRequested() {
            let value = ProcessInfo.processInfo.arguments.first {
                $0.hasPrefix("--design-preview=network-inbound-")
                    || $0.hasPrefix("--design-preview=identity-transaction-")
                    || $0.hasPrefix("--design-preview=operator-interlock-")
            }
            guard let value else { return }

            let mode = String(value.dropFirst("--design-preview=".count))
            let content = standaloneDesignPreview(mode: mode)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 730),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "QuilNode Design Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: content)
            window.center()
            window.makeKeyAndOrderFront(nil)
            designPreviewWindow = window
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                for candidate in NSApp.windows where candidate !== window {
                    candidate.orderOut(nil)
                }
                window.makeKeyAndOrderFront(nil)
                self.designPreviewWindow = window
            }
        }

        @ViewBuilder
        private func standaloneDesignPreview(mode: String) -> some View {
            if mode.hasPrefix("operator-interlock-") {
                let previewMode: OperatorInterlockPreviewMode =
                    switch mode {
                    case "operator-interlock-firewall": .firewall
                    case "operator-interlock-updates": .updates
                    case "operator-interlock-quit": .quit
                    default: .restart
                    }
                OperatorInterlockDesignPreviewHost(mode: previewMode)
                    .quilThemed(.quilNode)
            } else if mode.hasPrefix("identity-transaction-") {
                let previewMode: IdentityTransactionPreviewMode =
                    switch mode {
                    case "identity-transaction-create": .create
                    case "identity-transaction-activate": .activate
                    case "identity-transaction-recovery": .importRecoveryOnly
                    default: .importKeyset
                    }
                IdentityTransactionDesignPreviewHost(
                    mode: previewMode,
                    privacyEnabled: mode == "identity-transaction-private"
                )
                .quilThemed(.quilNode)
            } else {
                let initialStep: InboundSetupStep =
                    switch mode {
                    case "network-inbound-firewall": .firewall
                    case "network-inbound-router": .router
                    case "network-inbound-proof": .inboundProof
                    default: .listenerProfile
                    }
                InboundSetupDesignPreviewHost(
                    initialStep: initialStep,
                    privacyEnabled: mode == "network-inbound-private",
                    profileKind: mode == "network-inbound-custom" ? .custom : .recommendedResidential
                )
                .quilThemed(.quilNode)
            }
        }
    #endif
}

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
