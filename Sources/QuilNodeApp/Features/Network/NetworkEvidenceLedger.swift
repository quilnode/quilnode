import SwiftUI

struct NetworkEvidenceLedger: View {
    @Environment(\.quilTheme) private var theme

    let stages: [NetworkStagePresentation]
    @Binding var selectedStage: NetworkStageKind
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local evidence")
                        .font(.headline)
                    Text("Every conclusion below comes from this Mac or the local node.")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Button("Re-check all", systemImage: "arrow.clockwise", action: refresh)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(12)

            Divider().overlay(theme.colors.border.opacity(0.62))

            ForEach(stages) { stage in
                Button {
                    selectedStage = stage.kind
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: stage.kind.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(stage.state.tint(in: theme))
                            .frame(width: 24, height: 24)
                            .background(stage.state.tint(in: theme).opacity(0.10), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.evidenceSource)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.colors.primaryText)
                            Text(stage.detail)
                                .font(.caption2)
                                .foregroundStyle(theme.colors.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        NetworkStateBadge(state: stage.state, label: stage.status)

                        Text(stage.observedAt.map(NetworkFreshnessFormatter.string) ?? "Pending")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.colors.secondaryText)
                            .frame(width: 62, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(
                                selectedStage == stage.kind
                                    ? stage.state.tint(in: theme)
                                    : theme.colors.secondaryText
                            )
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 43)
                    .contentShape(Rectangle())
                    .background(
                        selectedStage == stage.kind
                            ? stage.state.tint(in: theme).opacity(0.055)
                            : Color.clear
                    )
                }
                .buttonStyle(QuilPressFeedbackButtonStyle())

                if stage.id != stages.last?.id {
                    Divider()
                        .overlay(theme.colors.border.opacity(0.45))
                        .padding(.leading, 46)
                }
            }
        }
        .controlSurface()
        .accessibilityElement(children: .contain)
    }
}
