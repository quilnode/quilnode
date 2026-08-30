import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkReadinessHeader: View {
    @Environment(\.quilTheme) private var theme

    let presentation: NetworkWorkspacePresentation
    let isRefreshing: Bool
    let refresh: () -> Void
    let customizePorts: () -> Void
    let copyPlan: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            DashboardCircleIcon(
                systemImage: presentation.state.headerSymbol,
                tint: presentation.state.tint(in: theme),
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("NETWORK READINESS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(presentation.state.tint(in: theme))
                Text(presentation.title)
                    .font(.system(size: 23, weight: .bold, design: theme.typography.displayDesign))
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Label("Local evidence", systemImage: "lock.shield.fill")
                    if let observedAt = presentation.observedAt {
                        Text("•")
                        Text("Checked \(NetworkFreshnessFormatter.string(from: observedAt))")
                    }
                    let reviewCount = presentation.stages.filter {
                        $0.state == .review || $0.state == .blocked
                    }.count
                    if reviewCount > 0 {
                        Text("•")
                        Label("\(reviewCount) local review", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(theme.colors.warning)
                    }
                }
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
            }

            Spacer(minLength: 10)

            HStack(spacing: 7) {
                Button(action: refresh) {
                    if isRefreshing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Checking…")
                        }
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
                .buttonStyle(.bordered)

                Button("Customize ports", systemImage: "slider.horizontal.3", action: customizePorts)
                    .buttonStyle(.bordered)

                Button("Copy plan", systemImage: "doc.on.doc", action: copyPlan)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(16)
        .controlSurface(tint: presentation.state.tint(in: theme))
    }
}

struct NetworkReadinessPathView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    let stages: [NetworkStagePresentation]
    @Binding var selectedStage: NetworkStageKind

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                NetworkStageButton(
                    stage: stage,
                    selected: selectedStage == stage.kind
                ) {
                    selectedStage = stage.kind
                }

                if index < stages.count - 1 {
                    NetworkStageConnector(state: stages[index + 1].state)
                        .frame(width: 24)
                }
            }
        }
        .padding(10)
        .controlSurface()
        .animation(motion.selection, value: selectedStage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inbound readiness path")
    }
}

private struct NetworkStageButton: View {
    @Environment(\.quilTheme) private var theme

    let stage: NetworkStagePresentation
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    DashboardCircleIcon(
                        systemImage: stage.kind.symbol,
                        tint: stage.state.tint(in: theme),
                        size: 34
                    )
                    Text(stage.kind.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NetworkStateBadge(state: stage.state, label: stage.status)

                PrivacyProtectedText(value: stage.value, field: stage.privacyField)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 0)

                Text(stage.observedAt.map(NetworkFreshnessFormatter.string) ?? "Evidence pending")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
            .background(
                (selected ? theme.colors.surfaceElevated : theme.colors.surface)
                    .opacity(selected ? 0.94 : 0.60),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        selected
                            ? stage.state.tint(in: theme).opacity(0.92)
                            : theme.colors.border.opacity(0.62),
                        lineWidth: selected ? 1.5 : max(theme.metrics.borderWidth, 0.5)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: stage.state.tint(in: theme), cornerRadius: 11)
        .accessibilityLabel("\(stage.kind.title), \(stage.status), \(stage.value)")
        .accessibilityHint("Shows evidence for this stage")
    }
}

private struct NetworkStageConnector: View {
    @Environment(\.quilTheme) private var theme
    let state: NetworkStageState

    var body: some View {
        ZStack {
            Capsule()
                .fill(state.tint(in: theme).opacity(state == .waiting ? 0.32 : 0.74))
                .frame(height: 2)
            Image(systemName: state.connectorSymbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(state.tint(in: theme))
                .padding(3)
                .background(theme.colors.canvas, in: Circle())
        }
        .accessibilityHidden(true)
    }
}

struct NetworkStateBadge: View {
    @Environment(\.quilTheme) private var theme

    let state: NetworkStageState
    let label: String

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.55)
            .foregroundStyle(state.tint(in: theme))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(state.tint(in: theme).opacity(0.11), in: Capsule())
            .lineLimit(1)
    }
}

enum NetworkFreshnessFormatter {
    static func string(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension NetworkStageState {
    func tint(in theme: QuilTheme) -> Color {
        switch self {
        case .verified: theme.colors.success
        case .active: theme.colors.accentSecondary
        case .waiting: theme.colors.info
        case .review: theme.colors.warning
        case .blocked: theme.colors.danger
        }
    }

    var connectorSymbol: String {
        switch self {
        case .verified: "checkmark.circle.fill"
        case .active: "circle.dotted"
        case .waiting: "ellipsis.circle.fill"
        case .review: "exclamationmark.circle.fill"
        case .blocked: "xmark.circle.fill"
        }
    }
}

extension NetworkReadinessState {
    func tint(in theme: QuilTheme) -> Color {
        switch self {
        case .inboundVerified: theme.colors.success
        case .waitingForEvidence, .inspecting: theme.colors.info
        case .reviewRouter: theme.colors.warning
        case .localConfigurationIssue, .offline: theme.colors.danger
        }
    }

    var headerSymbol: String {
        switch self {
        case .inboundVerified: "checkmark.seal.fill"
        case .waitingForEvidence, .inspecting: "antenna.radiowaves.left.and.right"
        case .reviewRouter: "wifi.exclamationmark"
        case .localConfigurationIssue: "exclamationmark.arrow.triangle.2.circlepath"
        case .offline: "power"
        }
    }
}
