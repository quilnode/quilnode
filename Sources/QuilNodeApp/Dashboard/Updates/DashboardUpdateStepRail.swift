import SwiftUI

extension DashboardView {
    /// Shows every evidence-bearing workflow step without asking operators to
    /// infer how an 11-step counter maps onto the six high-level safety phases.
    /// The overview stays intentionally calm; this rail exposes the exact
    /// execution order in a compact, scannable form.
    func updateDetailedStepRail(_ progress: NodeUpdateProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Execution steps")
                    .font(.caption.weight(.semibold))
                Text(progress.step.title)
                    .font(.caption2)
                    .foregroundStyle(operationTint(progress))
                    .quilLiveValueTransition(value: progress.currentStepNumber)
                Spacer()
                Text("\(progress.currentStepNumber) of \(progress.orderedSteps.count)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(progress.orderedSteps.enumerated()), id: \.element.id) { index, step in
                    detailedStepMarker(step, index: index, progress: progress)
                        .frame(maxWidth: .infinity)
                }
            }
            .background(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                    .offset(y: 11)
            }
        }
        .padding(.vertical, 2)
    }

    private func detailedStepMarker(
        _ step: NodeUpdateStep,
        index: Int,
        progress: NodeUpdateProgress
    ) -> some View {
        let isComplete = progress.status == .succeeded || index < progress.currentStepNumber - 1
        let isCurrent = progress.status != .succeeded && index == progress.currentStepNumber - 1
        let isFailed = isCurrent && progress.status == .failed
        let tint =
            isFailed
            ? theme.colors.danger
            : (isComplete ? theme.colors.success : (isCurrent ? operationTint(progress) : Color.secondary))

        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface.opacity(0.98))
                    .frame(width: 23, height: 23)
                Circle()
                    .fill(tint.opacity(isComplete || isCurrent ? 0.18 : 0.07))
                    .frame(width: 21, height: 21)
                Image(systemName: isFailed ? "xmark" : (isComplete ? "checkmark" : step.systemImage))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(step.shortTitle)
                .font(.system(size: 9, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent || isComplete ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1), \(step.title)")
        .accessibilityValue(
            isFailed ? "stopped" : (isComplete ? "complete" : (isCurrent ? "current" : "pending"))
        )
    }
}
