import SwiftUI

struct IdentityTransactionPlanRail: View {
    @Environment(\.quilTheme) private var theme

    let stages: [IdentityTransactionStage]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                stageNode(stage, isReady: index == 0)
                if index < stages.count - 1 {
                    Capsule()
                        .fill(theme.colors.border.opacity(0.56))
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.top, 15)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Protected identity transaction plan")
    }

    private func stageNode(_ stage: IdentityTransactionStage, isReady: Bool) -> some View {
        let tint = isReady ? theme.colors.accent : theme.colors.secondaryText
        return VStack(spacing: 4) {
            ZStack {
                Circle().fill(tint.opacity(isReady ? 0.16 : 0.07))
                Circle().strokeBorder(tint.opacity(isReady ? 0.92 : 0.38), lineWidth: isReady ? 2 : 1)
                Text("\(stage.number)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(tint)
            }
            .frame(width: 31, height: 31)

            Text(stage.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isReady ? theme.colors.primaryText : theme.colors.secondaryText)
            Text(stage.detail)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: 84)
    }
}
