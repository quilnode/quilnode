import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct PortNumberField: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedTextField(title: title.capitalized, text: $text, field: .networkPort)
                .font(.body.monospacedDigit())
                .frame(width: 138)
        }
    }
}

struct PortProfileRuleRow: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let port: String
    let transport: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(theme.colors.accent)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            PrivacyProtectedText(value: port, field: .networkPort)
                .font(.subheadline.bold().monospacedDigit())
            Text(transport)
                .font(.caption.bold())
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 34, alignment: .leading)
        }
    }
}

struct VerificationRow: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PortVerificationRow: View {
    let requirement: NetworkPortRequirement
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "circle.dashed")
                .accessibilityHidden(true)
            Text("Waiting for")
            PrivacyProtectedText(value: requirement.portLabel, field: .networkPort)
                .monospacedDigit()
            Text("\(requirement.transport.rawValue) — \(requirement.title.lowercased())")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
