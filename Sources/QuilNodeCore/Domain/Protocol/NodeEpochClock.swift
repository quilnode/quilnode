import Foundation

/// A frame and its epoch always come from the same observation. The RPC epoch
/// can be older than the fast status stream, so mixing the two produces a
/// previous epoch with the next epoch's progress bar.
public struct NodeEpochClock: Equatable, Sendable {
    /// Matches qclient's fallback when the RPC reports a zero epoch length.
    public static let defaultLength: UInt64 = 720

    public let frame: UInt64
    public let length: UInt64

    public init(frame: UInt64, epochLength: UInt64) {
        self.frame = frame
        self.length = epochLength == 0 ? Self.defaultLength : epochLength
    }

    public var epoch: UInt64 { frame / length }
    public var progress: Double { Double(frame % length) / Double(length) }
    public var framesRemaining: UInt64 { length - frame % length }

    public var nextEpoch: UInt64? {
        let result = epoch.addingReportingOverflow(1)
        return result.overflow ? nil : result.partialValue
    }

    public var nextBoundary: UInt64? { boundary(after: frame) }

    public func boundary(after sourceFrame: UInt64) -> UInt64? {
        let epoch = sourceFrame / length
        let next = epoch.addingReportingOverflow(1)
        guard !next.overflow else { return nil }
        let result = next.partialValue.multipliedReportingOverflow(by: length)
        return result.overflow ? nil : result.partialValue
    }
}

extension NodeSnapshot {
    public var epochClock: NodeEpochClock {
        NodeEpochClock(frame: max(frame, lastReceivedFrame), epochLength: epochLength)
    }

    /// Three normal one-minute prover refreshes. Kept separate from fast frame
    /// freshness because an old allocation read must not become a missed window.
    public func hasFreshProverStatus(at now: Date = Date()) -> Bool {
        guard isRunning, proverStatusError == nil, let observedAt = proverStatusUpdatedAt else { return false }
        return (0...180).contains(now.timeIntervalSince(observedAt))
    }
}
