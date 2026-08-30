import AppKit
import Foundation
import SwiftUI

enum DashboardDestination: String, CaseIterable, Identifiable {
    case overview
    case activity
    case network
    case identity
    case recovery
    case updates
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .activity: "Activity"
        case .network: "Network"
        case .identity: "Identity"
        case .recovery: "Recovery"
        case .updates: "Updates"
        case .diagnostics: "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .activity: "waveform.path.ecg"
        case .network: "network"
        case .identity: "person.text.rectangle.fill"
        case .recovery: "externaldrive.badge.checkmark"
        case .updates: "arrow.triangle.2.circlepath"
        case .diagnostics: "wrench.and.screwdriver.fill"
        }
    }

    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .overview: "1"
        case .activity: "2"
        case .network: "3"
        case .identity: "4"
        case .recovery: "5"
        case .updates: "6"
        case .diagnostics: "7"
        }
    }

    /// Only live-observation workspaces wait for the first complete node
    /// sample. Recovery, updates, and diagnostics must remain reachable while
    /// startup telemetry is still arriving because they are remediation paths.
    var waitsForInitialTelemetry: Bool {
        switch self {
        case .activity, .network, .identity: true
        case .overview, .recovery, .updates, .diagnostics: false
        }
    }
}

enum DashboardCommand: Equatable {
    case select(DashboardDestination)
    case refresh
    case toggleSidebar
}

struct DashboardCommandRequest: Equatable, Identifiable {
    let id = UUID()
    let command: DashboardCommand
}

/// A scene-independent command bus for macOS menu commands. Keeping this out of
/// individual windows means menu actions also work when the dashboard is closed:
/// opening a window publishes the latest request to the newly created scene.
@MainActor
final class DashboardCommandCenter: ObservableObject {
    @Published private(set) var latestRequest: DashboardCommandRequest?

    func send(_ command: DashboardCommand) {
        latestRequest = DashboardCommandRequest(command: command)
    }
}

/// Gives app-wide entry points (menus, Dock activation, and MenuBarExtra) one
/// consistent way to reveal the dashboard. SwiftUI's `openWindow` always makes
/// a new scene, so using it unconditionally for navigation commands quietly
/// accumulates duplicate dashboard windows.
@MainActor
enum DashboardWindowPresenter {
    static let windowTitle = "QuilNode Dashboard"

    static func present(using openWindow: OpenWindowAction) {
        if let dashboard = NSApp.windows.first(where: isDashboardWindow) {
            if dashboard.isMiniaturized {
                dashboard.deminiaturize(nil)
            }
            dashboard.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "dashboard")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func isDashboardWindow(_ window: NSWindow) -> Bool {
        window.title == windowTitle && window.canBecomeMain
    }
}

struct QuilNodeCommands: Commands {
    @ObservedObject var commandCenter: DashboardCommandCenter
    @ObservedObject var privacyMode: PrivacyModeController
    @ObservedObject var themeController: ThemeController
    @ObservedObject var appUpdates: AppUpdateController

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for QuilNode Updates…", systemImage: "arrow.down.app") {
                appUpdates.checkNow()
            }
            .disabled(!appUpdates.canCheck || appUpdates.phase == .checking)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Dashboard Window", systemImage: "rectangle.badge.plus") {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(after: .toolbar) {
            Button("Refresh Node Status", systemImage: "arrow.clockwise") {
                send(.refresh)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Toggle Sidebar", systemImage: "sidebar.leading") {
                send(.toggleSidebar)
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Toggle("Privacy Mode", isOn: $privacyMode.isEnabled)
                .keyboardShortcut("p", modifiers: [.command, .shift])

            Menu("Appearance") {
                ForEach(ThemeAppearancePreference.allCases) { preference in
                    Button {
                        themeController.appearancePreference = preference
                    } label: {
                        if themeController.appearancePreference == preference {
                            Label(preference.label, systemImage: "checkmark")
                        } else {
                            Text(preference.label)
                        }
                    }
                }
            }
        }

        CommandMenu("Node") {
            ForEach(DashboardDestination.allCases) { destination in
                Button(destination.title, systemImage: destination.systemImage) {
                    send(.select(destination))
                }
                .keyboardShortcut(destination.keyboardShortcut, modifiers: .command)
            }

            Divider()

            Button("Open Node Update Center…", systemImage: "arrow.triangle.2.circlepath") {
                send(.select(.updates))
            }
        }

        CommandGroup(replacing: .help) {
            Button("QuilNode Diagnostics", systemImage: "stethoscope") {
                send(.select(.diagnostics))
            }

            Divider()

            Button("Quilibrium Node Documentation", systemImage: "book.closed") {
                guard let url = URL(string: "https://docs.quilibrium.com/docs/run-node/") else { return }
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func send(_ command: DashboardCommand) {
        DashboardWindowPresenter.present(using: openWindow)
        commandCenter.send(command)
    }
}
