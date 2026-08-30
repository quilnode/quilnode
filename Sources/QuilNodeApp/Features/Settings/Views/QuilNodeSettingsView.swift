import SwiftUI

/// Native app-wide preferences surfaced through QuilNode > Settings (⌘,).
///
/// Operational tasks stay in the dashboard where their context is visible.
/// The Settings window contains only durable preferences that affect the whole
/// app, grouped into stable macOS toolbar panes.
struct QuilNodeSettingsView: View {
    @AppStorage("settings.selectedPane") private var selectedPane = SettingsPane.appearance.rawValue

    var body: some View {
        TabView(selection: $selectedPane) {
            AppearanceSettingsPane()
                .tabItem {
                    Label(SettingsPane.appearance.title, systemImage: SettingsPane.appearance.systemImage)
                }
                .tag(SettingsPane.appearance.rawValue)

            PrivacySettingsPane()
                .tabItem {
                    Label(SettingsPane.privacy.title, systemImage: SettingsPane.privacy.systemImage)
                }
                .tag(SettingsPane.privacy.rawValue)

            AppUpdateSettingsPane()
                .tabItem {
                    Label(SettingsPane.updates.title, systemImage: SettingsPane.updates.systemImage)
                }
                .tag(SettingsPane.updates.rawValue)
        }
        .frame(width: 700, height: selectedSettingsPane.windowHeight)
        .accessibilityIdentifier("quilnode-settings-tabs")
    }

    private var selectedSettingsPane: SettingsPane {
        SettingsPane(rawValue: selectedPane) ?? .appearance
    }
}
