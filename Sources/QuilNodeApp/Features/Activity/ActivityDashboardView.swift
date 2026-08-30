import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// The local flight recorder. Activity owns historical change and evidence;
/// current node state remains on the Overview, Network, and Identity surfaces.
struct ActivityDashboardView: View {
    @Environment(\.quilMotion) private var motion
    @EnvironmentObject private var history: NodeHistoryStore

    let snapshot: NodeSnapshot

    @State private var range: ActivityTimeRange = .sixHours
    @State private var mode: ActivityMode = .timeline
    @State private var filter: ActivityFilter = .all
    @State private var selectedEventID: String?
    @State private var selectedTimestamp: Date?

    private var samples: [NodeActivitySample] {
        history.activitySamples(since: range.interval)
    }

    private var summary: NodeActivitySummary {
        NodeActivityAnalyzer.summarize(samples)
    }

    private var chainProgress: ChainProgressAssessment {
        ChainProgressEvaluator.evaluate(snapshot)
    }

    private var allEvents: [NodeActivityEvent] {
        NodeActivityAnalyzer.events(from: samples)
    }

    private var filteredEvents: [NodeActivityEvent] {
        guard let category = filter.category else { return allEvents }
        return allEvents.filter { $0.category == category }
    }

    private var intervalPoints: [ActivityIntervalPoint] {
        ActivityPresentation.intervalPoints(from: samples)
    }

    private var selectedEvent: NodeActivityEvent? {
        guard let selectedEventID else { return filteredEvents.first }
        return allEvents.first { $0.id == selectedEventID } ?? filteredEvents.first
    }

    private var narrative: ActivityNarrative {
        ActivityPresentation.narrative(
            summary: summary,
            assessment: chainProgress,
            sampleCount: samples.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ActivityHeader(
                narrative: narrative,
                range: $range,
                mode: $mode
            )

            ActivitySummaryBand(
                summary: summary,
                chainProgress: chainProgress
            )

            ActivityFlightRecorderView(
                points: intervalPoints,
                events: allEvents,
                mode: mode,
                selectedTimestamp: $selectedTimestamp,
                selectedEventID: $selectedEventID
            )

            ActivityJournalWorkspace(
                events: filteredEvents,
                allEventCount: allEvents.count,
                filter: $filter,
                selectedEventID: $selectedEventID,
                selectedEvent: selectedEvent,
                snapshot: snapshot,
                hasLiveTelemetry: !samples.isEmpty
            )

            ActivityProvenanceRow()
        }
        .onAppear(perform: selectInitialEvent)
        .onChange(of: range) { _, _ in selectInitialEvent() }
        .onChange(of: filter) { _, _ in selectFirstFilteredEvent() }
        .onChange(of: allEvents.map(\.id)) { _, _ in
            guard mode == .live else { return }
            selectInitialEvent()
        }
        .onChange(of: mode) { _, newMode in apply(newMode) }
        .focusable()
        .onMoveCommand(perform: moveSelection)
        .animation(motion.selection, value: selectedEventID)
    }

    private func selectInitialEvent() {
        selectedEventID = allEvents.first?.id
        selectedTimestamp = intervalPoints.last?.timestamp
    }

    private func selectFirstFilteredEvent() {
        selectedEventID = filteredEvents.first?.id
        selectedTimestamp = filteredEvents.first?.timestamp ?? intervalPoints.last?.timestamp
    }

    private func apply(_ newMode: ActivityMode) {
        switch newMode {
        case .live:
            selectedTimestamp = intervalPoints.last?.timestamp
            selectedEventID = allEvents.first?.id
        case .timeline:
            selectedTimestamp = selectedEvent?.timestamp ?? intervalPoints.last?.timestamp
        case .snapshots:
            selectedEventID = filteredEvents.first?.id
            selectedTimestamp = filteredEvents.first?.timestamp
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard direction == .left || direction == .right else { return }

        if mode == .snapshots, !filteredEvents.isEmpty {
            let currentIndex = filteredEvents.firstIndex { $0.id == selectedEventID } ?? 0
            let offset = direction == .left ? 1 : -1
            let nextIndex = min(max(currentIndex + offset, 0), filteredEvents.count - 1)
            let event = filteredEvents[nextIndex]
            selectedEventID = event.id
            selectedTimestamp = event.timestamp
            return
        }

        guard !intervalPoints.isEmpty else { return }
        let currentIndex =
            selectedTimestamp.flatMap { timestamp in
                intervalPoints.enumerated().min {
                    abs($0.element.timestamp.timeIntervalSince(timestamp))
                        < abs($1.element.timestamp.timeIntervalSince(timestamp))
                }?.offset
            } ?? intervalPoints.count - 1
        let offset = direction == .left ? -1 : 1
        let nextIndex = min(max(currentIndex + offset, 0), intervalPoints.count - 1)
        selectedTimestamp = intervalPoints[nextIndex].timestamp
        selectedEventID =
            ActivityPresentation.nearestEvent(
                to: intervalPoints[nextIndex].timestamp,
                in: allEvents
            )?.id
    }
}
