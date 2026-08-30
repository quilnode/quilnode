import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ProtocolMilestoneMenuCard: View {
    let milestones: [ProtocolMilestone]
    let snapshot: NodeSnapshot

    @Environment(\.quilTheme) private var theme

    private var frame: UInt64 { max(snapshot.frame, snapshot.lastReceivedFrame) }
    private var featured: ProtocolMilestone? {
        milestones.first(where: { $0.targetFrame > frame })
    }

    var body: some View {
        if let milestone = featured {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let recoveryHold =
                    ChainProgressEvaluator.evaluate(snapshot, now: context.date).state == .archiveRecovery
                let timing = ProtocolMilestoneTiming.estimate(
                    targetFrame: milestone.targetFrame,
                    currentFrame: frame,
                    framesPerMinute: snapshot.framesPerMinute,
                    lowerFramesPerMinute: snapshot.lowerFramesPerMinute,
                    upperFramesPerMinute: snapshot.upperFramesPerMinute,
                    now: snapshot.collectedAt
                )
                HStack(spacing: 10) {
                    Image(systemName: "scope")
                        .foregroundStyle(
                            milestone.installedSupport == .missing ? theme.colors.danger : theme.colors.info)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.caption.weight(.semibold))
                        Text("\(timing.framesRemaining.grouped) frames · target \(milestone.targetFrame.grouped)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(recoveryHold ? "Waiting" : compactCountdown(timing.expectedAt, now: context.date))
                        .font(.caption.bold().monospacedDigit())
                }
                .padding(11)
                .background(theme.colors.info.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
    }

    private func compactCountdown(_ date: Date?, now: Date) -> String {
        guard let date else { return "now" }
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        if seconds >= 86_400 { return "~\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h" }
        if seconds >= 3_600 { return "~\(seconds / 3_600)h \((seconds % 3_600) / 60)m" }
        return "~\(max(seconds / 60, 1))m"
    }
}
