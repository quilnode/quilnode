import SwiftUI

struct ProtocolStatusCheck: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(minHeight: 32)
            .background(theme.colors.surface.opacity(0.74))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(tint.opacity(0.36), lineWidth: max(theme.metrics.borderWidth, 0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct ProtocolMetricCell: View {
    @Environment(\.quilTheme) private var theme
    let descriptor: ProtocolMetricDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(descriptor.title.uppercased())
                .protocolLabelStyle(color: theme.colors.secondaryText)
            PrivacyProtectedText(value: descriptor.value, field: descriptor.privacyField)
                .font(
                    .system(
                        size: 20 * theme.typography.scale,
                        weight: .medium,
                        design: .monospaced
                    ).monospacedDigit()
                )
                .foregroundStyle(descriptor.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .quilLiveValueTransition(value: descriptor.value)
            Text(descriptor.detail)
                .font(.system(size: 10.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ProtocolMetricDescriptor: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let privacyField: PrivacyField?
}

extension View {
    func protocolLabelStyle(color: Color) -> some View {
        font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.25)
            .foregroundStyle(color)
    }
}
