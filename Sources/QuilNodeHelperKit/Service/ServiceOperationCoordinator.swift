import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

enum ServiceOperationState: String, Codable {
    case running, succeeded, failed
}

struct ServiceOperationRecord: Codable {
    var id: String
    var action: String
    var idempotencyKey: String?
    var state: ServiceOperationState
    var stage: PrivilegedOperationStage?
    var message: String
    var startedAt: Date
    var updatedAt: Date
}

typealias ServiceOperationReporter = @Sendable (PrivilegedOperationStage, String) -> Void

enum ServiceOperationError: Error, CustomStringConvertible {
    case busy
    case notFound

    var description: String {
        switch self {
        case .busy: "Another privileged node operation is already running."
        case .notFound: "The privileged operation record is unavailable."
        }
    }
}

/// Keeps long mutations owned by the root launch daemon rather than a UI
/// socket. The latest state is root-only and survives app relaunches.
final class ServiceOperationCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private let stateURL: URL
    private var current: ServiceOperationRecord?

    init(path: String) {
        stateURL = URL(fileURLWithPath: path)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? QuilNodeHelper.readSecureRegularFile(
            stateURL,
            maximumBytes: 64_000,
            requiredOwner: 0
        ),
            var recovered = try? decoder.decode(ServiceOperationRecord.self, from: data)
        {
            if recovered.state == .running {
                recovered.state = .failed
                recovered.message = "The privileged service restarted before the operation reported completion."
                recovered.updatedAt = Date()
            }
            current = recovered
            persist(recovered)
        }
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return current?.state == .running
    }

    func begin(
        action: String,
        idempotencyKey: String?,
        operation: @escaping @Sendable (@escaping ServiceOperationReporter) throws -> String
    ) throws -> ServiceOperationRecord {
        lock.lock()
        if let current, current.state == .running {
            lock.unlock()
            if current.action == action && current.idempotencyKey == idempotencyKey { return current }
            throw ServiceOperationError.busy
        }
        if let current,
            current.state == .succeeded,
            idempotencyKey != nil,
            current.action == action,
            current.idempotencyKey == idempotencyKey
        {
            lock.unlock()
            return current
        }

        let record = ServiceOperationRecord(
            id: UUID().uuidString,
            action: action,
            idempotencyKey: idempotencyKey,
            state: .running,
            stage: .accepted,
            message: "Privileged operation accepted by the local service.",
            startedAt: Date(),
            updatedAt: Date()
        )
        current = record
        persist(record)
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let reporter: ServiceOperationReporter = { [weak self] stage, message in
                self?.update(id: record.id, stage: stage, message: message)
            }
            do {
                self?.finish(id: record.id, state: .succeeded, message: try operation(reporter))
            } catch {
                self?.finish(id: record.id, state: .failed, message: "\(error)")
            }
        }
        return record
    }

    private func update(id: String, stage: PrivilegedOperationStage, message: String) {
        lock.lock()
        defer { lock.unlock() }
        guard var record = current, record.id == id, record.state == .running else { return }
        record.stage = stage
        record.message = message
        record.updatedAt = Date()
        current = record
        persist(record)
    }

    func record(id: String) throws -> ServiceOperationRecord {
        lock.lock()
        defer { lock.unlock() }
        guard let current, current.id == id else { throw ServiceOperationError.notFound }
        return current
    }

    /// Returns only an operation that is still in flight. Completed receipts
    /// remain addressable by ID, but must not pull a later app launch back into
    /// an already-finished onboarding flow.
    func runningRecord() throws -> ServiceOperationRecord {
        lock.lock()
        defer { lock.unlock() }
        guard let current, current.state == .running else {
            throw ServiceOperationError.notFound
        }
        return current
    }

    private func finish(id: String, state: ServiceOperationState, message: String) {
        lock.lock()
        defer { lock.unlock() }
        guard var record = current, record.id == id else { return }
        record.state = state
        if state == .succeeded { record.stage = .completed }
        record.message = message
        record.updatedAt = Date()
        current = record
        persist(record)
    }

    private func persist(_ record: ServiceOperationRecord) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(record) else { return }
        try? QuilNodeHelper.writeRootFile(data, to: stateURL.path, mode: 0o600)
    }
}
