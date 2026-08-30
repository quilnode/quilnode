import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkOnboardingView: View {
    @EnvironmentObject private var network: NetworkReadinessCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                DashboardCircleIcon(systemImage: "wifi.router.fill", tint: theme.colors.accent, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connect your node to inbound peers").font(.title2.bold())
                    Text("The node is installed. Your router is the final manual boundary.")
                        .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
            }
            .padding(22)
            Divider()

            ScrollView {
                NetworkReadinessView(compactLayout: true)
                    .padding(22)
            }

            Divider()
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
            }
            .padding(18)
        }
        .frame(width: 860, height: 700)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}

struct NetworkEvidenceTile: View {
    @Environment(\.quilTheme) private var theme
    let icon: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
    var privacyField: PrivacyField? = nil

    var body: some View {
        HStack(spacing: 11) {
            DashboardCircleIcon(systemImage: icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.subheadline.bold().monospacedDigit())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .controlSurface(tint: tint)
    }
}

struct RouterInstructionRow: View {
    @Environment(\.quilTheme) private var theme
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(String(number))
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 23, height: 23)
                .background(theme.colors.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
