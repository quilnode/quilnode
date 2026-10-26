import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// An existing node needs a client repair, not the first-install journey.
struct QClientSetupView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator
    @EnvironmentObject private var privacyMode: PrivacyModeController

    private var isSourceRuntime: Bool {
        installer.preflight?.installedNodeBuild?.kind == .source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                DashboardCircleIcon(systemImage: "terminal.fill", tint: theme.colors.accent, size: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Update wallet client").font(.title2.bold())
                    Text("Restore balance, rewards, and prover reads.")
                        .font(.subheadline)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Label("Node stays online", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colors.success)
            }
            .padding(22)

            Divider().opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        isSourceRuntime
                            ? "QuilNode builds the current qclient for your node's protocol. The first build can take several minutes; later builds reuse its cache."
                            : "QuilNode downloads the official qclient and verifies its signatures before installation."
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    if let error = installer.error {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Client update stopped", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                            Text(error).font(.callout).textSelection(.enabled)
                            Text("Your running node is unchanged. Retry below or return to the dashboard.")
                                .font(.caption)
                        }
                        .foregroundStyle(theme.colors.danger)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .controlSurface(tint: theme.colors.danger)
                    } else if installer.isWorking {
                        progress
                    } else if let message = installer.message {
                        Text(message).font(.callout).foregroundStyle(theme.colors.secondaryText)
                    }

                    if let logURL = installer.progress?.logURL {
                        InlineBuildLogView(
                            logURL: logURL,
                            isLive: installer.isWorking,
                            privacyModeEnabled: privacyMode.isEnabled,
                            compact: true
                        )
                        .id(logURL.path)
                    }

                    DisclosureGroup("Verification and privacy") {
                        Text(
                            isSourceRuntime
                                ? "The exact upstream commit and binary hash are recorded and rechecked by the local service. macOS asks for approval before installing a source-built client. Private keys remain with the isolated node account."
                                : "The official signature quorum and binary hash are checked before and during installation. Private keys remain with the isolated node account."
                        )
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    }
                    .font(.subheadline)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.5)
            HStack(spacing: 12) {
                if installer.isWorking {
                    if installer.cancelPreparation != nil {
                        Button("Cancel build") { installer.cancelPreparation?() }
                            .buttonStyle(.bordered)
                    }
                    Text("You can keep the node running while this finishes.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                } else {
                    Button("Back to dashboard") { installer.qclientSetupDeferred = true }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(installer.isWorking ? "Updating…" : (installer.error == nil ? "Update client" : "Try again")) {
                    Task { await installer.prepareAndInstallQClient(allowsInteractiveAuthorization: true) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(installer.isWorking)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .frame(width: 780, height: 620)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .foregroundStyle(theme.colors.primaryText)
    }

    private var progress: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 5) {
                Text(installer.progress?.phase ?? "Preparing client")
                    .font(.headline)
                Text(installer.progress?.detail ?? "Checking the current client for this node.")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let startedAt = installer.progress?.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(InstallationOperationPresentation.elapsedDescription(from: startedAt, to: context.date))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
        .padding(14)
        .controlSurface(tint: theme.colors.accent)
    }
}
