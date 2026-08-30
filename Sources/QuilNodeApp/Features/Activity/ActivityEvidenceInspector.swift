import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ActivityEvidenceInspector: View {
    @Environment(\.quilTheme) private var theme

    let event: NodeActivityEvent?
    let snapshot: NodeSnapshot
    let hasLiveTelemetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Selected event")
                .font(.headline)
                .padding(.horizontal, 14)
                .frame(height: 44)

            Divider()

            if let event {
                VStack(alignment: .leading, spacing: 12) {
                    Label(event.title, systemImage: eventIcon(event))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(eventTint(event))

                    if event.journalSection == .network || event.journalSection == .router {
                        evidenceGrid(event)
                        LocalNetworkTopologyView(
                            snapshot: snapshot,
                            hasLiveTelemetry: hasLiveTelemetry,
                            compact: true
                        )
                        .frame(height: 108)
                        .background(theme.colors.canvas.opacity(0.34))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        evidenceGrid(event)
                    }

                    Divider()

                    inspectorRow(title: "Why it matters", value: event.whyItMatters)
                    inspectorRow(title: "Source", value: event.evidenceSource)
                    inspectorRow(
                        title: "Freshness",
                        value: freshness(event.timestamp),
                        privacyField: .localTimestamp
                    )

                    HStack(alignment: .firstTextBaseline) {
                        Text("Action needed")
                            .foregroundStyle(theme.colors.secondaryText)
                            .frame(width: 86, alignment: .leading)
                        Label(event.actionState.label, systemImage: actionIcon(event.actionState))
                            .foregroundStyle(actionTint(event.actionState))
                    }
                    .font(.caption)
                }
                .padding(14)
            } else {
                ActivityEmptyState(
                    icon: "cursorarrow.click.2",
                    title: "Select a recorded change",
                    detail: "Choose an event marker or journal row to inspect its local evidence."
                )
                .frame(minHeight: 245)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .controlSurface()
    }

    private func evidenceGrid(_ event: NodeActivityEvent) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("Time (local)")
                PrivacyProtectedText(
                    value: event.timestamp.formatted(date: .abbreviated, time: .standard),
                    field: .localTimestamp
                )
                .monospacedDigit()
            }
            GridRow {
                Text("Category")
                Text(event.journalSection.rawValue)
            }
            GridRow {
                Text("Evidence")
                if let value = event.sensitiveValue {
                    PrivacyProtectedText(value: value, field: event.privacyField)
                } else {
                    Text("Observed locally")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(theme.colors.secondaryText)
        .gridColumnAlignment(.leading)
    }

    private func inspectorRow(
        title: String,
        value: String,
        privacyField: PrivacyField? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 86, alignment: .leading)
            PrivacyProtectedText(value: value, field: privacyField)
                .foregroundStyle(theme.colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func freshness(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
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

    private func eventIcon(_ event: NodeActivityEvent) -> String {
        switch event.journalSection {
        case .network: "network"
        case .runtime: "waveform.path.ecg"
        case .router: "line.3.horizontal.decrease.circle"
        case .chain: "link"
        case .proving: "square.grid.3x3.fill"
        }
    }

    private func actionTint(_ action: ActivityActionState) -> Color {
        switch action {
        case .none: theme.colors.success
        case .wait: theme.colors.info
        case .review: theme.colors.warning
        case .startNode: theme.colors.danger
        }
    }

    private func actionIcon(_ action: ActivityActionState) -> String {
        switch action {
        case .none: "checkmark.circle"
        case .wait: "hourglass"
        case .review: "exclamationmark.triangle"
        case .startNode: "play.circle"
        }
    }
}
