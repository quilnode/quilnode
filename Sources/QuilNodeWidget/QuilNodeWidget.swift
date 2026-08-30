import SwiftUI
import WidgetKit

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

private struct QuilNodeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetNodeSnapshot
}

private struct QuilNodeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuilNodeEntry {
        QuilNodeEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuilNodeEntry) -> Void) {
        completion(
            QuilNodeEntry(
                date: Date(),
                snapshot: WidgetSnapshotStore.load() ?? .placeholder
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuilNodeEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = QuilNodeEntry(date: Date(), snapshot: snapshot)
        let nextRefresh =
            Calendar.current.date(byAdding: .minute, value: 5, to: Date())
            ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct QuilNodeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuilNodeEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
                .overlay(entry.snapshot.tint.opacity(0.08))
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.snapshot.frame.formatted(.number.grouping(.automatic)))
                    .font(.title2.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Current frame")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack {
                WidgetMetric(systemImage: "network", value: "\(entry.snapshot.peers)", label: "Peers")
                Spacer()
                WidgetMetric(
                    systemImage: entry.snapshot.activeShards > 0 ? "checkmark.seal.fill" : "square.grid.3x3.fill",
                    value:
                        "\(entry.snapshot.activeShards > 0 ? entry.snapshot.activeShards : entry.snapshot.pendingJoins)",
                    label: entry.snapshot.activeShards > 0 ? "Active" : "Joining"
                )
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                header
                Spacer(minLength: 0)
                Text(entry.snapshot.statusLabel)
                    .font(.title3.bold())
                Text("Frame \(entry.snapshot.frame.formatted(.number.grouping(.automatic)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                WidgetMetric(systemImage: "network", value: "\(entry.snapshot.peers)", label: "Peers")
                WidgetMetric(systemImage: "archivebox.fill", value: "\(entry.snapshot.archivePeers)", label: "Archive")
                WidgetMetric(
                    systemImage: "square.grid.3x3.fill", value: "\(entry.snapshot.totalAllocations)",
                    label: "Allocations")
                WidgetMetric(
                    systemImage: "checkmark.seal.fill", value: "\(entry.snapshot.activeShards)", label: "Shards")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(entry.snapshot.tint)
                Image(systemName: entry.snapshot.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text("QuilNode")
                    .font(.caption.weight(.semibold))
                Text(entry.snapshot.version ?? "Local")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WidgetMetric: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.bold().monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension WidgetNodeSnapshot {
    var statusLabel: String {
        switch health {
        case "active": "Active · Prover"
        case "joining": "Joining Shards"
        case "stalled", "warning": "Stalled"
        case "stopped": "Offline"
        default: "Online · Waiting"
        }
    }

    var systemImage: String {
        switch health {
        case "active": "checkmark"
        case "joining": "clock.badge.checkmark"
        case "stalled", "warning": "exclamationmark"
        case "stopped": "stop.fill"
        default: "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch health {
        case "active": .green
        case "joining": .orange
        case "stalled", "warning": .yellow
        case "stopped": .red
        default: .blue
        }
    }
}

private struct QuilNodeStatusWidget: Widget {
    let kind = "QuilNodeStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuilNodeTimelineProvider()) { entry in
            QuilNodeWidgetView(entry: entry)
        }
        .configurationDisplayName("QuilNode Status")
        .description("Local Quilibrium node health, frame, peers, and allocations.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct QuilNodeWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuilNodeStatusWidget()
    }
}
