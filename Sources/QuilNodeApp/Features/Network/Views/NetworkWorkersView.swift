import QuilNodeCore
import SwiftUI

/// Direct operational drill-down. The network map is a separate workspace so
/// investigating a worker never requires scrolling past a visualization.
struct NetworkWorkersView: View {
    @EnvironmentObject private var monitor: NodeMonitor
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var layout
    @Environment(\.redactionReasons) private var redactionReasons

    private var snapshot: NodeSnapshot { monitor.snapshot }
    private var hidden: Bool { redactionReasons.contains(.privacy) }
    private var workers: [LocalWorkerObservation] {
        (snapshot.localWorkers ?? []).sorted { $0.coreID < $1.coreID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local workers").font(.title2.weight(.semibold))
                    Text(
                        "Assignments describe registry membership. Execution and frame progress come from each worker."
                    )
                    .font(.callout).foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                PrivacyProtectedText(
                    value: ObservationFreshness(observedAt: snapshot.proverStatusUpdatedAt).label,
                    field: .localTimestamp
                )
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
            if workers.isEmpty && !hidden {
                ContentUnavailableView(
                    snapshot.proverStatusUpdatedAt == nil ? "Waiting for worker observations" : "No workers reported",
                    systemImage: "cpu",
                    description: Text(
                        "Worker information comes from the local node through qclient. A registry assignment alone does not establish a running worker."
                    ))
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: layout.isCompact ? 1 : 2),
                    alignment: .leading, spacing: 12
                ) {
                    if hidden {
                        ForEach(0..<PrivacyLayoutPolicy.collectionPlaceholderCount, id: \.self) { _ in
                            WorkerObservationRow(
                                worker: nil, nodeRunning: snapshot.isRunning, allocationLabel: "Hidden")
                        }
                    } else {
                        ForEach(workers) { worker in
                            WorkerObservationRow(
                                worker: worker, nodeRunning: snapshot.isRunning,
                                allocationLabel: allocation(for: worker))
                        }
                    }
                }
            }
            Label(
                "Host state, frame advancement and rewards are independent signals. Expand any worker for its observation time, recovery and storage details.",
                systemImage: "info.circle"
            )
            .font(.caption).foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).controlSurface()
    }

    private func allocation(for worker: LocalWorkerObservation) -> String {
        guard !worker.filter.isEmpty,
            let assignment = snapshot.shardAllocations.first(where: { $0.filter == worker.filter })
        else { return "Not reported" }
        return assignment.status
    }
}
