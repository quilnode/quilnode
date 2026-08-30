import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
extension ReleaseChecker {
    func synchronizeAutomaticUpdateAuthorization(runImmediately: Bool) {
        policySynchronizationTask?.cancel()
        rescheduleAutomaticChecks(runImmediately: false)

        let selectedPolicy = policy
        let privilegedPolicy = selectedPolicy.privilegedAutomaticPolicy
        let generation = UUID()
        policySynchronizationGeneration = generation
        automaticAuthorizationState = .synchronizing

        policySynchronizationTask = Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) {
                PrivilegedServiceClient.configureAutomaticNodeUpdatePolicy(privilegedPolicy)
            }.value
            guard let self,
                !Task.isCancelled,
                self.policySynchronizationGeneration == generation,
                self.policy == selectedPolicy
            else { return }

            self.policySynchronizationTask = nil
            guard result.policy == privilegedPolicy else {
                self.automaticAuthorizationState = .failed(
                    result.error ?? "The secure local service did not accept the automatic update policy."
                )
                return
            }

            self.automaticAuthorizationState = selectedPolicy == .manual ? .inactive : .ready
            if selectedPolicy != .manual {
                self.rescheduleAutomaticChecks(runImmediately: runImmediately)
            }
        }
    }

    func retryAutomaticUpdateAuthorization() {
        synchronizeAutomaticUpdateAuthorization(runImmediately: false)
    }
}

extension NodeUpdatePolicy {
    var privilegedAutomaticPolicy: AutomaticNodeUpdatePolicy {
        switch self {
        case .manual, .signedStable:
            .signedStable
        case .approvedDevelopment:
            .approvedDevelopment
        case .bleedingEdge:
            .bleedingEdge
        }
    }
}
