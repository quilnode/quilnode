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
            Group {
                if compact {
                    privacyIcon.frame(width: 40)
                } else {
                    ViewThatFits(in: .horizontal) {
                        expandedLabel(showsState: true)
                        expandedLabel(showsState: false)
                    }
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

    private var privacyIcon: some View {
        Image(systemName: isEnabled ? "eye.slash.fill" : "eye")
            .font(.system(size: 12.5, weight: .semibold))
            .contentTransition(.symbolEffect(.replace))
            .animation(motion.symbol, value: isEnabled)
    }

    private func expandedLabel(showsState: Bool) -> some View {
        HStack(spacing: 8) {
            privacyIcon.frame(width: 20)
            Text("Privacy")
                .foregroundStyle(theme.colors.primaryText)
                .fixedSize()
            Spacer(minLength: 4)
            if showsState {
                Text(isEnabled ? "Hidden" : "Visible")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isEnabled ? theme.colors.privacy : theme.colors.secondaryText)
                    .fixedSize()
            }
            Circle()
                .fill(isEnabled ? theme.colors.privacy : theme.colors.secondaryText.opacity(0.5))
                .frame(width: 6, height: 6)
        }
    }
}
