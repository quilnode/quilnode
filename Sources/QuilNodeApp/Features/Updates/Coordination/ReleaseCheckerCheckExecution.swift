import Foundation

@MainActor
extension ReleaseChecker {
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

            var sourceInfo = validateApprovalMonotonicity(scannedSource)
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

    private func ensureCurrentCheck(_ generation: UUID) throws {
        guard checkGeneration == generation else { throw CancellationError() }
        try Task.checkCancellation()
    }

    private func updateReleaseCheckProgress(
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

    private func validateApprovalMonotonicity(_ source: SourceReleaseInfo) -> SourceReleaseInfo {
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
