import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct QClientSetupView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator

    private var isSourceRuntime: Bool {
        installer.preflight?.installedNodeBuild?.kind == .source
    }

    var body: some View {
        OnboardingShell(stage: .runtime) {
            HStack(alignment: .top, spacing: 0) {
                clientContext
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider().opacity(0.7)
                provenancePanel
                    .frame(width: 338)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(theme.colors.surface.opacity(0.42))
            }
        } footer: {
            HStack(spacing: 16) {
                Label("The node keeps running while qclient is prepared.", systemImage: "bolt.shield.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                Button {
                    Task { await installer.prepareAndInstallQClient() }
                } label: {
                    if installer.isWorking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Preparing qclient…")
                        }
                    } else {
                        Label("Verify & install", systemImage: "checkmark.shield.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(installer.isWorking)
            }
        }
    }

    private var clientContext: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OnboardingSectionLabel(text: "Runtime dependency")
                HStack(alignment: .top, spacing: 15) {
                    DashboardCircleIcon(systemImage: "terminal.fill", tint: theme.colors.accent, size: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Match qclient to the installed node")
                            .font(
                                .system(
                                    size: 27 * theme.typography.scale,
                                    weight: .bold,
                                    design: theme.typography.displayDesign
                                ))
                        Text("Needed for local balance reads and identity creation—not bundled into QuilNode.")
                            .font(.subheadline)
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                }

                Text(
                    isSourceRuntime
                        ? "This node is pinned to a source commit. QuilNode prepares qclient from that same immutable commit, records its provenance independently, and installs it to a root-owned versioned directory."
                        : "This node uses an official signed release. QuilNode acquires the corresponding official qclient, verifies its digest and signer quorum, and installs it to a root-owned versioned directory."
                )
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                let runtimeProgress = OnboardingRuntimeProgress.qclient(phase: installer.phase)
                OnboardingProgressPanel(
                    progress: runtimeProgress,
                    detail: installer.progress?.detail ?? "Resolving the client provenance that matches this runtime.",
                    fraction: installer.progress?.boundedFraction
                )

                if let error = installer.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.colors.danger)
                        .textSelection(.enabled)
                }
                if let message = installer.message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.colors.success)
                }
            }
            .padding(26)
        }
    }

    private var provenancePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingSectionLabel(text: "Independent provenance")
            Text(isSourceRuntime ? "Same immutable commit" : "Official signed artifact")
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 12) {
                OnboardingEvidenceRow(
                    systemImage: isSourceRuntime
                        ? "point.3.connected.trianglepath.dotted" : "network.badge.shield.half.filled",
                    title: isSourceRuntime ? "Commit identity" : "Official origin",
                    detail: isSourceRuntime
                        ? "Require the exact repository commit recorded for the installed node."
                        : "Download only from Quilibrium's official release host."
                )
                OnboardingEvidenceRow(
                    systemImage: "checkmark.seal.fill",
                    title: "Verify twice",
                    detail: "Check provenance before staging, then repeat the check inside the privileged boundary."
                )
                OnboardingEvidenceRow(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Record exact evidence",
                    detail: "Persist the filename, runtime version, signatures or commit, and SHA-256."
                )
                OnboardingEvidenceRow(
                    systemImage: "arrow.clockwise.circle",
                    title: "Install only when needed",
                    detail: "A compatible existing qclient is reused; this flow does not reinstall it on every update."
                )
            }
            .padding(15)
            .controlSurface()

            Label("No node restart", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.colors.success)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlSurface(tint: theme.colors.success)
            Spacer()
        }
        .padding(24)
    }
}
