import Foundation

/// qclient's effective status is authoritative. Normalize spelling variants,
/// but do not reconstruct the raw on-chain status or turn unknown into active.
public enum AllocationStatus: Equatable, Sendable {
    case joining, active, paused, leaving, expiredJoin, expiredLeave
    case renewalMissed, rejected, kicked, historic, unknown

    public init(_ value: String) {
        let normalized = value.lowercased().filter { $0.isLetter }
        self =
            switch normalized {
            case "joining": .joining
            case "active": .active
            case "paused": .paused
            case "leaving": .leaving
            case "expiredjoin", "expiredjoining": .expiredJoin
            case "expiredleave", "expiredleaving": .expiredLeave
            case "reconfirm", "expiredepoch": .renewalMissed
            case "rejected": .rejected
            case "kicked": .kicked
            case "historic": .historic
            default: .unknown
            }
    }
}

/// Read-only explanations of the epoch-aligned .25 lifecycle. A confirmed join
/// remains Joining until the epoch after its confirmation. Confirmation windows
/// are half-open: [first frame of E+1, first frame of E+2).
/// Source: QuilibriumNetwork/monorepo, crates/quil-client/src/commands/node/prover/epoch.rs.
/// No state transition, registration or reward is inferred from a timer alone.
public enum AllocationEpochTiming: Equatable, Sendable {
    case confirmationOpens(frame: UInt64)
    case confirmationCloses(frame: UInt64)
    case activation(frame: UInt64)
    case departure(frame: UInt64)
    case renewalDue(frame: UInt64)
    case registeredThrough(epoch: UInt64)
    case renewalMissed
    case windowMissed
    case awaitingRegistry
    case unavailable

    public static func evaluate(_ allocation: ShardAllocation, clock: NodeEpochClock) -> Self {
        // Empty filters are global allocations and have no data-shard epoch
        // obligations or deferred activation.
        guard !allocation.filter.isEmpty else { return .unavailable }
        switch AllocationStatus(allocation.status) {
        case .joining:
            if let confirmed = allocation.confirmFrame, confirmed > 0 {
                return deferredBoundary(confirmed, clock: clock, departure: false)
            }
            return confirmWindow(allocation.joinFrame, clock: clock)
        case .leaving:
            if let confirmed = allocation.leaveConfirmFrame, confirmed > 0 {
                return deferredBoundary(confirmed, clock: clock, departure: true)
            }
            return confirmWindow(allocation.leaveFrame, clock: clock)
        case .active:
            guard let registered = allocation.registeredEpoch else { return .unavailable }
            // A newer fast frame is not proof that a slower registry read missed
            // renewal. Ask for fresh evidence; only qclient's explicit effective
            // status may report a missed renewal.
            if registered < clock.epoch { return .awaitingRegistry }
            if registered > clock.epoch { return .registeredThrough(epoch: registered) }
            return clock.nextBoundary.map { .renewalDue(frame: $0) } ?? .unavailable
        case .renewalMissed: return .renewalMissed
        case .expiredJoin: return .windowMissed
        case .expiredLeave:
            // A confirmed departure is normal, not a missed confirm window.
            return (allocation.leaveConfirmFrame ?? 0) > 0 ? .unavailable : .windowMissed
        default: return .unavailable
        }
    }

    private static func deferredBoundary(
        _ confirmed: UInt64, clock: NodeEpochClock, departure: Bool
    ) -> Self {
        guard confirmed <= clock.frame, let boundary = clock.boundary(after: confirmed) else {
            return .unavailable
        }
        guard clock.frame < boundary else { return .awaitingRegistry }
        return departure ? .departure(frame: boundary) : .activation(frame: boundary)
    }

    private static func confirmWindow(_ proposed: UInt64?, clock: NodeEpochClock) -> Self {
        // Zero is the upstream genesis/legacy sentinel, not a pending request.
        guard let proposed, proposed > 0, proposed <= clock.frame,
            let start = clock.boundary(after: proposed),
            let end = clock.boundary(after: start)
        else { return .unavailable }
        if clock.frame < start { return .confirmationOpens(frame: start) }
        if clock.frame < end { return .confirmationCloses(frame: end) }
        return .awaitingRegistry
    }
}
