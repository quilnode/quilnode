import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ActivityFlightRecorderView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass

    let points: [ActivityIntervalPoint]
    let events: [NodeActivityEvent]
    let mode: ActivityMode
    @Binding var selectedTimestamp: Date?
    @Binding var selectedEventID: String?

    private var orderedPoints: [ActivityIntervalPoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    private var chartDomain: ClosedRange<Date> {
        let now = Date()
        let start = orderedPoints.first?.timestamp ?? now.addingTimeInterval(-60)
        let end = orderedPoints.last?.timestamp ?? now
        return min(start, end.addingTimeInterval(-1))...max(end, start.addingTimeInterval(1))
    }

    private var visibleEvents: [NodeActivityEvent] {
        events
            .filter { chartDomain.contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(dashboardLayoutClass.isWide ? 3 : 1)
    }

    private var maximumFramePace: Double {
        max(orderedPoints.map(\.framesPerMinute).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text("Activity flight recorder")
                    .font(.headline)
                legend("Frames / min", tint: theme.colors.frame)
                Spacer()
                if mode == .live {
                    Label("Following live", systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(theme.colors.success)
                } else if let selectedTimestamp {
                    PrivacyProtectedText(
                        value: selectedTimestamp.formatted(date: .omitted, time: .standard),
                        field: .localTimestamp
                    )
                    .foregroundStyle(theme.colors.info)
                }
            }
            .font(.caption.weight(.semibold))

            if orderedPoints.count < 2 {
                ActivityEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Building the flight recorder",
                    detail: "Two movement intervals are needed. Samples remain private on this Mac for seven days."
                )
                .frame(minHeight: 220)
            } else {
                chart
                    .frame(height: 170)
                if !redactionReasons.contains(.privacy) {
                    legend("Connected peers", tint: theme.colors.accentSecondary, privacyField: .networkActivity)
                    peerChart.frame(height: 80)
                }
                ActivityTimelineScrubber(
                    points: orderedPoints,
                    selectedTimestamp: $selectedTimestamp,
                    selectedEvent: selectedEvent
                )
            }
        }
        .padding(14)
        .controlSurface(tint: theme.colors.frame)
        .onChange(of: mode) { _, newMode in
            if newMode == .live { selectedTimestamp = orderedPoints.last?.timestamp }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(orderedPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Frames per minute", point.framesPerMinute),
                    series: .value("Observation run", point.segment)
                )
                .foregroundStyle(by: .value("Series", "Frames / min"))
                .lineStyle(StrokeStyle(lineWidth: 1.35))
                .interpolationMethod(.linear)
            }

            ForEach(visibleEvents) { event in
                if !dashboardLayoutClass.isWide {
                    RuleMark(x: .value("Event", event.timestamp))
                        .foregroundStyle(eventTint(event).opacity(0.74))
                        .lineStyle(StrokeStyle(lineWidth: 0.8))
                } else {
                    RuleMark(x: .value("Event", event.timestamp))
                        .foregroundStyle(eventTint(event).opacity(0.74))
                        .lineStyle(StrokeStyle(lineWidth: 0.8))
                        .annotation(
                            position: .top,
                            alignment: markerAlignment(for: event),
                            spacing: 4
                        ) {
                            eventMarker(event)
                        }
                }
            }

            if let selectedTimestamp {
                RuleMark(x: .value("Selected time", selectedTimestamp))
                    .foregroundStyle(theme.colors.info.opacity(0.92))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartForegroundStyleScale([
            "Frames / min": theme.colors.frame,
            "Peers": theme.colors.accentSecondary,
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: chartDomain)
        .chartYScale(domain: 0...(maximumFramePace * 1.18))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) {
                AxisGridLine().foregroundStyle(theme.colors.border.opacity(0.30))
                AxisValueLabel(format: .dateTime.hour().minute())
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(theme.colors.border.opacity(0.30))
                AxisValueLabel().foregroundStyle(theme.colors.frame)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard mode != .live, let plotFrame = proxy.plotFrame else { return }
                                let frame = geometry[plotFrame]
                                let xPosition = value.location.x - frame.origin.x
                                guard xPosition >= 0, xPosition <= frame.width,
                                    let date: Date = proxy.value(atX: xPosition)
                                else { return }
                                select(date)
                            }
                    )
            }
        }
        .accessibilityLabel("Local frame pace in frames per minute")
        .accessibilityValue(accessibilitySummary)
    }

    private var selectedEvent: NodeActivityEvent? {
        guard let selectedEventID else { return nil }
        return events.first { $0.id == selectedEventID }
    }

    private func select(_ date: Date) {
        guard
            let nearestPoint = orderedPoints.min(by: {
                abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
            })
        else { return }
        selectedTimestamp = nearestPoint.timestamp
        selectedEventID = ActivityPresentation.nearestEvent(to: nearestPoint.timestamp, in: events)?.id
    }

    private var peerChart: some View {
        Chart(orderedPoints) { point in
            if let peers = point.peers {
                LineMark(
                    x: .value("Time", point.timestamp), y: .value("Connected peers", peers),
                    series: .value("Observation run", point.segment)
                )
                .foregroundStyle(theme.colors.accentSecondary)
                .interpolationMethod(.linear)
            }
        }
        .chartXScale(domain: chartDomain)
        .chartXAxis(.hidden)
        .chartYScale(domain: 0...max(orderedPoints.compactMap(\.peers).max() ?? 1, 1))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(theme.colors.border.opacity(0.30))
                AxisValueLabel().foregroundStyle(theme.colors.accentSecondary)
            }
        }
        .accessibilityLabel("Connected peers, observed counts. Gaps indicate missing or interrupted observations.")
    }

    private func legend(_ title: String, tint: Color, privacyField: PrivacyField? = nil) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(tint).frame(width: 16, height: 2)
            PrivacyProtectedText(value: title, field: privacyField)
        }
        .foregroundStyle(tint)
    }

    private func eventMarker(_ event: NodeActivityEvent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            PrivacyProtectedText(
                value: event.timestamp.formatted(date: .omitted, time: .shortened),
                field: .localTimestamp
            )
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            Text(markerTitle(event))
                .font(.system(size: 8.5, weight: .medium))
                .lineLimit(1)
            if let value = event.sensitiveValue {
                PrivacyProtectedText(value: value, field: event.privacyField)
                    .font(.system(size: 8, design: .monospaced))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(eventTint(event))
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(theme.colors.canvas.opacity(0.88), in: RoundedRectangle(cornerRadius: 4))
        .frame(width: 144, alignment: .leading)
    }

    private func markerAlignment(for event: NodeActivityEvent) -> Alignment {
        let midpoint = chartDomain.lowerBound.addingTimeInterval(
            chartDomain.upperBound.timeIntervalSince(chartDomain.lowerBound) / 2
        )
        return event.timestamp >= midpoint ? .trailing : .leading
    }

    private func eventTint(_ event: NodeActivityEvent) -> Color {
        switch event.journalSection {
        case .network: theme.colors.accentSecondary
        case .runtime: theme.colors.success
        case .router: theme.colors.warning
        case .chain: theme.colors.frame
        case .proving: theme.colors.accent
        }
    }

    private func markerTitle(_ event: NodeActivityEvent) -> String {
        switch event.kind {
        case .routerDropsIncreased: "Router filtered"
        case .inboundObserved: "Inbound peer"
        case .peerMeshChanged: "Peer mesh moved"
        case .archiveRecoveryStarted: "Recovery started"
        case .archiveRecoveryEnded: "Recovery cleared"
        default: event.title
        }
    }

    private var accessibilitySummary: String {
        guard let first = orderedPoints.first, let last = orderedPoints.last else { return "No trend available" }
        return "\(orderedPoints.count) intervals from \(first.timestamp.formatted()) to \(last.timestamp.formatted())."
    }
}

private struct ActivityTimelineScrubber: View {
    @Environment(\.quilTheme) private var theme

    let points: [ActivityIntervalPoint]
    @Binding var selectedTimestamp: Date?
    let selectedEvent: NodeActivityEvent?

    private var start: Date { points.first?.timestamp ?? Date() }
    private var end: Date { points.last?.timestamp ?? Date() }

    var body: some View {
        HStack(spacing: 10) {
            PrivacyProtectedText(
                value: start.formatted(date: .omitted, time: .shortened),
                field: .localTimestamp
            )
            .frame(width: 52, alignment: .leading)

            Slider(
                value: Binding(
                    get: { selectedTimestamp?.timeIntervalSince1970 ?? end.timeIntervalSince1970 },
                    set: { selectedTimestamp = Date(timeIntervalSince1970: $0) }
                ),
                in: start
                    .timeIntervalSince1970...max(
                        end.timeIntervalSince1970,
                        start.timeIntervalSince1970 + 1
                    )
            )
            .tint(theme.colors.info)
            .accessibilityLabel("Activity timeline")

            PrivacyProtectedText(
                value: end.formatted(date: .omitted, time: .shortened),
                field: .localTimestamp
            )
            .frame(width: 52, alignment: .trailing)

            if let selectedEvent {
                Text(selectedEvent.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 170, alignment: .trailing)
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(theme.colors.secondaryText)
    }
}
