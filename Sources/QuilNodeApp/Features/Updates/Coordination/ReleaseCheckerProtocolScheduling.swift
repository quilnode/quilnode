import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
extension ReleaseChecker {
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
}
