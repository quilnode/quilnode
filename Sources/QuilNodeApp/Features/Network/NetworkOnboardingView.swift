import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkOnboardingView: View {
    @EnvironmentObject private var network: NetworkReadinessCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme

    var body: some View {
        OnboardingShell(stage: .network, height: 720) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        OnboardingSectionLabel(text: "Inbound readiness")
                        Text("Connect this node to inbound peers")
                            .font(
                                .system(
                                    size: 27 * theme.typography.scale,
                                    weight: .bold,
                                    design: theme.typography.displayDesign
                                ))
                        Text(
                            "The runtime and identity are ready. Your router is the remaining manual boundary; QuilNode uses only local evidence to confirm when inbound traffic actually arrives."
                        )
                        .font(.subheadline)
                        .foregroundStyle(theme.colors.secondaryText)
                    }

                    NetworkReadinessView(compactLayout: true)
                }
                .padding(24)
            }
        } footer: {
            HStack {
                Button("Finish later") {
                    network.remindLater()
                    dismiss()
                }
                Spacer()
                Button("I configured my router") {
                    network.markInitialGuideCompleted()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}
