import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum ActivityTimeRange: String, CaseIterable, Identifiable {
    case oneHour
    case sixHours
    case oneDay
    case sevenDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: "1h"
        case .sixHours: "6h"
        case .oneDay: "24h"
        case .sevenDays: "7d"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .oneHour: 60 * 60
        case .sixHours: 6 * 60 * 60
        case .oneDay: 24 * 60 * 60
        case .sevenDays: 7 * 24 * 60 * 60
        }
    }
}

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case proving
    case network
    case rewards
    case runtime
    case identity

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var category: NodeActivityCategory? {
        switch self {
        case .all: nil
        case .proving: .proving
        case .network: .network
        case .rewards: .rewards
        case .runtime: .runtime
        case .identity: .identity
        }
    }
}

/// Activity is a local event journal: it answers “what changed?” and “how has
/// this session behaved?” Current state remains owned by Overview, Network,
/// Identity, and Wallet so operators never have to reconcile duplicate cards.
struct ActivityDashboardView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var history: NodeHistoryStore
    @EnvironmentObject private var privacyMode: PrivacyModeController

    let snapshot: NodeSnapshot

    @State private var range: ActivityTimeRange = .sixHours
    @State private var filter: ActivityFilter = .all

    private var samples: [NodeActivitySample] {
        history.activitySamples(since: range.interval)
    }

    private var summary: NodeActivitySummary {
        NodeActivityAnalyzer.summarize(samples)
    }

    private var chainProgress: ChainProgressAssessment {
        ChainProgressEvaluator.evaluate(snapshot)
    }

    private var events: [NodeActivityEvent] {
        let all = NodeActivityAnalyzer.events(from: samples)
        guard let category = filter.category else { return all }
        return all.filter { $0.category == category }
    }

    private var intervalPoints: [ActivityIntervalPoint] {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        return zip(ordered, ordered.dropFirst()).compactMap { previous, current in
            let duration = current.timestamp.timeIntervalSince(previous.timestamp)
            guard duration > 0, current.frame >= previous.frame else { return nil }
            return ActivityIntervalPoint(
                timestamp: current.timestamp,
                framesPerMinute: Double(current.frame - previous.frame) / duration * 60,
                peers: current.peers
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            pulse
            trends
            journal
            provenance
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Local activity journal")
                    .font(.title3.bold())
                Text("Meaningful changes and trends from this Mac—not a second copy of current status.")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 12)
            Picker("Activity range", selection: $range) {
                ForEach(ActivityTimeRange.allCases) { value in
                    Text(value.label).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
    }

    private var pulse: some View {
        VStack(alignment: .leading, spacing: 10) {
            ActivitySectionHeader(title: "Window pulse", systemImage: "waveform.path.ecg")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ActivitySummaryCard(
                    title: "Frames advanced",
                    value: summary.frameDelta.formatted(),
                    detail: range.label + " observation window",
                    systemImage: "forward.frame.fill",
                    tint: theme.colors.frame
                )
                ActivitySummaryCard(
                    title: "Average pace",
                    value: chainProgress.state == .archiveRecovery
                        ? "Network hold"
                        : (summary.averageFramesPerMinute.map { String(format: "%.2f/min", $0) } ?? "Calibrating"),
                    detail: chainProgress.state == .archiveRecovery
                        ? "Archive recovery detected locally"
                        : "Measured from local frame movement",
                    systemImage: chainProgress.state == .archiveRecovery ? "hourglass" : "speedometer",
                    tint: theme.colors.info
                )
                ActivitySummaryCard(
                    title: "Peer band",
                    value: peerBand + " · " + peerDeltaLabel,
                    detail: "Observed range · net change",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: theme.colors.accentSecondary,
                    privacyField: .networkActivity
                )
                ActivitySummaryCard(
                    title: "Runtime continuity",
                    value: summary.continuity.map { String(format: "%.0f%%", $0 * 100) } ?? "Calibrating",
                    detail: "Share of local samples online",
                    systemImage: "bolt.horizontal.circle.fill",
                    tint: continuityTint
                )
            }
        }
    }

    private var trends: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ActivitySectionHeader(title: "Local trends", systemImage: "chart.xyaxis.line")
                Spacer()
                Text("Frame pace + peer mesh")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
            }

            Group {
                if intervalPoints.count < 2 {
                    ActivityEmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Building the trend",
                        detail: "Two movement intervals are needed. Samples are retained privately for seven days."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            Label("Frame pace", systemImage: "minus")
                                .foregroundStyle(theme.colors.frame)
                            Label("Peers", systemImage: "minus")
                                .foregroundStyle(theme.colors.info)
                            Spacer()
                            Text("\(intervalPoints.count) intervals")
                                .foregroundStyle(theme.colors.secondaryText)
                        }
                        .font(.caption2.weight(.semibold))

                        Chart {
                            ForEach(intervalPoints) { point in
                                AreaMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Frames/min", point.framesPerMinute)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [theme.colors.frame.opacity(0.28), theme.colors.frame.opacity(0.02)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Frames/min", point.framesPerMinute)
                                )
                                .foregroundStyle(theme.colors.frame)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) {
                                AxisGridLine().foregroundStyle(theme.colors.border.opacity(0.35))
                                AxisValueLabel(format: .dateTime.hour().minute())
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) {
                                AxisGridLine().foregroundStyle(theme.colors.border.opacity(0.35))
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 150)

                        if privacyMode.isEnabled {
                            Label("Peer trend hidden by Privacy Mode", systemImage: "eye.slash.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.colors.privacy)
                        } else {
                            Chart(intervalPoints) { point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Peers", point.peers)
                                )
                                .foregroundStyle(theme.colors.info)
                                .interpolationMethod(.catmullRom)
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis {
                                AxisMarks(position: .leading) {
                                    AxisGridLine().foregroundStyle(theme.colors.border.opacity(0.35))
                                    AxisValueLabel()
                                }
                            }
                            .frame(height: 72)
                            .accessibilityLabel("Local peer-count trend")
                        }
                    }
                    .padding(16)
                }
            }
            .controlSurface(tint: theme.colors.frame)
        }
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ActivitySectionHeader(
                    title: "Changes", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                Spacer()
                Picker("Event filter", selection: $filter) {
                    ForEach(ActivityFilter.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
                .frame(width: 145)
            }

            VStack(spacing: 0) {
                if events.isEmpty {
                    ActivityEmptyState(
                        icon: "checkmark.circle",
                        title: filter == .all
                            ? "No meaningful changes in this window" : "No \(filter.label.lowercased()) changes",
                        detail: "Routine samples stay out of the journal. Change the time window to look further back."
                    )
                } else {
                    ForEach(Array(events.prefix(50).enumerated()), id: \.element.id) { index, event in
                        ActivityEventRow(event: event)
                        if index < min(events.count, 50) - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
            .controlSurface()
        }
    }

    private var provenance: some View {
        HStack(spacing: 16) {
            Label("Local node evidence", systemImage: "lock.shield.fill")
            Label("30-second samples", systemImage: "timer")
            Label("7-day retention", systemImage: "calendar")
            Spacer()
            Text("No explorer or remote agent")
        }
        .font(.caption2)
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 4)
    }

    private var peerBand: String {
        guard let minimum = summary.peerMinimum, let maximum = summary.peerMaximum else { return "Calibrating" }
        return minimum == maximum ? String(minimum) : "\(minimum)–\(maximum)"
    }

    private var peerDeltaLabel: String {
        guard summary.peerMinimum != nil else { return "calibrating" }
        if summary.peerDelta == 0 { return "±0" }
        return "\(summary.peerDelta > 0 ? "+" : "")\(summary.peerDelta)"
    }

    private var continuityTint: Color {
        guard let continuity = summary.continuity else { return theme.colors.info }
        if continuity >= 0.98 { return theme.colors.success }
        if continuity >= 0.90 { return theme.colors.warning }
        return theme.colors.danger
    }
}
