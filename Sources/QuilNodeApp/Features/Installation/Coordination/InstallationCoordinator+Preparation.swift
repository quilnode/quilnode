import Foundation

@MainActor
extension InstallationCoordinator {
    /// Runs app-owned acquisition or compilation away from the main actor and
    /// registers one safe cancellation point with the application lifecycle.
    /// Privileged activation is not covered here because the daemon owns and
    /// journals that phase independently across GUI relaunches.
    func runCancellablePreparation<Value: Sendable>(
        _ work: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let worker = Task.detached(priority: .utility, operation: work)
        let activityToken = UpdateActivityGuard.shared.beginInstalling {
            worker.cancel()
            _ = try? await worker.value
        }
        defer { UpdateActivityGuard.shared.finishInstalling(activityToken) }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
