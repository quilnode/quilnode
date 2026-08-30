import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct FirstInstallView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator
    @State private var showsSourceTools = false

    private var currentStage: OnboardingStage {
        if installer.phase == .failed, installer.progress != nil { return .runtime }
        return OnboardingStage.current(for: installer.phase)
    }

    var body: some View {
        OnboardingShell(stage: currentStage) {
            HStack(spacing: 0) {
                readinessWorkspace
                Divider().opacity(0.7)
                installFlightPlan
            }
        } footer: {
            HStack(spacing: 16) {
                Label(
                    "Identity files and stores stay untouched during installation.",
                    systemImage: "externaldrive.badge.checkmark"
                )
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                primaryAction
                    .frame(minWidth: 190)
            }
        }
        .sheet(isPresented: $installer.showsAuthorizationExplanation) {
            AuthorizationExplanationView()
                .environmentObject(installer)
                .quilThemed(theme)
        }
    }

    private var readinessWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 7) {
                    OnboardingSectionLabel(text: "Local readiness")
                    Text("Prepare this Mac for a trusted node runtime")
                        .font(
                            .system(
                                size: 27 * theme.typography.scale,
                                weight: .bold,
                                design: theme.typography.displayDesign
                            ))
                    Text(
                        "QuilNode verifies this Mac first, then acquires the latest signed Quilibrium release and installs it behind a restricted local service."
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let preflight = installer.preflight {
                    checkSection("This Mac", checks: preflight.hardware)
                    checkSection("Production path", checks: preflight.productionRequirements)

                    DisclosureGroup("Advanced source-build tools", isExpanded: $showsSourceTools) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(preflight.sourceToolchain) { check in
                                InstallCheckRow(check: check)
                            }
                            Text(
                                "These tools are needed only for an explicitly selected source build. They are not part of the signed-release installation path."
                            )
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                        }
                        .padding(.top, 9)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(13)
                    .controlSurface()
                } else {
                    QuilLoadingIndicator(
                        label: "Inspecting this Mac",
                        detail: "Checking hardware, storage, network access, and the local service boundary."
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }

    private var installFlightPlan: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    OnboardingSectionLabel(text: "Runtime flight plan")
                    Text(installer.signedRelease.map { "Quilibrium \($0.version)" } ?? "Latest signed release")
                        .font(.title2.bold())
                    Text("A bounded local sequence with trust checks before activation.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 11) {
                    OnboardingEvidenceRow(
                        systemImage: "arrow.down.circle",
                        title: "Acquire",
                        detail: "Fetch release artifacts only from Quilibrium's official release host."
                    )
                    OnboardingEvidenceRow(
                        systemImage: "checkmark.shield",
                        title: "Verify",
                        detail: "Require matching SHA3-256 digests and the Ed448 signer quorum."
                    )
                    OnboardingEvidenceRow(
                        systemImage: "person.badge.shield.checkmark",
                        title: "Install",
                        detail: "Create a restricted, non-login runtime managed by launchd."
                    )
                    OnboardingEvidenceRow(
                        systemImage: "waveform.path.ecg",
                        title: "Validate",
                        detail: "Confirm process, version, startup service, and loopback health."
                    )
                }
                .padding(14)
                .controlSurface()

                let runtimeProgress = OnboardingRuntimeProgress.firstInstall(phase: installer.phase)
                OnboardingProgressPanel(
                    progress: runtimeProgress,
                    detail: installer.progress?.detail ?? "No runtime changes begin until this Mac passes inspection.",
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
            .padding(22)
        }
        .frame(width: 326)
        .background(theme.colors.surface.opacity(0.42))
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch installer.phase {
        case .ready, .failed:
            Button {
                Task {
                    if installer.preflight?.productionReady == true {
                        await installer.prepareSignedInstallation()
                    } else {
                        await installer.retry()
                    }
                }
            } label: {
                Label(
                    installer.preflight?.productionReady == true ? "Acquire signed release" : "Run checks again",
                    systemImage: "arrow.right.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .awaitingAuthorization:
            Button("Review authorization") {
                installer.showsAuthorizationExplanation = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .complete:
            Label("Runtime verified", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(theme.colors.success)
        default:
            QuilLoadingIndicator(label: "Setup is working", compact: true)
        }
    }

    private func checkSection(_ title: String, checks: [InstallationCheck]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            OnboardingSectionLabel(text: title)
            ForEach(checks) { check in
                InstallCheckRow(check: check)
            }
        }
    }
}
