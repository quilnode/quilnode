import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

private enum OverviewWorkerRosterPhase: Hashable {
    case loading
    case privacy
    case empty
    case workers
}

extension DashboardView {
    func overviewWorkerRoster(layoutClass: DashboardLayoutClass) -> some View {
        let presentation = OverviewWorkerRosterPresentation.make(snapshot: monitor.snapshot)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Workers")
                    .font(.system(size: 13, weight: .semibold))
                Text("Execution is separate from assignment")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer(minLength: 12)
                if overviewWorkerRosterPhase(presentation) == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors.info)
                        .accessibilityLabel("Loading worker runtime")
                } else {
                    Button {
                        openOverviewNetwork(.workers)
                    } label: {
                        Label("View all", systemImage: "arrow.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(theme.colors.info)
                    .accessibilityHint("Opens the complete worker roster in Network")
                }
            }

            overviewWorkerRosterContent(
                presentation,
                visibleCardCount: overviewWorkerCardCount(layoutClass: layoutClass)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func overviewWorkerRosterContent(
        _ presentation: OverviewWorkerRosterPresentation,
        visibleCardCount: Int
    ) -> some View {
        switch overviewWorkerRosterPhase(presentation) {
        case .loading:
            overviewWorkerCardRow(placeholderWorkers(count: visibleCardCount, label: "Reading"))
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        case .privacy:
            overviewWorkerCardRow(placeholderWorkers(count: visibleCardCount, label: "Hidden"))
        case .empty:
            Button {
                openOverviewNetwork(.workers)
            } label: {
                HStack(spacing: 11) {
                    DashboardCircleIcon(
                        systemImage: "cpu",
                        tint: theme.colors.info,
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No worker process reported")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.colors.primaryText)
                        Text("Open Network for the complete local runtime evidence.")
                            .font(.system(size: 9.5))
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.colors.info)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                .contentShape(Rectangle())
                .controlSurface(tint: theme.colors.info.opacity(0.42))
            }
            .buttonStyle(QuilPressFeedbackButtonStyle())
            .quilHoverSurface(tint: theme.colors.info)
        case .workers:
            overviewWorkerCardRow(presentation.visibleWorkers(limit: visibleCardCount))
        }
    }

    private func overviewWorkerCardCount(layoutClass: DashboardLayoutClass) -> Int {
        switch layoutClass {
        case .wide: 5
        case .regular: 4
        case .compact: 3
        }
    }

    private func overviewWorkerCardRow(
        _ workers: [OverviewWorkerRosterPresentation.Worker]
    ) -> some View {
        HStack(spacing: 9) {
            ForEach(workers) { worker in
                OverviewWorkerRuntimeCard(worker: worker) {
                    openOverviewNetwork(.workers)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewWorkerRosterPhase(
        _ presentation: OverviewWorkerRosterPresentation
    ) -> OverviewWorkerRosterPhase {
        if !nodeObservation.hasLiveTelemetry || presentation.isAwaitingEvidence {
            return .loading
        }
        if privacyModeEnabled { return .privacy }
        return presentation.workers.isEmpty ? .empty : .workers
    }

    private func placeholderWorkers(
        count: Int,
        label: String
    ) -> [OverviewWorkerRosterPresentation.Worker] {
        (1...count).map { index in
            OverviewWorkerRosterPresentation.Worker(
                coreID: index,
                filter: "hidden",
                availableStorage: nil,
                totalStorage: nil,
                allocationLabel: label,
                allocationState: .awaitingAllocation,
                coverage: nil,
                activeProvers: nil,
                ring: nil
            )
        }
    }
}

private struct OverviewWorkerRuntimeCard: View {
    @Environment(\.quilTheme) private var theme

    let worker: OverviewWorkerRosterPresentation.Worker
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 7, height: 7)
                    PrivacyProtectedPhrase(
                        prefix: "Worker ",
                        value: String(worker.coreID),
                        field: .hardwareProfile
                    )
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(theme.colors.primaryText)
                    Spacer(minLength: 4)
                    PrivacyProtectedText(
                        value: execution.title,
                        field: .shardAllocation
                    )
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }

                workerDatum(
                    label: "Shard",
                    value: worker.filter?.compactIdentifier ?? "Unassigned",
                    field: .shardAllocation
                )

                workerDatum(label: "Assignment", value: worker.allocationLabel, field: .shardAllocation)
                workerDatum(label: "App frame", value: execution.frameText, field: .shardAllocation)
                PrivacyProtectedText(
                    value: worker.isDraining
                        ? "Draining surplus worker"
                        : (execution.needsReview || worker.execution?.recoveryPhase.map({ $0 != "idle" }) == true
                            ? execution.detail : "Last advance: " + execution.advanceText), field: .shardAllocation
                )
                .font(.caption2).foregroundStyle(theme.colors.secondaryText)
                .lineLimit(2)

            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            .contentShape(Rectangle())
            .controlSurface(tint: statusTint.opacity(0.45))
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: statusTint)
        .accessibilityHint("Opens the complete worker roster in Network")
    }

    private func workerDatum(
        label: String,
        value: String,
        field: PrivacyField
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
            PrivacyProtectedText(value: value, field: field)
                .fontWeight(.semibold)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(theme.colors.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }

    private var execution: WorkerExecutionPresentation {
        .init(observation: worker.execution, nodeRunning: worker.nodeRunning)
    }

    private var statusTint: Color {
        switch execution.tone {
        case .warning: theme.colors.warning
        case .progress: theme.colors.info
        case .neutral: theme.colors.secondaryText
        }
    }

}
