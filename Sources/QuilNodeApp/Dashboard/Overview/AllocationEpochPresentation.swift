import Foundation
import QuilNodeCore

/// Small, value-only-private explanations for the existing allocation cards.
/// Protocol timing lives in Core; no raw command or signing action is exposed.
struct AllocationEpochPresentation: Equatable {
    let label: String
    let value: String
    let explanation: String

    init?(allocation: ShardAllocation, clock: NodeEpochClock?) {
        guard let clock else { return nil }
        let timing = AllocationEpochTiming.evaluate(allocation, clock: clock)
        switch timing {
        case .confirmationOpens(let frame):
            label = "Confirm window · epoch"
            value = String(frame / clock.length)
            explanation = "Confirmation opens at frame \(frame). The node manages enrollment automatically."
        case .confirmationCloses(let frame):
            label = "Confirm before frame"
            value = String(frame)
            explanation =
                "The confirmation window is open until, but not including, frame \(frame). Keep the node online."
        case .activation(let frame):
            label = "Activation epoch"
            value = String(frame / clock.length)
            explanation =
                "Join confirmed. Activation is scheduled at frame \(frame); wait for the local registry to confirm it. This is not reward evidence."
        case .departure(let frame):
            label = "Departure epoch"
            value = String(frame / clock.length)
            explanation = "Leave confirmed. The allocation serves notice until frame \(frame)."
        case .renewalDue(let frame):
            label = "Renewal"
            value = "Due this epoch"
            explanation =
                "The allocation is registered for the current epoch. The node should renew before frame \(frame); no manual confirmation is normally required."
        case .registeredThrough(let epoch):
            label = "Registered through epoch"
            value = String(epoch)
            explanation = "The local registry includes the next epoch. Registration is not proof of reward credit."
        case .renewalMissed:
            label = "Renewal"
            value = "Not confirmed"
            explanation =
                "qclient reports an expired epoch registration. The node can renew it automatically. Refresh Diagnostics before considering a repair."
        case .windowMissed:
            label = "Confirmation"
            value = "Window missed"
            explanation =
                "The local registry reports an expired request. Inspect Diagnostics; a store wipe is not an enrollment repair."
        case .awaitingRegistry:
            label = "Epoch state"
            value = "Refreshing"
            explanation =
                "Frame progress has passed the allocation's last timing evidence. Waiting for a fresh registry read, not assuming success or failure."
        case .unavailable: return nil
        }
    }
}
