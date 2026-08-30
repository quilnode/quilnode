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
    func progressReporter() -> @Sendable (NodeUpdateProgress) -> Void {
        { [weak self] incomingValue in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var value = incomingValue
                if let current = self.progress {
                    value.workflow = current.workflow
                    value.stepStartedAt =
                        current.step == value.step
                        ? current.stepStartedAt
                        : Date()
                }
                if let current = self.progress,
                    current.status == .running,
                    value.status == .running,
                    value.boundedFraction + 0.001 < current.boundedFraction
                {
                    return
                }
                if let current = self.progress, current.phase == value.phase {
                    value.phaseStartedAt = current.phaseStartedAt
                } else {
                    if let current = self.progress { self.recordCompletedPhase(current) }
                    value.phaseStartedAt = Date()
                }
                self.applyTimingEstimate(to: &value)
                self.progress = value
                self.updateOperationJournal(from: value)
            }
        }
    }

    func updateProgress(
        step: NodeUpdateStep? = nil,
        phase: String,
        detail: String,
        fraction: Double,
        completedUnits: Int? = nil,
        totalUnits: Int? = nil,
        isEstimate: Bool
    ) {
        guard var current = progress else { return }
        let nextStep = step ?? NodeUpdateStep.classify(phase: phase, workflow: current.workflow)
        if current.step != nextStep {
            current.step = nextStep
            current.stepStartedAt = Date()
        }
        if current.phase != phase {
            recordCompletedPhase(current)
            current.phaseStartedAt = Date()
        }
        current.phase = phase
        current.detail = detail
        current.fraction = fraction
        current.completedUnits = completedUnits
        current.totalUnits = totalUnits
        current.isEstimate = isEstimate
        current.updatedAt = Date()
        applyTimingEstimate(to: &current)
        progress = current
        updateOperationJournal(from: current)
    }

    func applyTimingEstimate(to progress: inout NodeUpdateProgress) {
        let saved = defaults.dictionary(forKey: phaseTimingKey)?[progress.phase] as? Double
        switch progress.phase {
        case "Compiling node":
            let warmCache =
                if let completed = progress.completedUnits, let total = progress.totalUnits, total > 0 {
                    Double(completed) / Double(total) > 0.75
                } else { false }
            progress.expectedPhaseDuration = warmCache ? 90 : (saved ?? 5.5 * 60)
            progress.remainingKnownDuration = 6.5 * 60
        case "Linking optimized node":
            progress.expectedPhaseDuration = saved ?? 6 * 60
            progress.remainingKnownDuration = 30
        case "Checking built binary":
            progress.expectedPhaseDuration = saved ?? 15
            progress.remainingKnownDuration = 25
        case "Compiling matching qclient":
            progress.expectedPhaseDuration = saved ?? 5 * 60
            progress.remainingKnownDuration = 25
        case "Reusing verified qclient":
            progress.expectedPhaseDuration = 3
            progress.remainingKnownDuration = 25
        case "Creating integrity metadata":
            progress.expectedPhaseDuration = saved ?? 20
            progress.remainingKnownDuration = 5
        case "Activating and health-checking":
            progress.expectedPhaseDuration = saved ?? 60
            progress.remainingKnownDuration = 0
        default:
            progress.expectedPhaseDuration = nil
            progress.remainingKnownDuration = 0
        }
    }

    func recordCompletedPhase(_ progress: NodeUpdateProgress) {
        guard
            [
                "Compiling node", "Linking optimized node", "Checking built binary",
                "Compiling matching qclient", "Creating integrity metadata",
                "Activating and health-checking",
            ].contains(progress.phase)
        else { return }
        let duration = Date().timeIntervalSince(progress.phaseStartedAt)
        guard duration >= 1, duration < 3 * 60 * 60 else { return }
        var timings = defaults.dictionary(forKey: phaseTimingKey) ?? [:]
        let previous = timings[progress.phase] as? Double
        timings[progress.phase] = previous.map { $0 * 0.7 + duration * 0.3 } ?? duration
        defaults.set(timings, forKey: phaseTimingKey)
    }

    func markProgressFailed(_ detail: String) {
        guard var current = progress else { return }
        current.status = .failed
        current.phase = "Update stopped"
        current.detail = detail
        current.updatedAt = Date()
        progress = current
        finishOperationJournal(status: .failed, detail: detail)
    }

    func appendEvent(
        channel: String,
        version: String,
        branch: String? = nil,
        commit: String? = nil,
        result: String,
        detail: String
    ) {
        history.insert(
            NodeUpdateEvent(
                id: UUID(), timestamp: Date(), channel: channel, version: version,
                branch: branch, commit: commit, result: result, detail: detail
            ),
            at: 0
        )
        history = Array(history.prefix(50))
        persistHistory()
    }

    func handleOperationFailure(
        _ error: Error,
        channel: String,
        version: String,
        branch: String? = nil,
        commit: String? = nil
    ) {
        if let candidateID = activeAutomaticCandidateID {
            rememberAutomaticFailure(for: candidateID)
            services?.announceAutomaticUpdateFailed(
                candidateID: candidateID,
                version: version
            )
            activeAutomaticCandidateID = nil
        }
        operation = .idle
        lastError = error.localizedDescription
        if stagedUpdate != nil, var current = progress {
            // Activation failure rolls the node back but does not invalidate a
            // verified staging bundle. Keep it immediately retryable without
            // forcing an app restart or an expensive rebuild.
            current.status = .ready
            current.phase = "Ready to retry"
            current.detail =
                "Activation did not complete; the verified build is preserved. \(error.localizedDescription)"
            current.fraction = max(current.boundedFraction, 0.97)
            current.updatedAt = Date()
            current.isEstimate = false
            progress = current
            updateOperationJournal(from: current)
            if var journal = operationJournal {
                journal.status = .staged
                journal.updatedAt = Date()
                operationJournal = journal
                persistOperationJournal()
            }
        } else {
            stagedUpdate = nil
            markProgressFailed(error.localizedDescription)
        }
        appendEvent(
            channel: channel,
            version: version,
            branch: branch,
            commit: commit,
            result: "failed",
            detail: error.localizedDescription
        )
    }

    func beginOperationJournal(
        channel: String,
        version: String,
        branch: String? = nil,
        commit: String? = nil
    ) {
        let current = progress
        stagedUpdate = nil
        operationJournal = UpdateOperationJournal(
            id: UUID(),
            channel: channel,
            version: version,
            branch: branch,
            commit: commit,
            phase: current?.phase ?? "Preparing update",
            detail: current?.detail ?? "Starting",
            fraction: current?.boundedFraction ?? 0,
            startedAt: current?.startedAt ?? Date(),
            updatedAt: Date(),
            status: .running,
            logPath: current?.logURL?.path,
            manifestPath: nil
        )
        persistOperationJournal()
    }

    func updateOperationJournal(from progress: NodeUpdateProgress) {
        guard var journal = operationJournal else { return }
        journal.phase = progress.phase
        journal.detail = progress.detail
        journal.fraction = progress.boundedFraction
        journal.updatedAt = Date()
        if let logURL = progress.logURL { journal.logPath = logURL.path }
        operationJournal = journal
        persistOperationJournal()
    }

    func rememberStagedUpdate(_ manifestURL: URL) {
        guard let manifest = try? Self.decodeManifest(at: manifestURL) else { return }
        stagedUpdate = StagedNodeUpdate(
            channel: manifest.channel,
            version: manifest.version,
            manifestURL: manifestURL
        )
        guard var journal = operationJournal else { return }
        journal.status = .staged
        journal.manifestPath = manifestURL.path
        journal.updatedAt = Date()
        operationJournal = journal
        persistOperationJournal()
    }

    func finishOperationJournal(status: UpdateOperationJournal.Status, detail: String) {
        guard var journal = operationJournal else { return }
        journal.status = status
        if status == .installed {
            journal.phase = "Update complete"
            journal.fraction = 1
        }
        journal.detail = detail
        journal.updatedAt = Date()
        operationJournal = journal
        persistOperationJournal()
    }
}
