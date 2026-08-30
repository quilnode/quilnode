import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
private final class QuilNodeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ApplicationIcon.installForCurrentProcess()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UpdateActivityGuard.shared.isInstalling else { return .terminateNow }
        sender.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "An update is still running"
        alert.informativeText =
            "QuilNode can keep working with every dashboard window closed. Quitting now interrupts the build before activation; the currently installed node remains unchanged."
        alert.addButton(withTitle: "Keep Running")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
    }
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

    @MainActor
    init() {
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

    var body: some Scene {
        WindowGroup("QuilNode Dashboard", id: "dashboard") {
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
