import SwiftUI

struct MenuBarSectionSurface<Content: View>: View {
    @Environment(\.quilTheme) private var theme

    var tint: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (tint ?? theme.colors.surfaceElevated).opacity(tint == nil ? 0.68 : 0.10),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        (tint ?? theme.colors.border).opacity(tint == nil ? 0.50 : 0.22),
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
            }
    }
}

struct MenuBarValue: View {
    @Environment(\.quilTheme) private var theme

    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    var privacyField: PrivacyField? = nil

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MenuBarStatusChip<Content: View>: View {
    @Environment(\.quilTheme) private var theme

    let systemImage: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .accessibilityHidden(true)
            content()
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 0.5))
    }
}

struct MenuBarQuickAction: View {
    let title: String
    let systemImage: String
    var tint: Color? = nil
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(tint ?? .primary)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }
}

struct MenuBarResourceRow: View {
    @Environment(\.quilTheme) private var theme

    let cpu: String
    let memory: String

    var body: some View {
        HStack(spacing: 8) {
            Label("Node resources", systemImage: "gauge.with.dots.needle.50percent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.secondaryText)

            Spacer()

            Text("CPU")
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: cpu, field: .hardwareProfile)
                .monospacedDigit()
            Text("· MEM")
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: memory, field: .hardwareProfile)
                .monospacedDigit()
        }
        .font(.caption2.weight(.medium))
        .accessibilityElement(children: .combine)
    }
}
