import SwiftUI

struct OperatorInterlockRunway: View {
    @Environment(\.quilTheme) private var theme

    let steps: [OperatorInterlockStep]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    DashboardCircleIcon(systemImage: step.symbol, tint: step.tone.color(in: theme), size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title).font(.caption.weight(.semibold))
                        Text(step.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if index < steps.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.colors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.top, 11)
                }
            }
        }
        .padding(13)
        .controlSurface(tint: theme.colors.info)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action sequence")
    }
}

struct OperatorInterlockScopeLedger: View {
    @Environment(\.quilTheme) private var theme

    let changes: [OperatorInterlockScopeItem]
    let preserved: [OperatorInterlockScopeItem]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            scopeColumn("WILL CHANGE", items: changes, tint: theme.colors.info)
            Rectangle().fill(theme.colors.border.opacity(0.52)).frame(width: 1)
            scopeColumn("PRESERVED", items: preserved, tint: theme.colors.success)
        }
        .controlSurface(tint: theme.colors.accent)
    }

    private func scopeColumn(_ title: String, items: [OperatorInterlockScopeItem], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(tint)
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 19)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.caption.weight(.semibold))
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct OperatorInterlockDecisionCard: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    let decision: OperatorInterlockDecision
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    DashboardCircleIcon(systemImage: decision.symbol, tint: tint, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(decision.title).font(.caption.weight(.semibold))
                        Text(decision.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? tint : theme.colors.secondaryText)
                }
                ForEach(decision.bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(tint.opacity(isSelected ? 0.11 : 0.035), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(isSelected ? 0.8 : 0.18), lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .animation(motion.selection, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tint: Color { decision.tone.color(in: theme) }
}

extension OperatorInterlockTone {
    func color(in theme: QuilTheme) -> Color {
        switch self {
        case .accent: theme.colors.accent
        case .success: theme.colors.success
        case .information: theme.colors.info
        case .warning: theme.colors.warning
        case .destructive: theme.colors.danger
        }
    }
}
