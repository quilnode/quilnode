import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A persistent application footer. It reports observation freshness without
/// competing with page content and always opens the evidence-rich Diagnostics
/// destination when selected.
struct DashboardStatusFooter: View {
    @Environment(\.quilTheme) private var theme

    let snapshot: NodeSnapshot
    let observationPhase: NodeObservationPhase
    let onOpenDiagnostics: () -> Void

    private var presentation: NodeObservationPresentation {
        NodeObservationPresentation(phase: observationPhase, snapshot: snapshot)
    }

    var body: some View {
        Button(action: onOpenDiagnostics) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)
                    .shadow(color: statusTint.opacity(0.5), radius: 4)
                Text(statusTitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.colors.primaryText)

                footerDivider

                Label(frameLabel, systemImage: "square.stack.3d.up")
                    .font(.system(size: 9.5, design: .monospaced).monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)

                Rectangle()
                    .fill(theme.colors.info.opacity(presentation.hasLiveTelemetry ? 0.54 : 0.20))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(theme.metrics.borderWidth, 0.5))

                footerDivider

                HStack(spacing: 4) {
                    Text("Updated")
                    PrivacyProtectedText(
                        value: snapshot.collectedAt.formatted(date: .omitted, time: .standard),
                        field: .localTimestamp
                    )
                }
                .font(.system(size: 9.5, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.colors.info)
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 43)
        .background(theme.colors.sidebar.opacity(theme.components.elevatedOpacity))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.colors.border.opacity(0.68))
                .frame(height: max(theme.metrics.borderWidth, 0.5))
        }
        .help("Open Diagnostics")
        .accessibilityLabel("\(statusTitle). \(frameLabel). Open Diagnostics.")
    }

    private var footerDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.54))
            .frame(width: max(theme.metrics.borderWidth, 0.5), height: 16)
    }

    private var frameLabel: String {
        guard presentation.hasLiveTelemetry else { return "Frame —" }
        return "Frame \(max(snapshot.frame, snapshot.lastReceivedFrame).grouped)"
    }

    private var statusTitle: String {
        switch observationPhase {
        case .checkingProcess: "Reading local node state"
        case .loadingTelemetry: snapshot.isRunning ? "Node found · loading telemetry" : "Reading telemetry"
        case .ready: snapshot.isRunning ? "Local node state is current" : "Local node service is stopped"
        }
    }

    private var statusTint: Color {
        switch observationPhase {
        case .checkingProcess, .loadingTelemetry: theme.colors.info
        case .ready: snapshot.isRunning ? theme.colors.success : theme.colors.danger
        }
    }
}
