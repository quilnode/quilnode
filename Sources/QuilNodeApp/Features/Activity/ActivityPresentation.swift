import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum ActivityTimeRange: String, CaseIterable, Identifiable {
    case oneHour
    case sixHours
    case oneDay
    case sevenDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour: "1h"
        case .sixHours: "6h"
        case .oneDay: "24h"
        case .sevenDays: "7d"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .oneHour: 60 * 60
        case .sixHours: 6 * 60 * 60
        case .oneDay: 24 * 60 * 60
        case .sevenDays: 7 * 24 * 60 * 60
        }
    }
}

enum ActivityMode: String, CaseIterable, Identifiable {
    case live
    case timeline
    case snapshots

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case proving
    case network
    case rewards
    case runtime
    case identity

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var category: NodeActivityCategory? {
        switch self {
        case .all: nil
        case .proving: .proving
        case .network: .network
        case .rewards: .rewards
        case .runtime: .runtime
        case .identity: .identity
        }
    }
}

struct ActivityIntervalPoint: Identifiable, Equatable {
    let timestamp: Date
    let framesPerMinute: Double
    let peers: Int

    var id: Date { timestamp }
}

struct ActivityNarrative: Equatable {
    let title: String
    let subtitle: String
}

enum ActivityJournalSection: String, CaseIterable, Identifiable {
    case network = "Network"
    case runtime = "Runtime"
    case router = "Router"
    case chain = "Chain"
    case proving = "Proving"

    var id: String { rawValue }
}

enum ActivityActionState: Equatable {
    case none
    case wait
    case review
    case startNode

    var label: String {
        switch self {
        case .none: "No action"
        case .wait: "Wait"
        case .review: "Review"
        case .startNode: "Start node"
        }
    }
}

enum ActivityPresentation {
    static func intervalPoints(from samples: [NodeActivitySample]) -> [ActivityIntervalPoint] {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard ordered.count > 1 else { return [] }

        // Thirty-second samples are intentionally precise for evidence, but a
        // literal line between every delta creates a barcode rather than a
        // useful trend. Aggregate into a bounded number of time buckets and
        // preserve real frame deltas, timestamps, and peer observations.
        let minimumBucketSampleCount = ordered.count < 6 ? 1 : 4
        let targetPointCount = 180
        let bucketSampleCount = max(
            minimumBucketSampleCount,
            Int(ceil(Double(ordered.count - 1) / Double(targetPointCount)))
        )

        var points: [ActivityIntervalPoint] = []
        var endIndex = bucketSampleCount
        while endIndex < ordered.count {
            let previous = ordered[endIndex - bucketSampleCount]
            let current = ordered[endIndex]
            let duration = current.timestamp.timeIntervalSince(previous.timestamp)
            if duration > 0, current.frame >= previous.frame {
                points.append(
                    ActivityIntervalPoint(
                        timestamp: current.timestamp,
                        framesPerMinute: Double(current.frame - previous.frame) / duration * 60,
                        peers: current.peers
                    ))
            }
            endIndex += bucketSampleCount
        }
        if points.last?.timestamp != ordered.last?.timestamp,
            let previous = ordered.dropLast().suffix(bucketSampleCount).first,
            let current = ordered.last
        {
            let duration = current.timestamp.timeIntervalSince(previous.timestamp)
            if duration > 0, current.frame >= previous.frame {
                points.append(
                    ActivityIntervalPoint(
                        timestamp: current.timestamp,
                        framesPerMinute: Double(current.frame - previous.frame) / duration * 60,
                        peers: current.peers
                    ))
            }
        }
        return points
    }

    static func narrative(
        summary: NodeActivitySummary,
        assessment: ChainProgressAssessment,
        sampleCount: Int
    ) -> ActivityNarrative {
        guard sampleCount >= 2 else {
            return ActivityNarrative(
                title: "Building a local activity history.",
                subtitle: "QuilNode is collecting private observations on this Mac."
            )
        }

        if assessment.state == .archiveRecovery {
            return ActivityNarrative(
                title: "Chain movement is paused while archives converge.",
                subtitle: "Local runtime and network evidence remain visible; restarting is not recommended."
            )
        }

        let peerSpan = (summary.peerMaximum ?? 0) - (summary.peerMinimum ?? 0)
        let stablePeerBand = peerSpan <= max(5, Int(Double(max(summary.peerMaximum ?? 1, 1)) * 0.12))

        if summary.frameDelta > 0, stablePeerBand {
            return ActivityNarrative(
                title: "Frames advanced steadily; peer mesh remained stable.",
                subtitle: "Meaningful changes and their impact on local node operations."
            )
        }
        if summary.frameDelta > 0 {
            return ActivityNarrative(
                title: "Frames advanced while the peer mesh shifted.",
                subtitle: "Review the annotated network changes against local chain progress."
            )
        }
        if (summary.continuity ?? 0) >= 0.98 {
            return ActivityNarrative(
                title: "The node stayed online while chain progress held.",
                subtitle: "The journal separates a shared network hold from a local runtime interruption."
            )
        }
        return ActivityNarrative(
            title: "Local runtime continuity changed in this window.",
            subtitle: "Select an event to inspect its source, freshness, and recommended action."
        )
    }

    static func nearestEvent(to timestamp: Date, in events: [NodeActivityEvent]) -> NodeActivityEvent? {
        events.min {
            abs($0.timestamp.timeIntervalSince(timestamp))
                < abs($1.timestamp.timeIntervalSince(timestamp))
        }
    }
}

extension NodeActivityEvent {
    var journalSection: ActivityJournalSection {
        switch kind {
        case .routerDropsIncreased: .router
        case .nodeStarted, .nodeStopped, .versionChanged: .runtime
        case .allocationChanged, .pendingJoinChanged, .activeShardChanged: .proving
        case .seniorityChanged, .rewardCredited: .chain
        case .peerMeshChanged, .inboundObserved, .archiveRecoveryStarted, .archiveRecoveryEnded: .network
        }
    }

    var evidenceSource: String {
        switch kind {
        case .nodeStarted, .nodeStopped: "Process observation"
        case .versionChanged: "Local node information"
        case .allocationChanged, .pendingJoinChanged, .activeShardChanged: "Local prover registry"
        case .peerMeshChanged: "Peer telemetry"
        case .inboundObserved: "Local traffic probe"
        case .seniorityChanged: "Local consensus state"
        case .rewardCredited: "Local prover state"
        case .routerDropsIncreased: "Router statistics"
        case .archiveRecoveryStarted, .archiveRecoveryEnded: "Chain progress evaluator"
        }
    }

    var whyItMatters: String {
        switch kind {
        case .nodeStarted: "Confirms the managed node returned and local observation resumed."
        case .nodeStopped: "Local proving and synchronization cannot continue while the process is stopped."
        case .versionChanged: "Pins later behavior to the exact node version that produced it."
        case .allocationChanged, .pendingJoinChanged, .activeShardChanged:
            "Records a real change in local proving participation rather than a repeated status sample."
        case .peerMeshChanged: "Shows a material movement in the locally observed peer mesh."
        case .inboundObserved: "Confirms remote traffic crossed the local network boundary."
        case .seniorityChanged: "Captures movement in the locally reported consensus seniority value."
        case .rewardCredited: "Provides local evidence that a new prover credit frame was observed."
        case .routerDropsIncreased: "Surfaces a meaningful rise in invalid or stale messages rejected locally."
        case .archiveRecoveryStarted:
            "Distinguishes shared archive convergence from a local failure, avoiding an unnecessary restart."
        case .archiveRecoveryEnded: "Confirms the locally observed archive-recovery hold has cleared."
        }
    }

    var actionState: ActivityActionState {
        switch kind {
        case .nodeStopped: .startNode
        case .routerDropsIncreased: .review
        case .archiveRecoveryStarted: .wait
        default: .none
        }
    }

    var privacyField: PrivacyField? {
        switch category {
        case .proving: .allocationCount
        case .network: .networkActivity
        case .identity: .seniority
        case .rewards: .quilBalance
        case .runtime: kind == .versionChanged ? nil : .localTimestamp
        }
    }
}
