import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ProtocolMilestoneOverviewSpotlight: View {
    let selection: ProtocolMilestonePresentationPolicy.OverviewSelection
    let snapshot: NodeSnapshot
    let onOpenActivity: () -> Void
    let onDismiss: () -> Void

    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @State private var showsSourceNote = false

    private var frame: UInt64 { max(snapshot.frame, snapshot.lastReceivedFrame) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(selection.milestone, now: context.date)
        }
    }

    private func content(_ milestone: ProtocolMilestone, now: Date) -> some View {
        let timing = ProtocolMilestoneTiming.estimate(
            targetFrame: milestone.targetFrame,
            currentFrame: frame,
            framesPerMinute: snapshot.framesPerMinute,
            lowerFramesPerMinute: snapshot.lowerFramesPerMinute,
            upperFramesPerMinute: snapshot.upperFramesPerMinute,
            now: snapshot.collectedAt
        )
        let phase = ProtocolMilestonePhase.resolve(targetFrame: milestone.targetFrame, currentFrame: frame)
        let appliedLocally = selection.state == .passedLocallyObserved
        let recoveryHold = ChainProgressEvaluator.evaluate(snapshot, now: now).state == .archiveRecovery
        let tint = recoveryHold ? theme.colors.info : tint(for: milestone, phase: phase)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    Image(systemName: phase == .reached ? "flag.checkered" : "scope")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 43, height: 43)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("PROTOCOL MILESTONE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.25)
                            .foregroundStyle(tint)
                        milestoneStatus(milestone, phase: phase, appliedLocally: appliedLocally)
                    }
                    Text(milestone.title)
                        .font(.title3.bold())
                    Text(displaySummary(milestone))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(
                        phase == .reached
                            ? "BOUNDARY PASSED"
                            : (recoveryHold ? "TIMING PAUSED" : countdown(timing.expectedAt, now: now))
                    )
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(tint)
                    Text("frame \(milestone.targetFrame.grouped)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if selection.isDismissible {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Hide this event from Overview. It remains in Activity.")
                    .accessibilityLabel("Hide \(milestone.title) from Overview")
                }
            }

            HStack(spacing: 0) {
                milestoneMetric(
                    title: phase == .reached ? "STATUS" : "FRAMES LEFT",
                    value: phase == .reached
                        ? (appliedLocally ? "Observed locally" : "Boundary passed") : timing.framesRemaining.grouped,
                    detail: phase == .reached
                        ? (appliedLocally ? "Success log captured" : "No local success log captured")
                        : (recoveryHold ? "Global head unchanged" : paceDetail(timing))
                )
                Divider().frame(height: 42)
                milestoneMetric(
                    title: "ESTIMATED WINDOW",
                    value: recoveryHold && phase != .reached ? "Waiting for frames" : etaWindow(timing, phase: phase),
                    detail: phase == .reached
                        ? "Retained in Activity"
                        : (recoveryHold ? "Archive recovery in progress" : timing.basis.rawValue)
                )
                Divider().frame(height: 42)
                milestoneMetric(
                    title: "THIS NODE",
                    value: supportTitle(milestone.installedSupport),
                    detail: String(milestone.commit.prefix(10)) + " · " + milestone.branch
                )
            }
            .padding(.vertical, 11)
            .background(
                theme.colors.surfaceElevated.opacity(0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "bolt.shield.fill")
                    .foregroundStyle(tint)
                Text(milestone.operatorImpact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            sourceEvidence(milestone)

            HStack(spacing: 12) {
                Button {
                    if let url = sourceURL(milestone) { NSWorkspace.shared.open(url) }
                } label: {
                    Label("Official source", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.accent)

                Text("Checked \(milestone.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)

                if let previous = milestone.previousTargetFrame {
                    Label("Changed from \(previous.grouped)", systemImage: "arrow.left.arrow.right")
                        .foregroundStyle(theme.colors.warning)
                }

                Spacer()

                Button("View Activity", action: onOpenActivity)
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.colors.accent)
            }
            .font(.caption2.weight(.semibold))
        }
        .padding(17)
        .controlSurface(tint: tint)
    }

    private func milestoneMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func milestoneStatus(
        _ milestone: ProtocolMilestone,
        phase: ProtocolMilestonePhase,
        appliedLocally: Bool
    ) -> some View {
        if milestone.installedSupport == .missing {
            Label("UPDATE REQUIRED", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(theme.colors.danger)
        } else if milestone.hasSourceConflict {
            Label("SOURCE REVIEW", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.colors.warning)
        } else {
            switch phase {
            case .upcoming:
                Label("UPCOMING", systemImage: "calendar.badge.clock")
                    .foregroundStyle(theme.colors.info)
            case .imminent:
                Label("APPROACHING", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(theme.colors.warning)
            case .reached:
                Label(
                    appliedLocally ? "OBSERVED LOCALLY" : "BOUNDARY PASSED",
                    systemImage: appliedLocally ? "checkmark.seal.fill" : "flag.checkered"
                )
                .foregroundStyle(appliedLocally ? theme.colors.success : theme.colors.info)
            }
        }
    }

    @ViewBuilder
    private func sourceEvidence(_ milestone: ProtocolMilestone) -> some View {
        if milestone.hasSourceConflict {
            Label(
                "Executable definitions disagree: frame \(milestone.targetFrame.grouped) and \(milestone.conflictingFrames.map(\.grouped).joined(separator: ", ")). Verify the official source before operating across this boundary.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.colors.warning)
            .padding(10)
            .background(theme.colors.warning.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: showsSourceNote ? 8 : 0) {
                HStack(spacing: 8) {
                    Label("Schedule verified in executable code", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(theme.colors.success)
                    Spacer()
                    if milestone.hasDocumentationNote {
                        Button {
                            withAnimation(motion.disclosure) { showsSourceNote.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Source note")
                                Image(systemName: "chevron.down")
                                    .rotationEffect(.degrees(showsSourceNote ? 180 : 0))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.colors.accent)
                        .accessibilityLabel(showsSourceNote ? "Hide source note" : "Show source note")
                    }
                }
                .font(.caption.weight(.medium))

                if showsSourceNote, milestone.hasDocumentationNote {
                    Text(
                        "A nearby non-executable comment still mentions frame \(milestone.documentationFrames.map(\.grouped).joined(separator: ", ")). The compiled constant and the runtime comparison both use frame \(milestone.targetFrame.grouped), so this does not change the node’s schedule."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(motion.revealTransition)
                }
            }
            .padding(10)
            .background(theme.colors.success.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func tint(for milestone: ProtocolMilestone, phase: ProtocolMilestonePhase) -> Color {
        if milestone.installedSupport == .missing { return theme.colors.danger }
        if milestone.hasSourceConflict { return theme.colors.warning }
        if phase == .imminent { return theme.colors.warning }
        return phase == .reached ? theme.colors.success : theme.colors.info
    }

    private func displaySummary(_ milestone: ProtocolMilestone) -> String {
        if milestone.symbol.contains("PROVER_RESET") {
            return
                "A scheduled network reset will rebuild the QUIL prover tree so allocations and archive state can return to one consistent baseline. The node handles the transition automatically."
        }
        if milestone.symbol.contains("GRID_RESET") {
            return
                "A scheduled network reset will coordinate the QUIL allocation grid and prover state at one deterministic frame."
        }
        return milestone.summary
    }

    private func supportTitle(_ support: ProtocolMilestoneSupport) -> String {
        switch support {
        case .included: "Ready"
        case .missing: "Update required"
        case .unknown: "Verify update"
        }
    }

    private func paceDetail(_ timing: ProtocolMilestoneTiming) -> String {
        if timing.basis == .nominal { return "10-second fallback" }
        guard let pace = snapshot.framesPerMinute else { return timing.basis.rawValue }
        return String(format: "%.1f frames/min", pace)
    }

    private func countdown(_ date: Date?, now: Date) -> String {
        guard let date else { return "Reached" }
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3_600
        let minutes = seconds % 3_600 / 60
        let remainingSeconds = seconds % 60
        if days > 0 { return String(format: "%dd %02dh %02dm", days, hours, minutes) }
        if hours > 0 { return String(format: "%02dh %02dm %02ds", hours, minutes, remainingSeconds) }
        return String(format: "%02dm %02ds", minutes, remainingSeconds)
    }

    private func etaWindow(
        _ timing: ProtocolMilestoneTiming,
        phase: ProtocolMilestonePhase
    ) -> String {
        guard phase != .reached, let earliest = timing.earliestAt, let latest = timing.latestAt else {
            return "Completed"
        }
        let sameDay = Calendar.current.isDate(earliest, inSameDayAs: latest)
        if sameDay {
            return earliest.formatted(date: .abbreviated, time: .shortened)
                + "–" + latest.formatted(date: .omitted, time: .shortened)
        }
        return earliest.formatted(date: .abbreviated, time: .shortened)
            + "–" + latest.formatted(date: .abbreviated, time: .shortened)
    }

    private func sourceURL(_ milestone: ProtocolMilestone) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/QuilibriumNetwork/monorepo/blob/\(milestone.commit)/\(milestone.sourcePath)"
        components.fragment = "L\(milestone.sourceLine)"
        return components.url
    }
}
