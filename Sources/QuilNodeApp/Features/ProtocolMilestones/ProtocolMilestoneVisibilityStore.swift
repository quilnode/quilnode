import Combine
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Stores only presentation acknowledgements. Hiding an event never deletes
/// protocol evidence or removes it from Activity, and a changed target frame
/// gets a new event identifier so it becomes visible again automatically.
@MainActor
final class ProtocolMilestoneVisibilityStore: ObservableObject {
    @Published private(set) var dismissedOverviewEventIDs: Set<String>

    private let defaults: UserDefaults
    private let storageKey = "protocolMilestones.dismissedOverviewEventIDs.v1"
    private let maximumStoredEvents = 128

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dismissedOverviewEventIDs = Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    func dismissFromOverview(_ milestone: ProtocolMilestone) {
        dismissedOverviewEventIDs.insert(
            ProtocolMilestonePresentationPolicy.eventID(for: milestone)
        )
        persist()
    }

    func restoreToOverview(_ milestone: ProtocolMilestone) {
        dismissedOverviewEventIDs.remove(
            ProtocolMilestonePresentationPolicy.eventID(for: milestone)
        )
        persist()
    }

    func isDismissed(_ milestone: ProtocolMilestone) -> Bool {
        dismissedOverviewEventIDs.contains(
            ProtocolMilestonePresentationPolicy.eventID(for: milestone)
        )
    }

    private func persist() {
        let bounded = dismissedOverviewEventIDs.sorted().suffix(maximumStoredEvents)
        dismissedOverviewEventIDs = Set(bounded)
        defaults.set(Array(bounded), forKey: storageKey)
    }
}
