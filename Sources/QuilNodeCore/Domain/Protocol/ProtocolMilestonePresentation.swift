import Foundation

/// A protocol milestone is a time-bound event, not a permanent dashboard
/// status. This policy is the single source of truth for where an event belongs
/// after it is discovered, approached, crossed, acknowledged, or archived.
public enum ProtocolMilestonePresentationPolicy {
    /// Keep a completed event on Overview for one epoch. The frame-based window
    /// remains deterministic across app restarts, sleep, and clock changes.
    public static let completedOverviewRetentionFrames: UInt64 = 720

    public enum State: Equatable, Sendable {
        case upcoming
        case imminent
        case passedLocallyObserved
        case passedWithoutLocalEvidence
    }

    public struct OverviewSelection: Equatable, Sendable {
        public var milestone: ProtocolMilestone
        public var state: State
        public var isDismissible: Bool

        public init(milestone: ProtocolMilestone, state: State, isDismissible: Bool) {
            self.milestone = milestone
            self.state = state
            self.isDismissible = isDismissible
        }
    }

    public static func eventID(for milestone: ProtocolMilestone) -> String {
        "\(milestone.symbol)@\(milestone.targetFrame)"
    }

    public static func state(
        for milestone: ProtocolMilestone,
        currentFrame: UInt64,
        locallyObserved: Bool
    ) -> State {
        if currentFrame >= milestone.targetFrame {
            return locallyObserved ? .passedLocallyObserved : .passedWithoutLocalEvidence
        }
        return milestone.targetFrame - currentFrame <= completedOverviewRetentionFrames
            ? .imminent
            : .upcoming
    }

    public static func requiresAttention(_ milestone: ProtocolMilestone) -> Bool {
        milestone.installedSupport == .missing || milestone.hasSourceConflict
    }

    public static func overviewSelection(
        from milestones: [ProtocolMilestone],
        currentFrame: UInt64,
        observedMilestones: [String: UInt64] = [:],
        dismissedEventIDs: Set<String> = []
    ) -> OverviewSelection? {
        let candidates = milestones.compactMap { milestone -> OverviewSelection? in
            let attention = requiresAttention(milestone)
            if dismissedEventIDs.contains(eventID(for: milestone)), !attention {
                return nil
            }

            let passed = currentFrame >= milestone.targetFrame
            if passed,
                !attention,
                currentFrame - milestone.targetFrame > completedOverviewRetentionFrames
            {
                return nil
            }

            let locallyObserved = observedMilestones[milestone.symbol] == milestone.targetFrame
            return OverviewSelection(
                milestone: milestone,
                state: state(
                    for: milestone,
                    currentFrame: currentFrame,
                    locallyObserved: locallyObserved
                ),
                isDismissible: !attention
            )
        }

        return candidates.sorted { lhs, rhs in
            let lhsAttention = requiresAttention(lhs.milestone)
            let rhsAttention = requiresAttention(rhs.milestone)
            if lhsAttention != rhsAttention { return lhsAttention }

            let lhsFuture = lhs.milestone.targetFrame > currentFrame
            let rhsFuture = rhs.milestone.targetFrame > currentFrame
            if lhsFuture != rhsFuture { return lhsFuture }

            if lhsFuture {
                if lhs.milestone.targetFrame != rhs.milestone.targetFrame {
                    return lhs.milestone.targetFrame < rhs.milestone.targetFrame
                }
            } else if lhs.milestone.targetFrame != rhs.milestone.targetFrame {
                return lhs.milestone.targetFrame > rhs.milestone.targetFrame
            }
            return lhs.milestone.symbol < rhs.milestone.symbol
        }.first
    }

    public static func activityTimeline(_ milestones: [ProtocolMilestone]) -> [ProtocolMilestone] {
        milestones.sorted {
            if $0.targetFrame != $1.targetFrame { return $0.targetFrame > $1.targetFrame }
            return $0.symbol < $1.symbol
        }
    }
}
