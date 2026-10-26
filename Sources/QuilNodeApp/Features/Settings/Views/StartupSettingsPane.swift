import AppKit
import ServiceManagement
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// macOS owns login registration; the authenticated service owns boot policy.
/// Neither preference is inferred from a cached UserDefaults switch.
struct StartupSettingsPane: View {
    @Environment(\.quilTheme) private var theme
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var nodeEnabled: Bool?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        SettingsPaneContainer {
            SettingsSectionHeader(title: "Startup & background operation", trailing: "This Mac")
            SettingsCard {
                SettingsPreferenceRow(
                    systemImage: "person.crop.circle.badge.checkmark",
                    title: "Open QuilNode after login",
                    detail: "Open the dashboard and menu bar when you sign in to macOS after a restart."
                ) {
                    Toggle("Open after login", isOn: Binding(
                        get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                        set: setLoginEnabled
                    )).labelsHidden().toggleStyle(.switch)
                }
                if loginStatus == .requiresApproval {
                    Text("macOS is waiting for your approval in Login Items.")
                        .font(.callout).foregroundStyle(theme.colors.warning)
                    Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                }
                SettingsDivider()
                SettingsPreferenceRow(
                    systemImage: "power.circle.fill",
                    title: "Start node after a Mac restart",
                    detail: "Run the node at boot, before login, and restart it after an unexpected exit. QuilNode can stay closed. Changes apply at the next node start; the running node is untouched."
                ) {
                    if let nodeEnabled {
                        Toggle("Start node at boot", isOn: Binding(
                            get: { nodeEnabled }, set: { value in Task { await refreshNode(enabled: value) } }
                        )).labelsHidden().toggleStyle(.switch).disabled(busy)
                    } else if busy {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Unavailable").foregroundStyle(theme.colors.secondaryText)
                    }
                }
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(theme.colors.warning).textSelection(.enabled)
            }
            HStack {
                Button("Refresh startup status") {
                    loginStatus = SMAppService.mainApp.status
                    Task { await refreshNode() }
                }.disabled(busy)
                Spacer()
                Button("macOS Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            }
            SettingsFooterNote(
                systemImage: "info.circle",
                text: "Sleep pauses network work. A powered-off Mac cannot run the node. With FileVault, macOS must unlock the startup disk before system services can run."
            )
        }
        .task { await refreshNode() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
    }

    private func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = error.localizedDescription }
        loginStatus = SMAppService.mainApp.status
    }

    private func refreshNode(enabled: Bool? = nil) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let result = await Task.detached(priority: .userInitiated) {
            PrivilegedServiceClient.nodeStartupPolicy(enabled: enabled)
        }.value
        nodeEnabled = result.enabled
        error = result.error
    }
}
