import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
extension ReleaseChecker {
    func installSigned(_ release: SignedReleaseInfo) async {
        guard operation == .idle else { return }
        let startedAt = Date()
        operation = .downloading(release.version)
        lastError = nil
        lastMessage = nil
        progress = NodeUpdateProgress(
            workflow: .signedNode,
            step: .selectCandidate,
            phase: "Preparing signed release",
            detail: "Creating an isolated staging area for \(release.version)",
            fraction: 0.02,
            startedAt: startedAt,
            isEstimate: false
        )
        beginOperationJournal(channel: "signed", version: release.version)
        do {
            let baseURL = releaseBase
            let report = progressReporter()
            let manifestURL = try await Task.detached(priority: .utility) {
                try Self.stageSignedRelease(
                    release, baseURL: baseURL, startedAt: startedAt, progress: report
                )
            }.value
            guard !Task.isCancelled else {
                operation = .idle
                rememberStagedUpdate(manifestURL)
                lastMessage = "The signed update is staged and can be installed when QuilNode is reopened."
                return
            }
            try await activate(manifestURL: manifestURL)
        } catch {
            handleOperationFailure(error, channel: "signed", version: release.version)
        }
    }

    func installQClient(_ release: OfficialQClientRelease) async {
        guard operation == .idle else { return }
        let startedAt = Date()
        operation = .downloading("qclient \(release.releaseVersion)")
        lastError = nil
        lastMessage = nil
        progress = NodeUpdateProgress(
            workflow: .qclient,
            step: .selectCandidate,
            phase: "Preparing official qclient",
            detail: "Creating an isolated qclient staging area",
            fraction: 0.02, startedAt: startedAt, isEstimate: false
        )
        do {
            let report = progressReporter()
            let baseURL = releaseBase
            let manifest = try await Task.detached(priority: .utility) {
                try Self.stageQClientRelease(
                    release, baseURL: baseURL, startedAt: startedAt, progress: report
                )
            }.value
            operation = .activating
            let result = await Task.detached(priority: .userInitiated) {
                Self.runAuthorizedHelper(
                    arguments: ["qclient-install", manifest.path],
                    durableOperation: true
                )
            }.value
            guard result.exitCode == 0 else { throw UpdateCenterError.activationFailed(result.output) }
            let status = PrivilegedServiceClient.readQClientStatus(timeout: 10)
            guard status.status?.isReady == true else {
                throw UpdateCenterError.activationFailed(status.error ?? "qclient provenance could not be re-verified")
            }
            operation = .idle
            progress = NodeUpdateProgress(
                status: .succeeded, workflow: .qclient, step: .switchRuntime,
                phase: "qclient installed",
                detail:
                    "Official qclient \(release.releaseVersion) is root-owned and verified. The node was not restarted.",
                fraction: 1, startedAt: startedAt, isEstimate: false
            )
            lastMessage = result.output
            shouldCheckAfterOperation = true
        } catch {
            operation = .idle
            progress = NodeUpdateProgress(
                status: .failed, workflow: .qclient,
                step: progress?.step ?? .selectCandidate,
                phase: "qclient update failed",
                detail: error.localizedDescription, fraction: 1,
                startedAt: startedAt, isEstimate: false
            )
            lastError = error.localizedDescription
        }
    }

    func installSource(
        _ head: GitBranchHead,
        channel: String,
        displayVersion: String?
    ) async {
        guard operation == .idle else { return }
        let startedAt = Date()
        let version = displayVersion ?? head.version ?? "source"
        operation = .building(branch: head.name, commit: String(head.commit.prefix(8)))
        lastError = nil
        lastMessage = nil
        progress = NodeUpdateProgress(
            workflow: .sourceNode,
            step: .selectCandidate,
            phase: "Preparing source build",
            detail: "Pinning \(head.name) at \(head.commit.prefix(8))",
            fraction: 0.01,
            startedAt: startedAt,
            isEstimate: false
        )
        beginOperationJournal(
            channel: channel,
            version: version,
            branch: head.name,
            commit: head.commit
        )
        do {
            let repository = repositoryURL
            let existingQClient = PrivilegedServiceClient.readQClientStatus(timeout: 8).status
            let report = progressReporter()
            let manifestURL = try await Task.detached(priority: .userInitiated) {
                try Self.stageSourceBuild(
                    head: head, repositoryURL: repository,
                    startedAt: startedAt,
                    channel: channel,
                    displayVersion: displayVersion,
                    existingQClient: existingQClient,
                    progress: report
                )
            }.value
            guard !Task.isCancelled else {
                operation = .idle
                rememberStagedUpdate(manifestURL)
                lastMessage = "The source build is staged and can be installed when QuilNode is reopened."
                return
            }
            try await activate(manifestURL: manifestURL)
        } catch {
            handleOperationFailure(
                error,
                channel: channel,
                version: version,
                branch: head.name,
                commit: head.commit
            )
        }
    }

    func activate(manifestURL: URL) async throws {
        rememberStagedUpdate(manifestURL)
        operation = .awaitingAuthorization
        updateProgress(
            step: .switchRuntime,
            phase: "Ready to install",
            detail:
                "Candidate verified and sealed while the current node stayed online. The secure service will create a rollback point, switch runtimes, restart briefly, and validate local health.",
            fraction: 0.97,
            isEstimate: false
        )
        let result = await Task.detached(priority: .userInitiated) {
            Self.runAuthorizedActivation(manifestURL: manifestURL)
        }.value
        if result.exitCode == -128 {
            operation = .idle
            activeAutomaticCandidateID = nil
            lastMessage = "Update is staged. Administrator authorization was cancelled."
            updateProgress(
                step: .switchRuntime,
                phase: "Ready to install",
                detail: "The verified build is preserved. Choose Install staged update whenever you are ready.",
                fraction: 0.97,
                isEstimate: false
            )
            if var current = progress {
                current.status = .ready
                progress = current
            }
            return
        }
        if result.exitCode == 75 {
            operation = .idle
            lastMessage = result.output
            updateProgress(
                step: .switchRuntime,
                phase: "Activation continues in background",
                detail:
                    "The root-owned service still owns this update. Reopen Update Center to reconcile its final result safely.",
                fraction: 0.99,
                isEstimate: true
            )
            return
        }
        guard result.exitCode == 0 else {
            operation = .idle
            if result.output.contains("automatic restoration could not be verified") {
                throw UpdateCenterError.activationRecoveryUnverified(result.output)
            }
            throw UpdateCenterError.activationFailed(result.output)
        }

        operation = .activating
        updateProgress(
            step: .switchRuntime,
            phase: "Activating and health-checking",
            detail:
                "Creating a rollback point, switching atomically, restarting the node, and checking its version and local metrics for up to 180 seconds.",
            fraction: 0.99,
            isEstimate: true
        )
        let manifest = try Self.decodeManifest(at: manifestURL)
        let currentLogURL = progress?.logURL
        let retainedLogURL = await Task.detached(priority: .utility) {
            Self.retainBuildLog(currentLogURL, manifest: manifest)
        }.value
        appendEvent(
            channel: manifest.channel,
            version: manifest.version,
            branch: manifest.branch,
            commit: manifest.commit,
            result: "installed",
            detail: result.output.isEmpty ? "Activation and health check passed." : result.output
        )
        lastMessage = "Installed \(manifest.version). Node health check passed."
        if let candidateID = activeAutomaticCandidateID {
            clearAutomaticFailureSuppression()
            services?.announceAutomaticUpdateSucceeded(
                candidateID: candidateID,
                version: manifest.version
            )
            activeAutomaticCandidateID = nil
        }
        stagedUpdate = nil
        finishOperationJournal(status: .installed, detail: lastMessage ?? "Installed")
        if var current = progress {
            current.status = .succeeded
            current.step = .healthGate
            current.phase = "Update complete"
            current.detail =
                "Installed \(manifest.version). The node restarted successfully and passed version and local metrics checks."
            current.fraction = 1
            current.updatedAt = Date()
            current.isEstimate = false
            current.logURL = retainedLogURL
            progress = current
        }
        try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent())
        try? await Task.sleep(for: .seconds(3))
        await monitor?.refresh(forceNodeInfo: true)
        operation = .idle
        shouldCheckAfterOperation = true
    }

}
