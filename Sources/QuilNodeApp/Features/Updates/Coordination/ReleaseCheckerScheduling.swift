import Foundation

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

    func beginOperation(_ work: @escaping @MainActor () async -> Void) {
        guard operationTask == nil, operation == .idle else { return }
        operationTask = Task { @MainActor [weak self] in
            await work()
            guard let self else { return }
            self.operationTask = nil
            UpdateActivityGuard.shared.finishInstalling()
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
        UpdateActivityGuard.shared.beginInstalling { [weak self] in
            await self?.stopOperationForApplicationTermination()
        }
    }

    /// A dashboard window is disposable, but the application process owns the
    /// build worker. A deliberate Quit therefore cancels the worker and waits
    /// until its process tree reaches a safe point before macOS terminates the
    /// controller. Activation is already service-owned and is allowed to reach
    /// its durable result before the app exits.
    func stopOperationForApplicationTermination() async {
        guard let operationTask else { return }
        operationTask.cancel()
        await operationTask.value
    }

}
