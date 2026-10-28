import Foundation
import QuilNodeCore

extension ReleaseChecker {
    typealias SignalProbe =
        @Sendable (NodeUpdatePolicy, UpdateSignalBaseline?, URL, String) async throws -> UpdateSignalProbe

    nonisolated static func performSignalProbe(
        policy: NodeUpdatePolicy,
        baseline: UpdateSignalBaseline?,
        endpoint: URL,
        repository: String
    ) async throws -> UpdateSignalProbe {
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            return try probeUpdateSignal(
                policy: policy, baseline: baseline,
                releaseEndpoint: endpoint, repositoryURL: repository
            )
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
