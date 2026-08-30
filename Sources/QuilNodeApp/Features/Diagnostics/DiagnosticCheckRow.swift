import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticCheckRow: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    let check: NodeDiagnosticCheck
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRepair: (NodeDiagnosticRepair) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(tint.opacity(0.12))
                        if check.state == .checking {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.colors.primaryText)
                        Text(check.summary)
                            .font(.caption)
                            .foregroundStyle(theme.colors.secondaryText)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    Spacer(minLength: 8)
                    Text(stateLabel)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.10), in: Capsule())
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(theme.colors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(motion.selection, value: isExpanded)
                }
                .padding(13)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuilPressFeedbackButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .foregroundStyle(tint)
                        Text(check.evidence)
                            .font(.caption)
                            .foregroundStyle(theme.colors.secondaryText)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    if let observedAt = check.observedAt {
                        HStack(spacing: 0) {
                            Text("Observed ")
                            PrivacyProtectedText(
                                value: observedAt.formatted(date: .abbreviated, time: .standard),
                                field: .localTimestamp
                            )
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.colors.secondaryText)
                    }
                    if let repair = check.repair {
                        HStack {
                            Spacer()
                            Button(repairLabel(repair), systemImage: repairIcon(repair)) {
                                onRepair(repair)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.horizontal, 59)
                .padding(.bottom, 13)
                .transition(motion.revealTransition)
            }
        }
    }

    private var tint: Color {
        switch check.state {
        case .checking: theme.colors.info
        case .passed: theme.colors.success
        case .waiting: theme.colors.info
        case .advisory: theme.colors.warning
        case .failed: theme.colors.danger
        }
    }

    private var icon: String {
        switch check.state {
        case .checking: "ellipsis"
        case .passed: "checkmark"
        case .waiting: "hourglass"
        case .advisory: "exclamationmark"
        case .failed: "xmark"
        }
    }

    private var stateLabel: String {
        switch check.state {
        case .checking: "CHECKING"
        case .passed: "PASS"
        case .waiting: "WAITING"
        case .advisory: "REVIEW"
        case .failed: "ACTION"
        }
    }

    private func repairLabel(_ repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .refreshEvidence: "Run again"
        case .startNode: "Start node"
        case .restartNode: "Restart node"
        case .openNetwork: "Open Network"
        case .configureFirewall: "Configure firewall"
        case .openUpdates: "Open Updates"
        case .repairQClient: "Repair qclient"
        }
    }

    private func repairIcon(_ repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .refreshEvidence: "arrow.clockwise"
        case .startNode: "play.fill"
        case .restartNode: "arrow.clockwise"
        case .openNetwork: "network"
        case .configureFirewall: "shield.lefthalf.filled"
        case .openUpdates: "arrow.triangle.2.circlepath"
        case .repairQClient: "wrench.and.screwdriver"
        }
    }
}
