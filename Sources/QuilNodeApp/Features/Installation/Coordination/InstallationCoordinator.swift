import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
final class InstallationCoordinator: ObservableObject {
    // The coordinator is module-internal. Setters remain available only to its
    // focused coordination extensions, which keeps recovery logic out of this
    // already dense primary workflow file.
    @Published var preflight: InstallationPreflight? {
        didSet {
            if preflight?.secureServiceReady == true { hasVerifiedServiceThisRun = true }
        }
    }
    private(set) var hasVerifiedServiceThisRun = false
    @Published var platformSetupDeferred = false
    @Published var phase: FirstInstallPhase = .inspecting
    @Published var progress: NodeUpdateProgress?
    @Published var signedRelease: SignedReleaseInfo?
    @Published var qclientRelease: OfficialQClientRelease?
    @Published var identityPlan: FirstInstallIdentityPlan? = nil
    @Published var error: String?
    @Published var message: String?
    @Published var showsAuthorizationExplanation = false
    @Published var qclientSetupDeferred = false
    @Published var cancelPreparation: (() -> Void)?
    /// True only when this app session installed the node from scratch. It
    /// lets the first-run flow continue into network setup without forcing an
    /// onboarding sheet onto existing operators after an app upgrade.
    @Published var didCompleteInstallationThisRun = false

    private var stagedManifestURL: URL?
    var started = false

    init() {}

    #if DEBUG
        init(
            previewPreflight: InstallationPreflight,
            phase: FirstInstallPhase = .ready,
            progress: NodeUpdateProgress? = nil,
            identityPlan: FirstInstallIdentityPlan? = nil,
            signedRelease: SignedReleaseInfo? = nil,
            qclientRelease: OfficialQClientRelease? = nil
        ) {
            preflight = previewPreflight
            self.phase = phase
            self.progress = progress
            self.identityPlan = identityPlan
            self.signedRelease = signedRelease
            self.qclientRelease = qclientRelease
            started = true
        }
    #endif

    func selectIdentityPlan(_ plan: FirstInstallIdentityPlan) {
        guard !isWorking else { return }
        identityPlan = plan
    }

    func clearIdentityPlan() {
        identityPlan = nil
    }

    func refreshPreflight() async {
        phase = .inspecting
        error = nil
        var snapshot = await Task.detached(priority: .utility) {
            InstallationHostInspector.inspect()
        }.value
        if snapshot.nodeInstalled, !snapshot.secureServiceReady {
            _ = await Task.detached(priority: .userInitiated) {
                PrivilegedServiceClient.request(.upgradeService, timeout: 60)
            }.value
            // Older helpers can restart before delivering their response.
            // Verify the installed service even when that connection closes.
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(500))
                snapshot = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
                if snapshot.secureServiceReady { break }
            }
        }
        preflight = snapshot
        if snapshot.nodeInstalled && snapshot.secureServiceReady {
            phase = snapshot.qclientStatus?.isReady == true && snapshot.qclientCompatibleWithNode ? .complete : .ready
        } else {
            phase = snapshot.productionReady ? .ready : .failed
            if !snapshot.productionReady {
                markFailure("This Mac does not meet the production node requirements shown below.")
            }
        }
        // Never reinterpret a timeout as a missing client or launch an
        // interactive source-code trust prompt from a background check.
        if snapshot.canAutomaticallyInstallQClient {
            await prepareAndInstallQClient()
        }
    }

    /// Read-only host inspection for Diagnostics. Unlike first-run preflight,
    /// this never upgrades the privileged service and never installs qclient;
    /// a diagnostic scan must remain observational until the operator chooses
    /// a specific repair.
    func inspectForDiagnostics() async {
        guard !isWorking else { return }
        let snapshot = await Task.detached(priority: .utility) {
            InstallationHostInspector.inspect()
        }.value
        preflight = snapshot
    }

    func recheckServiceAuthorization() async {
        guard !isWorking else { return }
        preflight = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
    }

    /// Downloads and verifies an official signed release before privilege is
    /// requested. No node state, configuration, keyset, or store is touched.
    func prepareSignedInstallation() async {
        guard phase == .ready || phase == .failed,
            canPrepareSignedInstallation
        else { return }
        error = nil
        message = nil
        let startedAt = Date()
        phase = .downloading
        progress = NodeUpdateProgress(
            phase: "Discovering signed release",
            detail: "Reading the official Quilibrium release manifest",
            fraction: 0.01,
            startedAt: startedAt,
            isEstimate: false
        )
        do {
            let reporter: @Sendable (NodeUpdateProgress) -> Void = { [weak self] update in
                Task { @MainActor in
                    self?.phase = update.phase.localizedCaseInsensitiveContains("verif") ? .verifying : .downloading
                    self?.progress = update
                }
            }
            let prepared = try await runCancellablePreparation {
                try await InstallationArtifactPreparation.stageFirstInstallation(
                    startedAt: startedAt,
                    progress: reporter
                )
            }
            signedRelease = prepared.nodeRelease
            qclientRelease = prepared.qclientRelease
            stagedManifestURL = prepared.manifestURL
            phase = .awaitingAuthorization
            progress = NodeUpdateProgress(
                status: .ready,
                phase: "Verified and ready",
                detail: "Node and qclient SHA3-256 digests and signature quorums verified before installation",
                fraction: 1,
                startedAt: startedAt,
                isEstimate: false
            )
            showsAuthorizationExplanation = true
        } catch {
            markFailure(error.localizedDescription)
        }
    }

    /// The only administrator authorization in the lifecycle. It installs a
    /// code-signature-pinned local service; no password is stored or forwarded.
    func authorizeAndInstall() async {
        guard let manifest = stagedManifestURL, phase == .awaitingAuthorization else { return }
        let startedAt = progress?.startedAt ?? Date()
        showsAuthorizationExplanation = false
        phase = .authorizing
        error = nil
        progress = NodeUpdateProgress(
            phase: "Authorizing local service",
            detail: "Waiting for the standard macOS administrator confirmation",
            fraction: 0.05,
            startedAt: startedAt,
            isEstimate: false
        )

        let authorization = await Task.detached(priority: .userInitiated) {
            ReleaseChecker.authorizeServiceMigration(controllerUID: getuid())
        }.value
        if authorization.exitCode == -128 {
            phase = .awaitingAuthorization
            message = "Authorization was cancelled. The verified download is preserved and the node was not installed."
            showsAuthorizationExplanation = true
            return
        }
        guard authorization.exitCode == 0 else {
            markFailure(
                authorization.output.isEmpty
                    ? "The secure local service could not be authorized." : authorization.output
            )
            return
        }

        phase = .installing
        progress = NodeUpdateProgress(
            phase: "Installing signed node",
            detail: "The local service is creating the restricted runtime and launchd service",
            fraction: 0.76,
            startedAt: startedAt,
            isEstimate: false
        )
        let result = await Task.detached(priority: .userInitiated) { [weak self] in
            PrivilegedServiceClient.requestOperation(
                .install,
                manifestPath: manifest.path,
                timeout: 420,
                progress: { [weak self] update in
                    Task { @MainActor in
                        self?.progress = InstallationOperationPresentation.progress(
                            for: update,
                            workflow: .signedNode,
                            startedAt: startedAt
                        )
                    }
                }
            )
        }.value
        guard result.exitCode == 0 else {
            markFailure(result.output.isEmpty ? "The first installation did not complete." : result.output)
            return
        }

        phase = .validating
        progress = NodeUpdateProgress(
            phase: "Validating local node",
            detail: "Checking launchd, the node process, its version, and loopback metrics",
            fraction: 0.92,
            startedAt: startedAt,
            isEstimate: true
        )
        try? await Task.sleep(for: .seconds(2))
        let refreshed = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
        preflight = refreshed
        guard refreshed.nodeInstalled, refreshed.secureServiceReady else {
            markFailure(
                "Installation returned successfully, but the local service or node could not be re-verified."
            )
            return
        }
        phase = .complete
        didCompleteInstallationThisRun = true
        progress = NodeUpdateProgress(
            status: .succeeded,
            phase: "Node installed",
            detail: "Signed release, restricted runtime, launchd startup, and local health checks passed",
            fraction: 1,
            startedAt: startedAt,
            isEstimate: false
        )
        message = result.output
    }

    func retry() async {
        if stagedManifestURL != nil {
            phase = .awaitingAuthorization
            showsAuthorizationExplanation = true
        } else {
            await refreshPreflight()
        }
    }
}
