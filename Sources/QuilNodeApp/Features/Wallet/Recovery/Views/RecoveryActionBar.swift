import SwiftUI

struct RecoveryActionBar: View {
    @Environment(\.quilTheme) private var theme

    let presentation: RecoveryWorkspacePresentation
    let isWorking: Bool
    let export: () -> Void
    let protect: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            DashboardCircleIcon(
                systemImage: recommendationSymbol,
                tint: recommendationTint,
                size: 42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("RECOMMENDED NEXT STEP")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.65)
                    .foregroundStyle(theme.colors.secondaryText)
                Text(presentation.recommendation.title)
                    .font(.headline)
                Text(presentation.recommendation.detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)

            Button(action: performRecommendation) {
                if isWorking {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Working…")
                    }
                } else {
                    Label(presentation.recommendation.actionTitle, systemImage: recommendationSymbol)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking)
        }
        .padding(13)
        .frame(minHeight: 80)
        .controlSurface(tint: recommendationTint)
    }

    private func performRecommendation() {
        switch presentation.recommendation.kind {
        case .protectActive:
            protect()
        case .createSeparateBackup, .maintainCoverage:
            export()
        case .addIdentity:
            break
        }
    }

    private var recommendationSymbol: String {
        switch presentation.recommendation.kind {
        case .addIdentity: "plus.circle.fill"
        case .protectActive: "checkmark.shield.fill"
        case .createSeparateBackup, .maintainCoverage: "externaldrive.badge.checkmark"
        }
    }

    private var recommendationTint: Color {
        switch presentation.recommendation.kind {
        case .maintainCoverage: theme.colors.success
        case .addIdentity, .protectActive, .createSeparateBackup: theme.colors.warning
        }
    }
}
