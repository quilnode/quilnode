import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct PlatformAuthorizationView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator

    var body: some View {
        OnboardingShell(stage: .runtime) {
            HStack(alignment: .top, spacing: 0) {
                authorizationContext
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider().opacity(0.7)
                capabilityBoundary
                    .frame(width: 350)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(theme.colors.surface.opacity(0.42))
            }
        } footer: {
            HStack(spacing: 16) {
                Label("macOS handles the password; QuilNode cannot read or retain it.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                Button {
                    Task { await installer.authorizeExistingInstallation() }
                } label: {
                    if installer.isWorking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Waiting for macOS…")
                        }
                    } else {
                        Label("Continue to macOS", systemImage: "lock.open.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(installer.isWorking)
            }
        }
    }

    private var authorizationContext: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OnboardingSectionLabel(text: "One-time platform approval")
                HStack(alignment: .top, spacing: 15) {
                    DashboardCircleIcon(systemImage: "lock.shield.fill", tint: theme.colors.accent, size: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Authorize the durable local service")
                            .font(
                                .system(
                                    size: 27 * theme.typography.scale,
                                    weight: .bold,
                                    design: theme.typography.displayDesign
                                ))
                        Text("Your installed node, active identity, configuration, and stores remain in place.")
                            .font(.subheadline)
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                }

                Text(
                    "The existing helper predates QuilNode's current security boundary. One standard administrator confirmation replaces it with a code-signature-pinned service. Routine signed installs, updates, controls, and read-only inspection can then run without repeated password prompts."
                )
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 11) {
                    OnboardingEvidenceRow(
                        systemImage: "checkmark.seal.fill",
                        title: "Exact app identity",
                        detail:
                            "Requests must come from this code-signed QuilNode app and the controlling macOS account."
                    )
                    OnboardingEvidenceRow(
                        systemImage: "arrow.triangle.2.circlepath",
                        title: "Same-certificate upgrades",
                        detail: "Future service upgrades preserve this authorization while keeping the certificate pin."
                    )
                    OnboardingEvidenceRow(
                        systemImage: "hand.raised.fill",
                        title: "Fresh presence for key mutations",
                        detail:
                            "Operations that change or export identity material still request explicit macOS approval."
                    )
                }
                .padding(15)
                .controlSurface(tint: theme.colors.accent)

                if let error = installer.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.colors.danger)
                        .textSelection(.enabled)
                }
                if let message = installer.message {
                    Label(message, systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
            .padding(26)
        }
    }

    private var capabilityBoundary: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingSectionLabel(text: "Fixed capability boundary")
            Text("What the approval allows")
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 12) {
                AuthorizationScopeRow(text: "Maintain the restricted _quilnode service account")
                AuthorizationScopeRow(text: "Install verified runtime artifacts under fixed root-owned paths")
                AuthorizationScopeRow(text: "Control the launchd node service and inspect bounded local status")
                AuthorizationScopeRow(text: "Apply the required file-descriptor limit")
            }

            Divider().padding(.vertical, 2)

            Text("What it never grants")
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 10) {
                OnboardingEvidenceRow(
                    systemImage: "xmark.shield.fill",
                    title: "No broad sudo rule",
                    detail: "The service accepts a fixed local operation vocabulary only.",
                    tint: theme.colors.success
                )
                OnboardingEvidenceRow(
                    systemImage: "eye.slash.fill",
                    title: "No key bytes in the interface",
                    detail: "Private files are never returned to, displayed by, or transmitted from the GUI.",
                    tint: theme.colors.success
                )
                OnboardingEvidenceRow(
                    systemImage: "externaldrive.badge.xmark",
                    title: "No Full Disk Access",
                    detail: "QuilNode does not request a system-wide privacy grant.",
                    tint: theme.colors.success
                )
            }
            Spacer()
        }
        .padding(24)
    }
}
