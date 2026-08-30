import SwiftUI

struct AppearanceSettingsPane: View {
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.quilTheme) private var theme

    var body: some View {
        SettingsPaneContainer(
            title: "Appearance",
            subtitle: "Choose how QuilNode looks across the dashboard, menu bar, and settings.",
            systemImage: "paintpalette.fill"
        ) {
            SettingsCard {
                SettingsPreferenceRow(
                    systemImage: "paintpalette",
                    title: "Theme library",
                    detail: "Current family: \(theme.name)"
                ) {
                    ThemePickerButton(
                        compact: false,
                        controlHeight: 36,
                        popoverEdge: .trailing,
                        showChevron: true
                    )
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    systemImage: themeController.appearancePreference.systemImage,
                    title: "Appearance mode",
                    detail: appearanceDetail
                ) {
                    Picker("Appearance mode", selection: $themeController.appearancePreference) {
                        ForEach(ThemeAppearancePreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                    .accessibilityLabel("Appearance mode")
                }
            }

            SettingsCallout(
                systemImage: "circle.lefthalf.filled",
                title: "Each theme owns its light and dark design",
                detail:
                    "System follows the Mac automatically. Light and Dark select the corresponding variant from the current theme family—not a generic color filter.",
                tint: theme.colors.accentSecondary
            )
        }
    }

    private var appearanceDetail: String {
        switch themeController.appearancePreference {
        case .system: "Follow the current macOS appearance"
        case .light: "Always use this theme family’s light variant"
        case .dark: "Always use this theme family’s dark variant"
        }
    }
}
