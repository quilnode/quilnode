import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct FirstInstallView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator
    @State private var showsSourceTools = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                overview
                Divider()
                actionPanel
            }
        }
        .frame(width: 900, height: 620)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .sheet(isPresented: $installer.showsAuthorizationExplanation) {
            AuthorizationExplanationView()
                .environmentObject(installer)
                .quilThemed(theme)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                ThemeAccentShape(shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("Q").font(.title3.weight(.black)).foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("QuilNode setup").font(.headline)
                Text("Official signed release · local self-custody")
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
            SetupStep(
                index: 1, title: "Check",
                active: [.inspecting, .ready, .downloading, .verifying].contains(installer.phase))
            SetupStep(
                index: 2, title: "Authorize", active: [.awaitingAuthorization, .authorizing].contains(installer.phase))
            SetupStep(
                index: 3, title: "Install", active: [.installing, .validating, .complete].contains(installer.phase))
            SetupStep(index: 4, title: "Network", active: installer.phase == .complete)
        }
        .padding(18)
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Run Quilibrium safely on this Mac")
                        .font(
                            .system(
                                size: 30 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign
                            ))
                    Text(
                        "QuilNode checks the host, downloads the latest official Apple Silicon release, verifies its digest and signer quorum, installs a restricted launchd service, and proves the node is healthy before setup completes."
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 12) {
                    InstallPromise(
                        icon: "checkmark.seal.fill", title: "Signed release",
                        detail: "No compiler or package manager required")
                    InstallPromise(
                        icon: "key.horizontal.fill", title: "Self-custody",
                        detail: "The interface never opens private-key files")
                    InstallPromise(
                        icon: "lock.shield.fill", title: "One authorization",
                        detail: "No password is stored or replayed")
                }

                if let preflight = installer.preflight {
                    checkSection("THIS MAC", checks: preflight.hardware)
                    checkSection("PRODUCTION INSTALL", checks: preflight.productionRequirements)
                    DisclosureGroup("Advanced source-build toolchain", isExpanded: $showsSourceTools) {
                        VStack(spacing: 7) {
                            ForEach(preflight.sourceToolchain) { check in
                                InstallCheckRow(check: check)
                            }
                            Text(
                                "These packages are detected and provisioned only when you explicitly choose a source build later. They are intentionally excluded from the signed production path."
                            )
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .padding(.top, 4)
                        }
                        .padding(.top, 10)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .controlSurface()
                } else {
                    ProgressView("Inspecting this Mac…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INSTALL PLAN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(theme.colors.accent)
            Text(installer.signedRelease.map { "Quilibrium \($0.version)" } ?? "Latest signed release")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 10) {
                PlanRow(icon: "arrow.down.circle", text: "Download from releases.quilibrium.com")
                PlanRow(icon: "checkmark.shield", text: "Verify SHA3-256 and Ed448 quorum")
                PlanRow(icon: "person.badge.shield.checkmark", text: "Run as restricted _quilnode account")
                PlanRow(icon: "gearshape.2", text: "Start at login with launchd")
                PlanRow(icon: "wave.3.right", text: "Validate process, version, and local metrics")
                PlanRow(icon: "wifi.router", text: "Guide the one-time router setup")
            }

            if let progress = installer.progress {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(progress.phase).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(progress.boundedFraction * 100))%")
                            .font(.caption.monospacedDigit())
                    }
                    ProgressView(value: progress.boundedFraction)
                    Text(progress.detail)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .controlSurface(tint: installer.phase == .failed ? theme.colors.danger : theme.colors.accent)
            }

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
            Spacer()

            primaryAction
            Text(
                "No keyset or store is deleted during installation. Identity setup and verified recovery follow as a separate step."
            )
            .font(.caption2)
            .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(24)
        .frame(width: 330)
        .background(theme.colors.surface.opacity(0.68))
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
                    installer.preflight?.productionReady == true ? "Download & verify" : "Run checks again",
                    systemImage: "arrow.right.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        case .awaitingAuthorization:
            Button("Review one-time authorization") {
                installer.showsAuthorizationExplanation = true
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .frame(maxWidth: .infinity)
        case .complete:
            Label("Installation verified", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(theme.colors.success)
                .frame(maxWidth: .infinity)
        default:
            HStack {
                ProgressView()
                Text("Setup is working…")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func checkSection(_ title: String, checks: [InstallationCheck]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(theme.colors.secondaryText)
            ForEach(checks) { check in InstallCheckRow(check: check) }
        }
    }
}
