import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case appearance
    case privacy
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .privacy: "Privacy"
        case .updates: "App Updates"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: "paintpalette.fill"
        case .privacy: "eye.slash.fill"
        case .updates: "arrow.down.app.fill"
        }
    }

    var windowHeight: CGFloat {
        switch self {
        case .appearance: 510
        case .privacy: 520
        case .updates: 650
        }
    }
}

/// Shared geometry and hierarchy for settings panes. Pane content remains
/// feature-owned, while the window rhythm stays consistent across themes.
struct SettingsPaneContainer<Content: View>: View {
    @Environment(\.quilTheme) private var theme

    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16 * theme.metrics.spacingScale) {
                content()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}

struct SettingsCard<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlSurface(tint: tint)
    }
}

struct SettingsPreferenceRow<Accessory: View>: View {
    @Environment(\.quilTheme) private var theme

    let systemImage: String
    let title: String
    let detail: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.accent)
                .frame(width: 32, height: 32)
                .background(
                    theme.colors.selection.opacity(0.46),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)
            accessory()
        }
        .frame(minHeight: 48)
    }
}

struct SettingsDivider: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.48))
            .frame(height: max(theme.metrics.borderWidth, 0.5))
            .padding(.vertical, 12)
            .accessibilityHidden(true)
    }
}

struct SettingsCallout: View {
    @Environment(\.quilTheme) private var theme

    let systemImage: String
    let title: String
    let detail: String
    var tint: Color? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint ?? theme.colors.info)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (tint ?? theme.colors.info).opacity(0.08),
            in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .strokeBorder((tint ?? theme.colors.info).opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PrivacyScopeRow: View {
    @Environment(\.quilTheme) private var theme

    let systemImage: String
    let title: String
    let detail: String
    let stateTitle: String
    let stateSystemImage: String
    let stateTint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.privacy)
                .frame(width: 28, height: 28)
                .background(
                    theme.colors.privacy.opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Label(stateTitle, systemImage: stateSystemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(stateTint)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsSectionHeader: View {
    @Environment(\.quilTheme) private var theme

    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
            }
        }
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 2)
    }
}

struct SettingsFooterNote: View {
    @Environment(\.quilTheme) private var theme

    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
            .padding(.horizontal, 2)
            .accessibilityElement(children: .combine)
    }
}

struct SettingsValueLabel: View {
    @Environment(\.quilTheme) private var theme

    let text: String
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(tint ?? theme.colors.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (tint ?? theme.colors.selection).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .textSelection(.enabled)
    }
}

struct SettingsStatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityLabel(title)
    }
}
