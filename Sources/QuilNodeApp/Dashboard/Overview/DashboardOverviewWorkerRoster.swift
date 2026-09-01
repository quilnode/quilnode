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
    var overviewWorkerRoster: some View {
        let presentation = OverviewWorkerRosterPresentation.make(snapshot: monitor.snapshot)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Worker runtime")
                    .font(.system(size: 13, weight: .semibold))
                Text("One local process per card")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer(minLength: 12)
                if !nodeObservation.hasLiveTelemetry {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors.info)
                        .accessibilityLabel("Loading worker runtime")
                } else {
                    Button {
                        destination = .network
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

            ZStack(alignment: .topLeading) {
                overviewWorkerRosterContent(presentation)
                    .id(overviewWorkerRosterPhase(presentation))
                    .transition(motion.revealTransition)
            }
            .animation(motion.contentReplacement, value: overviewWorkerRosterPhase(presentation))
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func overviewWorkerRosterContent(
        _ presentation: OverviewWorkerRosterPresentation
    ) -> some View {
        switch overviewWorkerRosterPhase(presentation) {
        case .loading:
            overviewWorkerCardRow(loadingWorkers)
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
        case .privacy:
            overviewWorkerCardRow(privacyWorkers)
        case .empty:
            Button {
                destination = .network
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
            overviewWorkerCardRow(
                presentation.visibleWorkers(limit: overviewWorkerVisibleLimit)
            )
        }
    }

    private func overviewWorkerCardRow(
        _ workers: [OverviewWorkerRosterPresentation.Worker]
    ) -> some View {
        HStack(spacing: 9) {
            ForEach(workers) { worker in
                OverviewWorkerRuntimeCard(worker: worker) {
                    destination = .network
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewWorkerRosterPhase(
        _ presentation: OverviewWorkerRosterPresentation
    ) -> OverviewWorkerRosterPhase {
        if !nodeObservation.hasLiveTelemetry { return .loading }
        if privacyModeEnabled { return .privacy }
        return presentation.workers.isEmpty ? .empty : .workers
    }

    private var overviewWorkerVisibleLimit: Int {
        switch dashboardLayoutClass {
        case .wide: 5
        case .regular: 4
        case .compact: 3
        }
    }

    private var loadingWorkers: [OverviewWorkerRosterPresentation.Worker] {
        placeholderWorkers(label: "Reading")
    }

    private var privacyWorkers: [OverviewWorkerRosterPresentation.Worker] {
        placeholderWorkers(label: "Hidden")
    }

    private func placeholderWorkers(
        label: String
    ) -> [OverviewWorkerRosterPresentation.Worker] {
        (1...PrivacyLayoutPolicy.collectionPlaceholderCount).map { index in
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
                        value: worker.allocationLabel,
                        field: .shardAllocation
                    )
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }

                workerDatum(
                    label: "Shard",
                    value: worker.filter?.compactIdentifier ?? "Unassigned",
                    field: .shardAllocation
                )

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Coverage")
                    PrivacyProtectedText(
                        value: worker.coverage?.label ?? "Checking",
                        field: .shardAllocation
                    )
                    .foregroundStyle(coverageTint)
                    if let activeProvers = worker.activeProvers {
                        Text("·")
                        PrivacyProtectedText(
                            value: String(activeProvers),
                            field: .shardAllocation
                        )
                        Text(activeProvers == 1 ? "prover" : "provers")
                    }
                    if let ring = worker.ring {
                        Text("· Ring")
                        PrivacyProtectedText(
                            value: String(ring),
                            field: .shardAllocation
                        )
                    }
                }
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

                workerDatum(
                    label: "Storage",
                    value: storageLabel,
                    field: .hardwareProfile
                )
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
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
        .font(.system(size: 8.8, design: .monospaced))
        .foregroundStyle(theme.colors.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }

    private var storageLabel: String {
        guard let available = worker.availableStorage,
            let total = worker.totalStorage
        else { return "Reading" }
        return "\(available) / \(total)"
    }

    private var statusTint: Color {
        switch worker.allocationState {
        case .active: theme.colors.success
        case .joining: theme.colors.warning
        case .attention: theme.colors.danger
        case .awaitingAllocation: theme.colors.info
        }
    }

    private var coverageTint: Color {
        switch worker.coverage {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk, .unassigned: theme.colors.danger
        case nil: theme.colors.secondaryText
        }
    }
}
