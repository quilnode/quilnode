import QuilNodeCore
import SwiftUI

struct WorkerObservationRow: View {
    @Environment(\.quilTheme) private var theme
    let worker: LocalWorkerObservation?
    let nodeRunning: Bool
    var allocationLabel: String? = nil
    @State private var expanded = false

    private var execution: WorkerExecutionPresentation {
        .init(observation: worker?.execution, nodeRunning: nodeRunning)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 9) {
                datum("App frame", execution.frameText)
                datum("Last advance", execution.advanceText)
                datum("Observation", ObservationFreshness(observedAt: worker?.execution?.observedAt).label)
                if let phase = worker?.execution?.recoveryPhase {
                    datum("Recovery phase", phase.replacingOccurrences(of: "_", with: " "))
                }
                if let recorded = worker?.execution?.sealRecorded {
                    datum("Session seal", recorded ? "Recorded by GLOBAL" : "Awaiting GLOBAL recording")
                }
                if let blocker = worker?.execution?.blocker {
                    datum("Reported blocker", blocker)
                }
                datum("Shard", worker?.filter ?? "—")
                datum(
                    "Storage available / total",
                    worker.map {
                        $0.totalStorage == "0 B" ? "Not reported" : "\($0.availableStorage) / \($0.totalStorage)"
                    } ?? "—")
                if let failures = worker?.execution?.recoveryFailures {
                    datum("Consecutive recovery failures", String(failures))
                }
                PrivacyProtectedText(value: execution.detail, field: .shardAllocation)
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                if worker?.isDraining == true {
                    Text("Draining: this worker stops after its surplus assignment departs.")
                        .font(.caption).foregroundStyle(theme.colors.secondaryText)
                }
            }
            .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    PrivacyProtectedText(
                        value: worker.map { "Worker \($0.coreID)" } ?? "Worker", field: .hardwareProfile
                    )
                    .font(.subheadline.weight(.medium))
                    Spacer(minLength: 4)
                    PrivacyProtectedText(value: execution.title, field: .shardAllocation)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(execution.needsReview ? theme.colors.warning : theme.colors.secondaryText)
                }
                if let allocationLabel {
                    PrivacyProtectedText(
                        value: "Assignment: \(allocationLabel) · App frame: \(execution.frameText)",
                        field: .shardAllocation
                    )
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                }
                PrivacyProtectedText(
                    value: execution.isCurrent && !execution.needsReview
                        ? "Last advance: \(execution.advanceText)" : execution.detail,
                    field: .shardAllocation
                )
                .font(.caption2).foregroundStyle(theme.colors.secondaryText).lineLimit(2)
            }
        }
        .padding(10)
        .background(theme.colors.canvas.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func datum(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: .shardAllocation)
                .font(.caption.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
        }
    }
}
