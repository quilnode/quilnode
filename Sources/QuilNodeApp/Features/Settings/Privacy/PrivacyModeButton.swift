import SwiftUI

struct PrivacyModeButton: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @Binding var isEnabled: Bool
    var compact = false
    var fillsWidth = false
    var controlHeight: CGFloat = 30
    var embedded = false

    var body: some View {
        Button {
            isEnabled.toggle()
        } label: {
            HStack(spacing: compact ? 0 : 10) {
                Image(systemName: isEnabled ? "eye.slash.fill" : "eye")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: compact ? 40 : 24)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(motion.symbol, value: isEnabled)
                if !compact {
                    Text("Privacy")
                        .foregroundStyle(theme.colors.primaryText)
                    Spacer(minLength: 4)
                    Text(isEnabled ? "Hidden" : "Visible")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isEnabled ? theme.colors.privacy : theme.colors.secondaryText)
                    Circle()
                        .fill(isEnabled ? theme.colors.privacy : theme.colors.secondaryText.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                isEnabled
                    ? (embedded ? theme.colors.privacy : Color.white)
                    : theme.colors.primaryText.opacity(0.78)
            )
            .padding(.horizontal, compact ? 0 : 9)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: fillsWidth ? .leading : .center)
            .frame(width: compact && !fillsWidth ? controlHeight : nil, height: controlHeight)
            .background {
                if !embedded {
                    RoundedRectangle(
                        cornerRadius: fillsWidth ? theme.metrics.controlCornerRadius : controlHeight / 2,
                        style: .continuous
                    )
                    .fill(isEnabled ? theme.colors.privacy : theme.colors.surfaceElevated)
                } else if compact && isEnabled {
                    Circle().fill(theme.colors.privacy.opacity(0.16)).padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .accessibilityLabel("Privacy Mode")
        .accessibilityValue(isEnabled ? "On, sensitive values hidden" : "Off, sensitive values visible")
        .accessibilityHint(
            isEnabled
                ? "Shows sensitive local and operational values"
                : "Masks sensitive local and operational values throughout QuilNode"
        )
        .accessibilityIdentifier("quilnode-privacy-mode-button")
        .help(isEnabled ? "Show sensitive local values" : "Mask sensitive local values throughout QuilNode")
    }
}
