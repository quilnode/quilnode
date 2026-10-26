import Foundation

/// Read-only fields emitted by `qclient node prover status`. Neither an active
/// allocation nor a running host establishes frame production or reward credit.
public struct WorkerExecutionObservation: Codable, Equatable, Sendable {
    public var state: String
    public var blocker: String?
    public var frame: UInt64?
    public var lastAdvanceAt: Date?
    public var observedAt: Date?
    public var readAt: Date
    public var recoveryPhase: String?
    public var recoveryFailures: Int?
    public var sealRecorded: Bool?

    public init(
        state: String, blocker: String? = nil, frame: UInt64? = nil,
        lastAdvanceAt: Date? = nil, observedAt: Date? = nil, readAt: Date,
        recoveryPhase: String? = nil, recoveryFailures: Int? = nil, sealRecorded: Bool? = nil
    ) {
        self.state = state
        self.blocker = blocker
        self.frame = frame
        self.lastAdvanceAt = lastAdvanceAt
        self.observedAt = observedAt
        self.readAt = readAt
        self.recoveryPhase = recoveryPhase
        self.recoveryFailures = recoveryFailures
        self.sealRecorded = sealRecorded
    }

    /// qclient marks source observations older than 30 seconds stale. Allow
    /// two normal 60-second app polling intervals before aging a cached read.
    public func isFresh(at now: Date) -> Bool {
        guard let observedAt else { return false }
        return state != "stale" && readAt.timeIntervalSince(observedAt) >= 0
            && readAt.timeIntervalSince(observedAt) <= 30
            && now.timeIntervalSince(readAt) >= 0 && now.timeIntervalSince(readAt) <= 120
    }
}
