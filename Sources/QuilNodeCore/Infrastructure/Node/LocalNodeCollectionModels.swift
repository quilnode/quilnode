import Foundation

public struct NodeProcessObservation: Equatable, Sendable {
    public var processID: Int32?
    public var observedAt: Date
    public var latency: TimeInterval

    public init(processID: Int32?, observedAt: Date, latency: TimeInterval) {
        self.processID = processID
        self.observedAt = observedAt
        self.latency = latency
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds)
            + TimeInterval(parts.attoseconds) / 1_000_000_000_000_000_000
    }
}

struct RewardCreditEvidence {
    let frame: UInt64
    let balanceSubunits: String
    let date: Date?
}

struct ProcessStats {
    var cpuPercent: Double?
    var cpuTimeSeconds: Double?
    var sampledAt: Date
    var memoryMB: Double?
    var elapsed: String?
}

struct CommandResult {
    var output: String
    var exitCode: Int32
}
