import SwiftUI

struct RecoveryOperationSequence: View {
    @Environment(\.quilTheme) private var theme

    private let steps = [
        RecoveryOperationStep(
            number: 1, title: "Inspect", detail: "Validate the complete pair", symbol: "checkmark.shield"),
        RecoveryOperationStep(number: 2, title: "Snapshot", detail: "Create verified rollback", symbol: "camera.fill"),
        RecoveryOperationStep(
            number: 3, title: "Apply", detail: "Change only node identity", symbol: "shippingbox.fill"),
        RecoveryOperationStep(number: 4, title: "Validate", detail: "Confirm node startup", symbol: "checkmark.circle"),
        RecoveryOperationStep(
            number: 5, title: "Rollback", detail: "Restore if validation fails", symbol: "arrow.uturn.backward.circle"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Protected identity switch")
                    .font(.headline)
                Text("The running node is paused only while the complete identity pair changes.")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                Label("Stores preserved", systemImage: "internaldrive.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.success)
            }

            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.number) { index, step in
                    operationStep(step)
                    if index < steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.colors.secondaryText)
                            .frame(width: 22)
                    }
                }
            }
        }
        .padding(13)
        .controlSurface(tint: theme.colors.info)
        .accessibilityElement(children: .contain)
    }

    private func operationStep(_ step: RecoveryOperationStep) -> some View {
        HStack(spacing: 8) {
            Image(systemName: step.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.info)
                .frame(width: 28, height: 28)
                .background(theme.colors.info.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("\(step.number). \(step.title)")
                    .font(.caption.weight(.semibold))
                Text(step.detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecoveryOperationStep {
    let number: Int
    let title: String
    let detail: String
    let symbol: String
}
