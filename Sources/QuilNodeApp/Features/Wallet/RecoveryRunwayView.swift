import SwiftUI

struct RecoveryRunwayView: View {
    @Environment(\.quilTheme) private var theme

    let stages: [RecoveryLayerPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery runway")
                    .font(.headline)
                Text("Three layers protect different failures.")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(12)

            Divider().overlay(theme.colors.border.opacity(0.58))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    runwayStage(stage, number: index + 1)
                    if index < stages.count - 1 {
                        runwayConnector(state: stages[index + 1].state)
                    }
                }
            }
            .padding(12)

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .foregroundStyle(theme.colors.info)
                Text("config.yml + keys.yml stay together")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 376, alignment: .topLeading)
        .controlSurface()
    }

    private func runwayStage(_ stage: RecoveryLayerPresentation, number: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(number))
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(stage.state.tint(in: theme), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: stage.layer.symbol)
                        .foregroundStyle(stage.state.tint(in: theme))
                    Text(stage.layer.title)
                        .font(.caption.weight(.semibold))
                }
                PrivacyProtectedText(value: stage.value, field: stage.privacyField)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                Text(stage.detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(stage.state.label.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.45)
                    .foregroundStyle(stage.state.tint(in: theme))
            }
        }
    }

    private func runwayConnector(state: RecoveryLayerState) -> some View {
        Rectangle()
            .fill(state.tint(in: theme).opacity(0.48))
            .frame(width: 1, height: 12)
            .padding(.leading, 10.5)
            .accessibilityHidden(true)
    }
}
