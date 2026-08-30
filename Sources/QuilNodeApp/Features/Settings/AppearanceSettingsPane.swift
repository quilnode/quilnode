import SwiftUI

struct AppearanceSettingsPane: View {
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.quilTheme) private var theme

    var body: some View {
        SettingsPaneContainer {
            SettingsCard {
                SettingsPreferenceRow(
                    systemImage: "paintpalette",
                    title: "Theme family",
                    detail: "Choose the visual system used throughout QuilNode."
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

            AppearanceLivePreview()

            SettingsCallout(
                systemImage: "circle.lefthalf.filled",
                title: "Variants belong to the theme",
                detail:
                    "System follows macOS automatically. Light and Dark select the matching design from this theme family, not a generic color filter.",
                tint: theme.colors.accentSecondary
            )

            SettingsFooterNote(
                systemImage: "sparkles",
                text: "Appearance changes apply immediately across the dashboard, menu bar, and settings."
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

private struct AppearanceLivePreview: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Live preview", systemImage: "eye.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Key surfaces and semantic states in the current theme.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 188, alignment: .leading)

                preview
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(index == 0 ? theme.colors.accent.opacity(0.78) : theme.colors.secondaryText.opacity(0.2))
                        .frame(width: index == 0 ? 45 : 30, height: 7)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 78, height: 112)
            .background(theme.colors.surfaceElevated)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ApplicationBrandMark(size: 22, theme: theme)
                    Text("QuilNode")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Circle().fill(theme.colors.success).frame(width: 7, height: 7)
                }
                Capsule().fill(theme.colors.primaryText.opacity(0.72)).frame(width: 94, height: 7)
                Capsule().fill(theme.colors.secondaryText.opacity(0.24)).frame(width: 150, height: 6)
                Capsule().fill(theme.colors.secondaryText.opacity(0.18)).frame(width: 118, height: 6)
                Spacer(minLength: 0)
                HStack {
                    SettingsStatusPill(title: "Local", tint: theme.colors.success)
                    Spacer()
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.colors.accent)
                        .frame(width: 56, height: 22)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(theme.colors.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.68), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the current \(theme.name) theme")
    }
}
