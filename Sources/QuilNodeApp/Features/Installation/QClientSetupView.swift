import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct QClientSetupView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                DashboardCircleIcon(systemImage: "terminal.fill", tint: theme.colors.accent, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Matching local client").font(.headline)
                    Text(
                        installer.preflight?.installedNodeBuild?.kind == .source
                            ? "Same source commit · independently recorded"
                            : "Official signed dependency · independently verified"
                    )
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
            }
            .padding(18)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                Text("Finish the local toolchain").font(.title.bold())
                Text(
                    installer.preflight?.installedNodeBuild?.kind == .source
                        ? "Your node is a pinned source build. QuilNode is preparing qclient from the exact same immutable repository commit for local balance reads and identity creation. Its commit and SHA-256 are recorded before it is installed to a root-owned versioned directory. It is not embedded in QuilNode and the node will not restart."
                        : "Your node is an official signed build. QuilNode now needs the official signed qclient for local balance reads and identity creation. It is downloaded from Quilibrium, verified with SHA3-256 and the Ed448 signer quorum, then installed to a root-owned versioned directory. It is not embedded in QuilNode and the node will not restart."
                )
                .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    AuthorizationScopeRow(
                        text: installer.preflight?.installedNodeBuild?.kind == .source
                            ? "Use only the official checkout whose commit matches the installed node"
                            : "Download only from releases.quilibrium.com")
                    AuthorizationScopeRow(
                        text: "Verify before installation, then verify again inside the privileged boundary")
                    AuthorizationScopeRow(
                        text: "Record exact release filename, runtime version, signatures, and SHA-256")
                    AuthorizationScopeRow(text: "Use the existing passwordless service—no administrator dialog")
                }
                if let progress = installer.progress {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(progress.phase).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int(progress.boundedFraction * 100))%")
                                .font(.caption.monospacedDigit())
                        }
                        ProgressView(value: progress.boundedFraction)
                        Text(progress.detail).font(.caption2).foregroundStyle(theme.colors.secondaryText)
                    }
                    .padding(13).controlSurface(tint: theme.colors.accent)
                }
                if let error = installer.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(theme.colors.danger).textSelection(.enabled)
                }
                Spacer()
                Button {
                    Task { await installer.prepareAndInstallQClient() }
                } label: {
                    if installer.isWorking {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Securing qclient…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Download, verify & install", systemImage: "checkmark.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(installer.isWorking)
            }
            .padding(30)
        }
        .frame(width: 650, height: 560)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}
