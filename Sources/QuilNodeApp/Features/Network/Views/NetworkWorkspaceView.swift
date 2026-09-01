import SwiftUI

struct NetworkWorkspaceView: View {
    @Environment(\.quilTheme) private var theme
    @AppStorage("networkWorkspaceMode") private var storedMode = NetworkWorkspaceMode.observatory.rawValue
    var forcedMode: NetworkWorkspaceMode? = nil

    private var mode: Binding<NetworkWorkspaceMode> {
        Binding(
            get: { forcedMode ?? NetworkWorkspaceMode(rawValue: storedMode) ?? .observatory },
            set: { if forcedMode == nil { storedMode = $0.rawValue } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    workspaceTitle
                    Spacer(minLength: 12)
                    modePicker.frame(width: 286)
                }
                VStack(alignment: .leading, spacing: 10) {
                    workspaceTitle
                    modePicker.frame(maxWidth: 360)
                }
            }

            switch mode.wrappedValue {
            case .observatory:
                NetworkObservatoryView()
            case .connectivity:
                NetworkReadinessView()
            }
        }
    }

    private var workspaceTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Network")
                .font(.system(size: 24 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign))
            Text("Explore locally observed network state or verify this Mac's inbound path.")
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private var modePicker: some View {
        Picker("Network workspace", selection: mode) {
            ForEach(NetworkWorkspaceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .accessibilityLabel("Network workspace")
        .disabled(forcedMode != nil)
    }
}
