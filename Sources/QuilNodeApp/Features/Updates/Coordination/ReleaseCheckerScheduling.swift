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
    func rollback() async {
        operation = .awaitingAuthorization
        lastError = nil
        let result = await Task.detached(priority: .userInitiated) {
            Self.runAuthorizedHelper(arguments: ["rollback"], durableOperation: true)
        }.value
        operation = .idle
        guard result.exitCode == 0 else {
            lastError =
                result.exitCode == -128
                ? "Administrator authorization was cancelled."
                : (result.output.isEmpty ? "Rollback failed." : result.output)
            return
        }
        lastMessage = result.output
        appendEvent(
            channel: "rollback", version: monitor?.snapshot.version ?? "previous", result: "installed",
            detail: result.output)
        try? await Task.sleep(for: .seconds(3))
        await monitor?.refresh(forceNodeInfo: true)
        shouldCheckAfterOperation = true
    }

    func rescheduleAutomaticChecks(runImmediately: Bool) {
        automationTask?.cancel()
        signalTask?.cancel()
        signalCheckTask?.cancel()
        signalGeneration = UUID()
        nextAutomaticCheck = nil
        nextSignalCheck = nil
        guard policy != .manual else {
            automaticCheckPending = false
            automaticReconciliationPending = false
            signalFailureCount = 0
            signalCheckError = nil
            return
        }

        automationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if runImmediately { self.requestScheduledAutomaticCheck() }
            while !Task.isCancelled {
                let next = Date().addingTimeInterval(self.checkInterval)
                self.nextAutomaticCheck = next
                do { try await Task.sleep(for: .seconds(self.checkInterval)) } catch { return }
                self.requestScheduledAutomaticCheck()
            }
        }
        scheduleNextSignalProbe()
    }

    /// Protocol metadata is operationally time-sensitive but is not release
    /// discovery. It owns a separate cache and task, so manual mode can monitor
    /// upcoming gates without blocking or changing node-update controls.
    func scheduleProtocolChecks() {
        protocolTask?.cancel()
        protocolTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.beginProtocolRefresh(refreshRemote: true)
            while !Task.isCancelled {
                let next = Date().addingTimeInterval(self.protocolCheckInterval)
                self.nextProtocolCheck = next
                do { try await Task.sleep(for: .seconds(self.protocolCheckInterval)) } catch { return }
                self.beginProtocolRefresh(refreshRemote: true)
            }
        }
    }

    func beginProtocolRefresh(refreshRemote: Bool) {
        guard protocolRefreshTask == nil else { return }
        let previous = protocolMilestones
        let repository = repositoryURL
        protocolRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.protocolRefreshTask = nil }
            do {
                let cacheURL = try Self.protocolBranchCacheURL()
                let worker = Task.detached(priority: .utility) {
                    let head =
                        if refreshRemote {
                            try Self.refreshProtocolHead(repositoryURL: repository, cacheURL: cacheURL)
                        } else {
                            try Self.highestCachedVersionHead(cacheURL: cacheURL)
                        }
                    let installed = Self.readInstalledBuild().build
                    return try Self.scanProtocolMilestones(
                        head: head,
                        installed: installed,
                        cacheURL: cacheURL,
                        previous: previous
                    )
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                try Task.checkCancellation()
                self.protocolMilestones = result
                self.protocolMilestoneError = nil
                self.persistProtocolMilestones()
                self.announceNewProtocolMilestones(previous: previous, current: result)
            } catch is CancellationError {
                return
            } catch {
                self.protocolMilestoneError =
                    "Milestone metadata could not refresh; cached data remains visible. \(error.localizedDescription)"
            }
        }
    }

    func announceNewProtocolMilestones(
        previous: [ProtocolMilestone],
        current: [ProtocolMilestone]
    ) {
        let prior = Dictionary(uniqueKeysWithValues: previous.map { ($0.symbol, $0.targetFrame) })
        let frame = max(monitor?.snapshot.frame ?? 0, monitor?.snapshot.lastReceivedFrame ?? 0)
        for milestone in current where prior[milestone.symbol] != milestone.targetFrame {
            services?.announceProtocolMilestone(milestone, currentFrame: frame)
        }
    }

    func beginCheck(origin: CheckOrigin) {
        guard checkTask == nil, operationTask == nil, operation == .idle else { return }
        if origin == .automatic {
            defaults.set(Date(), forKey: automaticAttemptKey)
        }
        let generation = UUID()
        checkGeneration = generation
        checkTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.checkGeneration == generation {
                    self.checkTask = nil
                    self.releaseCheckProgress = nil
                    if self.automaticCheckPending, self.operationTask == nil, self.operation == .idle {
                        self.automaticCheckPending = false
                        Task { @MainActor [weak self] in self?.requestScheduledAutomaticCheck() }
                    }
                }
            }
            let candidate = await self.check(origin: origin, generation: generation)
            guard self.checkGeneration == generation else { return }
            guard let candidate else { return }
            if origin == .automatic, self.automaticCandidateIsSuppressed(candidate) {
                self.lastMessage =
                    "Automatic retry is paused for this exact candidate after a failed attempt. A new upstream signal or a manual retry will clear the pause."
                return
            }
            if origin == .automatic {
                self.activeAutomaticCandidateID = candidate.identifier
                self.services?.announceAutomaticUpdateDetected(
                    candidateID: candidate.identifier,
                    channel: candidate.notificationChannel,
                    version: candidate.notificationVersion
                )
            }
            switch candidate {
            case let .signed(release):
                self.beginOperation { [weak self] in await self?.installSigned(release) }
            case let .approvedDevelopment(release):
                self.beginOperation { [weak self] in
                    await self?.installSource(
                        release.head,
                        channel: "approved-dev",
                        displayVersion: release.version
                    )
                }
            case let .rawDevelopment(head):
                self.beginOperation { [weak self] in
                    await self?.installSource(head, channel: "raw-dev", displayVersion: nil)
                }
            }
        }
    }

    func beginOperation(_ work: @escaping @MainActor () async -> Void) {
        guard operationTask == nil, operation == .idle else { return }
        UpdateActivityGuard.shared.setInstalling(true)
        operationTask = Task { @MainActor [weak self] in
            await work()
            guard let self else { return }
            self.operationTask = nil
            UpdateActivityGuard.shared.setInstalling(false)
            // A signal observed during a long build takes precedence over the
            // ordinary post-install refresh. The automatic reconciliation is
            // itself a full refresh and can safely act on a second candidate.
            if self.automaticCheckPending {
                self.automaticCheckPending = false
                self.shouldCheckAfterOperation = false
                self.requestScheduledAutomaticCheck()
            } else if self.shouldCheckAfterOperation {
                self.shouldCheckAfterOperation = false
                self.beginCheck(origin: .user)
            }
        }
    }

    func check(origin: CheckOrigin, generation: UUID) async -> AutomaticCandidate? {
        let previousSnapshot: UpdateCenterSnapshot? =
            if case let .available(snapshot) = state {
                snapshot
            } else {
                nil
            }
        if previousSnapshot == nil { state = .checking }
        lastError = nil
        lastMessage = nil
        let startedAt = Date()
        updateReleaseCheckProgress(
            .preparing,
            detail: "Starting bounded checks for official releases and source refs",
            startedAt: startedAt,
            generation: generation
        )

        do {
            async let signed = Self.fetchSignedRelease(endpoint: releaseEndpoint)
            async let installed = Self.readInstalledBuild()
            async let qclient = Self.readQClientUpdateInfo(endpoint: qclientReleaseEndpoint)

            updateReleaseCheckProgress(
                .branches,
                detail: "Fetching official branch heads and resolving the latest approval marker",
                startedAt: startedAt,
                generation: generation
            )
            let repository = repositoryURL
            let cacheURL = try Self.branchCacheURL()
            let sourceTask = Task.detached(priority: .utility) {
                try Self.scanOfficialBranches(repositoryURL: repository, cacheURL: cacheURL)
            }
            let scannedSource = try await withTaskCancellationHandler {
                try await sourceTask.value
            } onCancel: {
                sourceTask.cancel()
            }
            try ensureCurrentCheck(generation)

            updateReleaseCheckProgress(
                .releases,
                detail: "Checking signed node and qclient manifests",
                startedAt: startedAt,
                generation: generation
            )
            let (signedInfo, installedInfo, qclientInfo) = try await (signed, installed, qclient)
            try ensureCurrentCheck(generation)

            var sourceInfo = scannedSource
            sourceInfo = validateApprovalMonotonicity(sourceInfo)
            updateReleaseCheckProgress(
                .comparison,
                detail: "Comparing immutable commits with the build installed on this Mac",
                startedAt: startedAt,
                generation: generation
            )
            sourceInfo.commitsBehind = Self.commitsBehind(
                installed: installedInfo.build,
                head: sourceInfo.newestAnyBranch,
                cacheURL: cacheURL
            )
            try ensureCurrentCheck(generation)
            let snapshot = UpdateCenterSnapshot(
                signed: signedInfo,
                source: sourceInfo,
                installed: installedInfo,
                qclient: qclientInfo,
                checkedAt: Date()
            )
            state = .available(snapshot)
            if origin == .automatic {
                automaticReconciliationPending = false
                signalFailureCount = 0
            }
            defaults.set(snapshot.checkedAt, forKey: "node-update-last-check")
            let duration = max(snapshot.checkedAt.timeIntervalSince(startedAt), 0)
            lastCheckDuration = duration
            defaults.set(duration, forKey: checkDurationKey)

            guard origin == .automatic else { return nil }
            switch policy {
            case .manual:
                return nil
            case .signedStable:
                return Self.signedReleaseIsNewer(snapshot.signed, than: snapshot.installed.build)
                    ? .signed(snapshot.signed) : nil
            case .approvedDevelopment:
                guard let approved = snapshot.source.approvedDevelopment,
                    Self.approvedReleaseIsNewer(approved, than: snapshot.installed.build),
                    !Self.installed(snapshot.installed.build, matches: approved.head)
                else { return nil }
                return .approvedDevelopment(approved)
            case .bleedingEdge:
                return !Self.installed(snapshot.installed.build, matches: snapshot.source.newestAnyBranch)
                    ? .rawDevelopment(snapshot.source.newestAnyBranch) : nil
            }
        } catch is CancellationError {
            if checkGeneration == generation {
                state = previousSnapshot.map(State.available) ?? .notChecked
            }
            return nil
        } catch {
            guard checkGeneration == generation else { return nil }
            lastError = error.localizedDescription
            if origin == .automatic {
                automaticReconciliationPending = true
                signalFailureCount = min(signalFailureCount + 1, 4)
                scheduleNextSignalProbe()
            }
            state = previousSnapshot.map(State.available) ?? .failed(error.localizedDescription)
            return nil
        }
    }

    func ensureCurrentCheck(_ generation: UUID) throws {
        guard checkGeneration == generation else { throw CancellationError() }
        try Task.checkCancellation()
    }

    func updateReleaseCheckProgress(
        _ stage: ReleaseCheckProgress.Stage,
        detail: String,
        startedAt: Date,
        generation: UUID
    ) {
        guard checkGeneration == generation else { return }
        releaseCheckProgress = ReleaseCheckProgress(
            stage: stage,
            detail: detail,
            startedAt: startedAt
        )
    }

    func validateApprovalMonotonicity(_ source: SourceReleaseInfo) -> SourceReleaseInfo {
        guard let approved = source.approvedDevelopment else { return source }
        let keyRoot = "node-update-approved-marker-\(approved.branch)"
        let numberKey = "\(keyRoot)-number"
        let commitKey = "\(keyRoot)-commit"
        let knownNumber = defaults.object(forKey: numberKey) as? Int
        let knownCommit = defaults.string(forKey: commitKey)
        var validated = source

        if let knownNumber, approved.subpatch < knownNumber {
            validated.approvedDevelopment = nil
            validated.approvalIssue =
                "Rejected subpatch \(approved.subpatch): this Mac has already observed subpatch \(knownNumber) on \(approved.branch)."
            return validated
        }
        if let knownNumber, approved.subpatch == knownNumber,
            let knownCommit, knownCommit != approved.commit
        {
            validated.approvedDevelopment = nil
            validated.approvalIssue =
                "Rejected a changed commit for previously observed subpatch \(approved.subpatch). Approval numbers must be immutable."
            return validated
        }

        if knownNumber == nil || approved.subpatch > (knownNumber ?? 0) {
            defaults.set(approved.subpatch, forKey: numberKey)
            defaults.set(approved.commit, forKey: commitKey)
        }
        return validated
    }

}
