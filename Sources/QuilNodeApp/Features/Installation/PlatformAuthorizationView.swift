import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct PlatformAuthorizationView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    ThemeAccentShape(shape: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("Q").font(.headline.weight(.black)).foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)
                Text("QuilNode security upgrade").font(.headline)
                Spacer()
            }
            .padding(18)
            Divider()

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    DashboardCircleIcon(systemImage: "lock.shield.fill", tint: theme.colors.accent, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Authorize the platform once").font(.title.bold())
                        Text("Your node is already installed and will be preserved.")
                            .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                    }
                }

                Text(
                    "The installed passwordless service predates QuilNode's current capability boundary. macOS needs one administrator confirmation to replace that root-owned service. Signed installs, updates, node controls, and read-only inspection then stay passwordless. Source builds and operations that change or export identity material retain a fresh macOS approval gate."
                )
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    AuthorizationScopeRow(
                        text: "Preserve the active identity, configuration, stores, and running node version")
                    AuthorizationScopeRow(
                        text: "Pin requests to this exact code-signed app and controlling macOS account")
                    AuthorizationScopeRow(
                        text: "Move all key-file byte access out of the GUI into a fixed local-only service vocabulary")
                    AuthorizationScopeRow(
                        text: "Store no password, reusable credential, broad sudo rule, or Full Disk Access grant")
                }

                Text(
                    "The standard macOS dialog appears after you click below. macOS handles the password; QuilNode cannot see or save it."
                )
                .font(.caption)
                .padding(14)
                .controlSurface(tint: theme.colors.success)

                if let error = installer.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(theme.colors.danger).textSelection(.enabled)
                }
                if let message = installer.message {
                    Label(message, systemImage: "info.circle.fill")
                        .font(.caption).foregroundStyle(theme.colors.secondaryText)
                }

                Button {
                    Task { await installer.authorizeExistingInstallation() }
                } label: {
                    if installer.isWorking {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Waiting for macOS…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Continue to macOS password", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(installer.isWorking)
            }
            .padding(30)
        }
        .frame(width: 650, height: 540)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}
