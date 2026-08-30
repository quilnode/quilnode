import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
extension ReleaseChecker {
    private var signalBaselineKey: String { "node-update-signal-baseline-v1" }
    private var automaticFailureCandidateKey: String { "node-update-automatic-failure-candidate-v1" }

    func scheduleNextSignalProbe() {
        signalTask?.cancel()
        nextSignalCheck = nil
        guard policy != .manual else { return }

        let baseline = loadSignalBaseline(for: policy)
        if lastSignalCheck == nil {
            lastSignalCheck = baseline?.observedAt
        }
        let delay = UpdateDiscoveryPolicy.nextSignalDelay(
            consecutiveFailures: signalFailureCount,
            jitterUnit: Double.random(in: 0...1),
            lastSuccessfulProbeAt: baseline?.observedAt
        )
        nextSignalCheck = Date().addingTimeInterval(delay)
        signalTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.beginSignalCheck()
        }
    }

    func beginSignalCheck() {
        guard policy != .manual, signalCheckTask == nil else { return }
        let selectedPolicy = policy
        let baseline = loadSignalBaseline(for: selectedPolicy)
        let generation = UUID()
        signalGeneration = generation
        nextSignalCheck = nil

        signalCheckTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.signalGeneration == generation {
                    self.signalCheckTask = nil
                    self.scheduleNextSignalProbe()
                }
            }
            do {
                let endpoint = self.releaseEndpoint
                let repository = self.repositoryURL
                let probe = try await Task.detached(priority: .utility) {
                    try Self.probeUpdateSignal(
                        policy: selectedPolicy,
                        baseline: baseline,
                        releaseEndpoint: endpoint,
                        repositoryURL: repository
                    )
                }.value
                try Task.checkCancellation()
                guard self.signalGeneration == generation, self.policy == selectedPolicy else { return }

                let now = Date()
                self.lastSignalCheck = now
                self.signalCheckError = nil
                self.persistSignalBaseline(
                    UpdateSignalBaseline(
                        policy: selectedPolicy,
                        fingerprint: probe.fingerprint,
                        entityTag: probe.entityTag,
                        observedAt: now
                    )
                )
                if probe.result == .changed {
                    self.signalFailureCount = 0
                    self.automaticReconciliationPending = true
                    self.clearAutomaticFailureSuppression()
                }
                if probe.result == .changed || self.automaticReconciliationPending {
                    self.requestScheduledAutomaticCheck()
                }
            } catch is CancellationError {
                return
            } catch {
                guard self.signalGeneration == generation else { return }
                self.lastSignalCheck = Date()
                self.signalFailureCount = min(self.signalFailureCount + 1, 4)
                self.signalCheckError = error.localizedDescription
            }
        }
    }

    func requestScheduledAutomaticCheck() {
        guard policy != .manual else { return }
        guard checkTask == nil, operationTask == nil, operation == .idle else {
            automaticCheckPending = true
            return
        }
        automaticCheckPending = false
        beginCheck(origin: .automatic)
    }

    func automaticCandidateIsSuppressed(_ candidate: AutomaticCandidate) -> Bool {
        defaults.string(forKey: automaticFailureCandidateKey) == candidate.identifier
    }

    func rememberAutomaticFailure(for candidateID: String) {
        defaults.set(candidateID, forKey: automaticFailureCandidateKey)
    }

    func clearAutomaticFailureSuppression() {
        defaults.removeObject(forKey: automaticFailureCandidateKey)
    }

    func loadSignalBaseline(for policy: NodeUpdatePolicy) -> UpdateSignalBaseline? {
        guard let data = defaults.data(forKey: signalBaselineKey),
            let baseline = try? JSONDecoder().decode(UpdateSignalBaseline.self, from: data),
            baseline.policy == policy
        else { return nil }
        return baseline
    }

    func persistSignalBaseline(_ baseline: UpdateSignalBaseline) {
        guard let data = try? JSONEncoder().encode(baseline) else { return }
        defaults.set(data, forKey: signalBaselineKey)
    }
}
