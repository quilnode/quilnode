import SwiftUI

/// A temporary, actionable protocol notice for the compact menu-bar surface.
/// Selection policy lives in `MenuBarMilestonePresentation`; this component
/// is intentionally presentation-only.
struct ProtocolMilestoneMenuCard: View {
    let notice: MenuBarMilestonePresentation
    let action: () -> Void

    @Environment(\.quilTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: notice.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(notice.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(notice.detail)
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Text(notice.timing)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.colors.secondaryText.opacity(0.62))
                    .accessibilityHidden(true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(tint.opacity(0.22), lineWidth: max(theme.metrics.borderWidth, 0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: tint, cornerRadius: 13)
        .accessibilityLabel("\(notice.title). \(notice.detail). \(notice.timing)")
        .accessibilityHint("Opens the protocol event in Activity")
    }

    private var tint: Color {
        switch notice.tone {
        case .information: theme.colors.info
        case .attention: theme.colors.warning
        case .danger: theme.colors.danger
        }
    }
}
