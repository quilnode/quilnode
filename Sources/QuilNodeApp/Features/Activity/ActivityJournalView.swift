import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ActivityJournalWorkspace: View {
    let events: [NodeActivityEvent]
    let allEventCount: Int
    @Binding var filter: ActivityFilter
    @Binding var selectedEventID: String?
    let selectedEvent: NodeActivityEvent?
    let snapshot: NodeSnapshot
    let hasLiveTelemetry: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ActivityChangeJournal(
                events: events,
                allEventCount: allEventCount,
                filter: $filter,
                selectedEventID: $selectedEventID
            )
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            ActivityEvidenceInspector(
                event: selectedEvent,
                snapshot: snapshot,
                hasLiveTelemetry: hasLiveTelemetry
            )
            .frame(width: 330)
        }
    }
}

private struct ActivityChangeJournal: View {
    @Environment(\.quilTheme) private var theme

    let events: [NodeActivityEvent]
    let allEventCount: Int
    @Binding var filter: ActivityFilter
    @Binding var selectedEventID: String?

    private var sections: [(ActivityJournalSection, [NodeActivityEvent])] {
        let grouped = Dictionary(grouping: events, by: \.journalSection)
        return ActivityJournalSection.allCases.compactMap { section in
            guard let sectionEvents = grouped[section], !sectionEvents.isEmpty else { return nil }
            return (section, Array(sectionEvents.prefix(8)))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Change journal")
                    .font(.headline)
                Text("\(allEventCount) changes in this period")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                Menu {
                    Picker("Event theme", selection: $filter) {
                        ForEach(ActivityFilter.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text("Filter: \(filter.label)")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                    .background(theme.colors.surfaceElevated, in: RoundedRectangle(cornerRadius: 6))
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel("Filter activity journal")
            }
            .padding(.horizontal, 14)
            .frame(height: 44)

            Divider()
            columnHeader

            if sections.isEmpty {
                ActivityEmptyState(
                    icon: "checkmark.circle",
                    title: filter == .all
                        ? "No meaningful changes in this window" : "No \(filter.label.lowercased()) changes",
                    detail: "Routine samples stay out of the journal. Change the range to look further back."
                )
                .frame(minHeight: 150)
            } else {
                ForEach(sections, id: \.0.id) { section, sectionEvents in
                    ActivityJournalSectionHeader(section: section)
                    ForEach(sectionEvents) { event in
                        ActivityJournalRow(
                            event: event,
                            isSelected: event.id == selectedEventID,
                            onSelect: { selectedEventID = event.id }
                        )
                    }
                }
            }
        }
        .controlSurface()
    }

    private var columnHeader: some View {
        HStack(spacing: 10) {
            Text("TIME").frame(width: 68, alignment: .leading)
            Text("EVENT").frame(maxWidth: .infinity, alignment: .leading)
            Text("CHANGE").frame(width: 92, alignment: .leading)
            Text("EVIDENCE").frame(width: 110, alignment: .leading)
            Text("ACTION").frame(width: 72, alignment: .leading)
        }
        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
        .tracking(0.7)
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 14)
        .frame(height: 28)
    }
}

private struct ActivityJournalSectionHeader: View {
    @Environment(\.quilTheme) private var theme
    let section: ActivityJournalSection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(section.rawValue.uppercased())
                .foregroundStyle(tint)
            Text(sectionDetail)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer()
        }
        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
        .tracking(0.6)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(theme.colors.surfaceElevated.opacity(0.54))
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    private var tint: Color {
        switch section {
        case .network: theme.colors.accentSecondary
        case .runtime: theme.colors.success
        case .router: theme.colors.warning
        case .chain: theme.colors.frame
        case .proving: theme.colors.accent
        }
    }

    private var icon: String {
        switch section {
        case .network: "network"
        case .runtime: "waveform.path.ecg"
        case .router: "line.3.horizontal.decrease.circle"
        case .chain: "link"
        case .proving: "square.grid.3x3.fill"
        }
    }

    private var sectionDetail: String {
        switch section {
        case .network: "Peer mesh health"
        case .runtime: "Execution continuity"
        case .router: "Message filtering"
        case .chain: "Consensus progress"
        case .proving: "Allocation lifecycle"
        }
    }
}

private struct ActivityJournalRow: View {
    @Environment(\.quilTheme) private var theme

    let event: NodeActivityEvent
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                PrivacyProtectedText(
                    value: event.timestamp.formatted(date: .omitted, time: .standard),
                    field: .localTimestamp
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 68, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.primaryText)
                    Text(event.detail)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if let value = event.sensitiveValue {
                        PrivacyProtectedText(value: value, field: event.privacyField)
                    } else {
                        Text("Observed")
                    }
                }
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)

                Text(event.evidenceSource)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(2)
                    .frame(width: 110, alignment: .leading)

                Label(event.actionState.label, systemImage: actionIcon)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(actionTint)
                    .labelStyle(.titleAndIcon)
                    .frame(width: 72, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(isSelected ? theme.colors.info.opacity(0.09) : .clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? theme.colors.info : .clear)
                    .frame(width: 2)
            }
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
        .accessibilityLabel("\(event.title), \(event.actionState.label)")
    }

    private var tint: Color {
        switch event.journalSection {
        case .network: theme.colors.accentSecondary
        case .runtime: theme.colors.success
        case .router: theme.colors.warning
        case .chain: theme.colors.frame
        case .proving: theme.colors.accent
        }
    }

    private var actionTint: Color {
        switch event.actionState {
        case .none: theme.colors.success
        case .wait: theme.colors.info
        case .review: theme.colors.warning
        case .startNode: theme.colors.danger
        }
    }

    private var actionIcon: String {
        switch event.actionState {
        case .none: "checkmark.circle"
        case .wait: "hourglass"
        case .review: "exclamationmark.triangle"
        case .startNode: "play.circle"
        }
    }
}
