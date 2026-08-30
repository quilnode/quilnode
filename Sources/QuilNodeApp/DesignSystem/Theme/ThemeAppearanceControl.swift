import SwiftUI

/// A sidebar-native mode control. Expanded sidebars expose all three choices;
/// the icon rail uses a menu so it stays centered without losing direct access.
struct ThemeAppearanceControl: View {
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    let compact: Bool
    var embedded = false

    var body: some View {
        if compact {
            Menu {
                ForEach(ThemeAppearancePreference.allCases) { preference in
                    Button {
                        themeController.appearancePreference = preference
                    } label: {
                        Label(preference.sidebarLabel, systemImage: preference.systemImage)
                    }
                }
            } label: {
                Image(systemName: themeController.appearancePreference.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.accent)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 40, height: 40)
            .background {
                if !embedded {
                    RoundedRectangle(cornerRadius: theme.metrics.navigationCornerRadius, style: .continuous)
                        .fill(theme.colors.surfaceElevated)
                }
            }
            .contentShape(Rectangle())
            .fixedSize()
            .help("Appearance: \(themeController.appearancePreference.sidebarLabel)")
            .accessibilityLabel("Theme appearance: \(themeController.appearancePreference.sidebarLabel)")
            .accessibilityIdentifier("quilnode-theme-appearance-menu")
        } else {
            HStack(spacing: 9) {
                Text("Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.primaryText)

                Spacer(minLength: 4)

                HStack(spacing: 2) {
                    ForEach(ThemeAppearancePreference.allCases) { preference in
                        Button {
                            themeController.appearancePreference = preference
                        } label: {
                            Image(systemName: preference.systemImage)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(
                                    themeController.appearancePreference == preference
                                        ? theme.colors.accent
                                        : theme.colors.secondaryText
                                )
                                .frame(width: 27, height: 26)
                                .background {
                                    if themeController.appearancePreference == preference {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(theme.colors.selection.opacity(0.72))
                                    }
                                }
                                .animation(motion.selection, value: themeController.appearancePreference)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .help(preference.helpText)
                        .accessibilityLabel(preference.helpText)
                        .accessibilityIdentifier("quilnode-theme-appearance-\(preference.rawValue)")
                    }
                }
                .padding(2)
                .background(
                    theme.colors.surface.opacity(0.48), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .padding(.horizontal, 9)
            .frame(height: 44)
            .background {
                if !embedded {
                    RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                        .fill(theme.colors.surfaceElevated.opacity(0.72))
                }
            }
        }
    }
}

extension ThemeAppearancePreference {
    var sidebarLabel: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var helpText: String {
        switch self {
        case .system: "Automatically follow the Mac appearance"
        case .light: "Use this theme's light mode"
        case .dark: "Use this theme's dark mode"
        }
    }
}
