import SwiftUI

extension DashboardView {
    var updateFlightPlanIdle: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update flight plan")
                        .font(.headline)
                    Text("Every node candidate follows the same safety envelope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("Node stays online during preparation", systemImage: "bolt.horizontal.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.colors.success)
            }

            updateFlightSectionLabels
            updateFlightStageGrid(current: nil, completed: [])

            HStack(spacing: 16) {
                Label("Pinned candidate", systemImage: "scope")
                Label("Cryptographic checks", systemImage: "checkmark.seal")
                Label("Compatible qclient reused", systemImage: "terminal")
                Label("Automatic rollback", systemImage: "arrow.uturn.backward.circle")
                Label("Local health gate", systemImage: "waveform.path.ecg")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .controlSurface(tint: theme.colors.info)
    }

    var updateFlightSectionLabels: some View {
        HStack(spacing: 12) {
            Label("Preparation — node stays online", systemImage: "checkmark.shield.fill")
                .foregroundStyle(theme.colors.success)
                .frame(maxWidth: .infinity)
            Label("Activation — brief restart", systemImage: "arrow.triangle.swap")
                .foregroundStyle(theme.colors.warning)
                .frame(maxWidth: .infinity)
        }
        .font(.caption.weight(.semibold))
    }

    func updateFlightStageGrid(
        current: UpdateFlightStage?,
        completed: Set<UpdateFlightStage>
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: UpdateFlightStage.allCases.count),
            spacing: 8
        ) {
            ForEach(UpdateFlightStage.allCases) { stage in
                let isComplete = completed.contains(stage)
                let isCurrent = current == stage
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: isComplete ? "checkmark.circle.fill" : stage.systemImage)
                            .foregroundStyle(
                                isComplete
                                    ? theme.colors.success
                                    : (isCurrent ? theme.colors.warning : Color.secondary)
                            )
                        Text(stage.title)
                            .font(.caption.weight(isCurrent ? .bold : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Text(stage.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (isCurrent ? theme.colors.warning : Color.secondary).opacity(isCurrent ? 0.08 : 0.035),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            isCurrent ? theme.colors.warning.opacity(0.55) : Color.secondary.opacity(0.10),
                            lineWidth: 1
                        )
                }
            }
        }
    }

    func releaseCheckProgressCard(_ progress: ReleaseCheckProgress) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = max(timeline.date.timeIntervalSince(progress.startedAt), 0)
            HStack(spacing: 14) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.stage.title)
                        .font(.subheadline.weight(.semibold))
                    Text(progress.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                ProgressView(value: progress.fraction, total: 1)
                    .progressViewStyle(.linear)
                    .frame(width: 220)
                Text("Step \(progress.stage.stepNumber)/4")
                    .font(.caption.monospacedDigit())
                Text("\(compactDuration(elapsed))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .controlSurface(tint: theme.colors.info)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Release check progress")
            .accessibilityValue("Step \(progress.stage.stepNumber) of 4, \(progress.stage.title)")
        }
    }

    func compactDuration(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded()), 0)
        if value < 60 { return "\(value)s" }
        let minutes = value / 60
        let remainder = value % 60
        return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
    }
}
