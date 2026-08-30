import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum HistoryRange: String, CaseIterable, Identifiable {
    case oneHour
    case sixHours
    case oneDay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: "1h"
        case .sixHours: "6h"
        case .oneDay: "24h"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .oneHour: 60 * 60
        case .sixHours: 6 * 60 * 60
        case .oneDay: 24 * 60 * 60
        }
    }
}

struct LifecycleControlBar: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject private var lifecycle: NodeLifecycleController
    @State private var pendingConfirmation: NodeLifecycleAction?

    let compact: Bool

    private var processStateKnown: Bool {
        monitor.observationPhase.hasDeterminedProcessState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 9) {
                if !compact {
                    HStack(spacing: 9) {
                        DashboardCircleIcon(
                            systemImage: !processStateKnown
                                ? "ellipsis.circle.fill"
                                : monitor.snapshot.isRunning ? "power.circle.fill" : "power.circle",
                            tint: !processStateKnown
                                ? theme.colors.info
                                : monitor.snapshot.isRunning ? theme.colors.success : theme.colors.danger,
                            size: 38
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(
                                !processStateKnown
                                    ? "Checking node service"
                                    : monitor.snapshot.isRunning
                                        ? DashboardCopy.Updates.nodeServiceRunning
                                        : "Node service stopped"
                            )
                            .font(.subheadline.weight(.semibold))
                            Text(lifecycleSubtitle)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                lifecycleButton(.start, tint: theme.colors.success) {
                    Task { await lifecycle.perform(.start, monitor: monitor) }
                }
                .disabled(!processStateKnown || monitor.snapshot.isRunning || lifecycle.isWorking)

                lifecycleButton(.restart, tint: theme.colors.info) {
                    pendingConfirmation = .restart
                }
                .disabled(!processStateKnown || !monitor.snapshot.isRunning || lifecycle.isWorking)

                lifecycleButton(.stop, tint: theme.colors.danger) {
                    pendingConfirmation = .stop
                }
                .disabled(!processStateKnown || !monitor.snapshot.isRunning || lifecycle.isWorking)
            }

            if !compact, let message = lifecycle.lastMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colors.success)
                    .lineLimit(2)
            }
            if !compact, let error = lifecycle.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colors.danger)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(compact ? 10 : 14)
        .controlSurface()
        .alert(item: $pendingConfirmation) { action in
            Alert(
                title: Text("\(action.label) Quilibrium node?"),
                message: Text(
                    action == .stop
                        ? "This unloads only com.quilibrium.node. Your keys and stores are untouched."
                        : "This restarts only com.quilibrium.node. Your keys and stores are untouched."),
                primaryButton: action == .stop
                    ? .destructive(Text("Stop")) {
                        Task { await lifecycle.perform(action, monitor: monitor) }
                    }
                    : .default(Text("Restart")) {
                        Task { await lifecycle.perform(action, monitor: monitor) }
                    },
                secondaryButton: .cancel()
            )
        }
    }

    private var lifecycleSubtitle: String {
        switch lifecycle.passwordlessServiceAvailable {
        case true:
            "Isolated as _quilnode · passwordless controls"
        case false:
            "Secure service unavailable · administrator fallback"
        case nil:
            "Checking secure local controls…"
        }
    }

    private func lifecycleButton(
        _ action: NodeLifecycleAction,
        tint: Color,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                if lifecycle.activeAction == action {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: action.systemImage)
                }
                Text(action.label)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: compact ? .infinity : nil)
            .padding(.horizontal, compact ? 7 : 11)
            .frame(height: 31)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ServiceStatusPill: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let systemImage: String
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isReady ? theme.colors.success : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isReady ? "Alerts enabled" : "Enable Alerts")
        .accessibilityIdentifier("quilnode-alerts-button")
        .help(isReady ? "Local notifications are enabled" : "Enable local notifications")
    }
}
