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
    @Published var preflight: InstallationPreflight?
    @Published var phase: FirstInstallPhase = .inspecting
    @Published var progress: NodeUpdateProgress?
    @Published var signedRelease: SignedReleaseInfo?
    @Published var qclientRelease: OfficialQClientRelease?
    @Published var identityPlan: FirstInstallIdentityPlan? = nil
    @Published var error: String?
    @Published var message: String?
    @Published var showsAuthorizationExplanation = false
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
            identityPlan: FirstInstallIdentityPlan? = nil,
            signedRelease: SignedReleaseInfo? = nil,
            qclientRelease: OfficialQClientRelease? = nil
        ) {
            preflight = previewPreflight
            self.phase = phase
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
            let upgrade = await Task.detached(priority: .userInitiated) {
                PrivilegedServiceClient.request(.upgradeService, timeout: 60)
            }.value
            if upgrade.exitCode == 0 {
                for _ in 0..<12 {
                    try? await Task.sleep(for: .milliseconds(500))
                    snapshot = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
                    if snapshot.secureServiceReady { break }
                }
            }
        }
        preflight = snapshot
        if snapshot.nodeInstalled && snapshot.secureServiceReady {
            phase = snapshot.qclientStatus?.isReady == true && snapshot.qclientCompatibleWithNode ? .complete : .ready
        } else {
            phase = snapshot.productionReady ? .ready : .failed
            if !snapshot.productionReady {
                error = "This Mac does not meet the production node requirements shown below."
            }
        }
        // qclient is a required local dependency, not an optional user update.
        // Existing installations migrate automatically through the already
        // authorized service; a visible setup screen remains as retry/error UI.
        if snapshot.nodeInstalled,
            snapshot.secureServiceReady,
            (snapshot.qclientStatus?.isReady != true || !snapshot.qclientCompatibleWithNode)
        {
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

    func authorizeExistingInstallation() async {
        guard requiresPlatformAuthorization, !isWorking else { return }
        phase = .authorizing
        error = nil
        message = nil
        let result = await Task.detached(priority: .userInitiated) {
            ReleaseChecker.authorizeServiceMigration(controllerUID: getuid())
        }.value
        if result.exitCode == -128 {
            phase = .ready
            message = "Authorization was cancelled. The running node, identity, and stores were not changed."
            return
        }
        guard result.exitCode == 0 else {
            phase = .failed
            error = result.output.isEmpty ? "The secure local service could not be upgraded." : result.output
            return
        }
        var refreshed = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
        for _ in 0..<10 where !refreshed.secureServiceReady {
            try? await Task.sleep(for: .milliseconds(500))
            refreshed = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
        }
        preflight = refreshed
        if refreshed.nodeInstalled && refreshed.secureServiceReady {
            let clientReady = refreshed.qclientStatus?.isReady == true && refreshed.qclientCompatibleWithNode
            phase = clientReady ? .complete : .ready
            message =
                clientReady
                ? "The secure local service is current. Supported platform operations are passwordless."
                : "The secure local service is current. QuilNode can now install the qclient that matches this node without another password prompt."
        } else {
            phase = .failed
            error = "macOS completed authorization, but the upgraded local service could not be verified."
        }
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
            let prepared = try await InstallationArtifactPreparation.stageFirstInstallation(
                startedAt: startedAt,
                progress: reporter
            )
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
            phase = .failed
            self.error = error.localizedDescription
        }
    }

    /// Adds or updates qclient for an existing node without stopping it. The
    /// already-authorized root service repeats all trust checks.
    func prepareAndInstallQClient() async {
        guard requiresQClientSetup, !isWorking else { return }
        error = nil
        message = nil
        let startedAt = Date()
        phase = .downloading
        do {
            let reporter: @Sendable (NodeUpdateProgress) -> Void = { [weak self] update in
                Task { @MainActor in
                    self?.phase = update.phase.localizedCaseInsensitiveContains("verif") ? .verifying : .downloading
                    self?.progress = update
                }
            }
            guard let preflightSnapshot = preflight else { return }
            let prepared = try await InstallationArtifactPreparation.stageQClient(
                for: preflightSnapshot,
                startedAt: startedAt,
                progress: reporter
            )
            qclientRelease = prepared.officialRelease
            phase = .installing
            progress = NodeUpdateProgress(
                workflow: .qclient,
                step: .switchRuntime,
                phase: "Handing off to local installer",
                detail: "The verified qclient is ready for the passwordless local service.",
                fraction: 0.90,
                startedAt: startedAt,
                isEstimate: false
            )
            let result = await Task.detached(priority: .userInitiated) {
                ReleaseChecker.runAuthorizedHelper(
                    arguments: ["qclient-install", prepared.manifestURL.path],
                    durableOperation: true,
                    allowsInteractiveAuthorization: prepared.allowsInteractiveAuthorization,
                    progress: { [weak self] update in
                        Task { @MainActor in
                            self?.progress = InstallationOperationPresentation.progress(
                                for: update,
                                workflow: .qclient,
                                startedAt: startedAt
                            )
                        }
                    }
                )
            }.value
            guard result.exitCode == 0 else {
                phase = .failed
                error = result.output
                return
            }
            let refreshed = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
            preflight = refreshed
            guard refreshed.qclientStatus?.isReady == true,
                refreshed.qclientCompatibleWithNode
            else {
                phase = .failed
                error =
                    "qclient installation returned successfully but its root-owned provenance could not be re-verified."
                return
            }
            phase = .complete
            let isSourceClient = refreshed.qclientStatus?.trust == .pinnedSource
            progress = NodeUpdateProgress(
                status: .succeeded,
                phase: isSourceClient ? "Matching qclient ready" : "Official qclient ready",
                detail: isSourceClient
                    ? "Built from the installed node commit, recorded separately, and installed without restarting the node"
                    : "Installed separately and signature-verified without restarting the node",
                fraction: 1, startedAt: startedAt, isEstimate: false
            )
            message = result.output
        } catch {
            phase = .failed
            self.error = error.localizedDescription
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
            phase = .failed
            error =
                authorization.output.isEmpty
                ? "The secure local service could not be authorized." : authorization.output
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
        let result = await Task.detached(priority: .userInitiated) {
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
            phase = .failed
            error = result.output.isEmpty ? "The first installation did not complete." : result.output
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
            phase = .failed
            error = "Installation returned successfully, but the local service or node could not be re-verified."
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
