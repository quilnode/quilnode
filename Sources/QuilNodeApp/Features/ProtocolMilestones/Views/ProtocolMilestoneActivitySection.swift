import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ProtocolMilestoneActivitySection: View {
    let milestones: [ProtocolMilestone]
    let snapshot: NodeSnapshot
    let refreshError: String?
    let dismissedOverviewEventIDs: Set<String>
    let onRestoreToOverview: (ProtocolMilestone) -> Void

    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @State private var showsAll = false
    @State private var expandedEventID: String?

    private var frame: UInt64 { max(snapshot.frame, snapshot.lastReceivedFrame) }
    private var timeline: [ProtocolMilestone] {
        ProtocolMilestonePresentationPolicy.activityTimeline(milestones)
    }
    private var visibleTimeline: [ProtocolMilestone] {
        showsAll ? timeline : Array(timeline.prefix(3))
    }
    private var upcomingCount: Int { timeline.count(where: { $0.targetFrame > frame }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Protocol timeline", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                Text("Source-backed network events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !timeline.isEmpty {
                    Text("\(upcomingCount) upcoming · \(timeline.count - upcomingCount) passed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if timeline.isEmpty {
                HStack(spacing: 12) {
                    DashboardCircleIcon(
                        systemImage: refreshError == nil ? "scope" : "wifi.exclamationmark",
                        tint: refreshError == nil ? theme.colors.info : theme.colors.warning,
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(refreshError == nil ? "Discovering protocol events" : "Protocol timeline unavailable")
                            .font(.subheadline.weight(.semibold))
                        Text(
                            refreshError ?? "Reading deterministic frame gates from the cached official source commit."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .controlSurface(tint: refreshError == nil ? theme.colors.info : theme.colors.warning)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleTimeline.enumerated()), id: \.element.id) { index, milestone in
                        if index > 0 { Divider().opacity(0.55) }
                        timelineRow(milestone)
                    }

                    if timeline.count > 3 {
                        Divider().opacity(0.55)
                        Button {
                            withAnimation(motion.disclosure) {
                                showsAll.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: showsAll ? "chevron.up" : "clock.arrow.circlepath")
                                Text(showsAll ? "Show recent events only" : "Show \(timeline.count - 3) older events")
                                Spacer()
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.accent)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .controlSurface()
            }

            if let refreshError, !timeline.isEmpty {
                Label(
                    "Showing cached events · \(refreshError)",
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                )
                .font(.caption2)
                .foregroundStyle(theme.colors.warning)
                .padding(.horizontal, 4)
            }
        }
    }

    private func timelineRow(_ milestone: ProtocolMilestone) -> some View {
        let eventID = ProtocolMilestonePresentationPolicy.eventID(for: milestone)
        let expanded = expandedEventID == eventID
        let observed = snapshot.observedProtocolMilestones?[milestone.symbol] == milestone.targetFrame
        let state = ProtocolMilestonePresentationPolicy.state(
            for: milestone,
            currentFrame: frame,
            locallyObserved: observed
        )
        let tint = activityTint(milestone, state: state)

        return VStack(alignment: .leading, spacing: expanded ? 12 : 0) {
            Button {
                withAnimation(motion.disclosure) {
                    expandedEventID = expanded ? nil : eventID
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(tint.opacity(0.14))
                        Image(systemName: activityIcon(milestone, state: state))
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.colors.primaryText)
                        Text(activityDetail(milestone, state: state))
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                    }

                    Spacer(minLength: 12)

                    Text(activityStatus(milestone, state: state))
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.75)
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.10), in: Capsule())

                    Text(milestone.targetFrame.grouped)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 72, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(theme.colors.accent)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .animation(motion.selection, value: expanded)
                        .frame(width: 18)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(milestone.title), \(activityStatus(milestone, state: state)), frame \(milestone.targetFrame)"
            )
            .accessibilityHint(expanded ? "Collapse protocol event details" : "Expand protocol event details")

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(displaySummary(milestone))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(milestone.operatorImpact, systemImage: "bolt.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if state == .passedWithoutLocalEvidence {
                        Label(
                            "A matching success line is not retained in the local log. This is an evidence gap, not a failure state.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                    }
                    HStack(spacing: 13) {
                        Label(supportTitle(milestone.installedSupport), systemImage: "checkmark.shield")
                            .foregroundStyle(tint)
                        Button {
                            if let url = sourceURL(milestone) { NSWorkspace.shared.open(url) }
                        } label: {
                            Label("Official source", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.colors.accent)
                        Text("Checked \(milestone.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if dismissedOverviewEventIDs.contains(eventID),
                            milestone.targetFrame > frame
                        {
                            Button("Show on Overview") { onRestoreToOverview(milestone) }
                                .buttonStyle(.plain)
                                .foregroundStyle(theme.colors.accent)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 13)
                .transition(motion.revealTransition)
            }
        }
    }

    private func activityStatus(
        _ milestone: ProtocolMilestone,
        state: ProtocolMilestonePresentationPolicy.State
    ) -> String {
        if milestone.installedSupport == .missing { return "UPDATE REQUIRED" }
        if milestone.hasSourceConflict { return "SOURCE REVIEW" }
        switch state {
        case .upcoming: return "UPCOMING"
        case .imminent: return "APPROACHING"
        case .passedLocallyObserved: return "OBSERVED"
        case .passedWithoutLocalEvidence: return "PASSED"
        }
    }

    private func activityDetail(
        _ milestone: ProtocolMilestone,
        state: ProtocolMilestonePresentationPolicy.State
    ) -> String {
        switch state {
        case .upcoming, .imminent:
            return "\((milestone.targetFrame - frame).grouped) frames remaining"
        case .passedLocallyObserved:
            return "Local success evidence captured"
        case .passedWithoutLocalEvidence:
            return "\((frame - milestone.targetFrame).grouped) frames ago"
        }
    }

    private func activityTint(
        _ milestone: ProtocolMilestone,
        state: ProtocolMilestonePresentationPolicy.State
    ) -> Color {
        if milestone.installedSupport == .missing { return theme.colors.danger }
        if milestone.hasSourceConflict || state == .imminent { return theme.colors.warning }
        switch state {
        case .upcoming: return theme.colors.info
        case .imminent: return theme.colors.warning
        case .passedLocallyObserved: return theme.colors.success
        case .passedWithoutLocalEvidence: return theme.colors.secondaryText
        }
    }

    private func activityIcon(
        _ milestone: ProtocolMilestone,
        state: ProtocolMilestonePresentationPolicy.State
    ) -> String {
        if milestone.installedSupport == .missing { return "arrow.down.circle.fill" }
        if milestone.hasSourceConflict { return "exclamationmark.triangle.fill" }
        switch state {
        case .upcoming: return "calendar.badge.clock"
        case .imminent: return "clock.badge.exclamationmark"
        case .passedLocallyObserved: return "checkmark.seal.fill"
        case .passedWithoutLocalEvidence: return "flag.checkered"
        }
    }

    private func displaySummary(_ milestone: ProtocolMilestone) -> String {
        if milestone.symbol.contains("PROVER_RESET") {
            return
                "The scheduled network reset re-baselines the QUIL prover tree so allocations and archive state can return to one consistent view."
        }
        if milestone.symbol.contains("GRID_RESET") {
            return
                "The scheduled network reset coordinates the QUIL allocation grid and prover state at one deterministic frame."
        }
        return milestone.summary
    }

    private func supportTitle(_ support: ProtocolMilestoneSupport) -> String {
        switch support {
        case .included: return "Included in this node"
        case .missing: return "Update required"
        case .unknown: return "Support unverified"
        }
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
