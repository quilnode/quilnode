import Foundation

/// Produces operator-facing changes from local observations. Raw samples stay
/// available for charts; the event stream intentionally suppresses routine
/// 30-second samples so Activity reads like a journal rather than a log dump.
public enum NodeActivityAnalyzer {
    public static func summarize(_ samples: [NodeActivitySample]) -> NodeActivitySummary {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard let first = ordered.first, let last = ordered.last else {
            return NodeActivitySummary()
        }

        let duration = max(last.timestamp.timeIntervalSince(first.timestamp), 0)
        let frameDelta = last.frame >= first.frame ? last.frame - first.frame : 0
        let rate = duration > 0 ? Double(frameDelta) / duration * 60 : nil
        let peers = ordered.map(\.peers)
        let runningCount = ordered.filter(\.isRunning).count
        let continuity = ordered.isEmpty ? nil : Double(runningCount) / Double(ordered.count)
        let lifecycleChanges = zip(ordered, ordered.dropFirst()).reduce(into: 0) { total, pair in
            if pair.0.pendingJoins != pair.1.pendingJoins
                || pair.0.activeShards != pair.1.activeShards
                || pair.0.totalAllocations != pair.1.totalAllocations
            {
                total += 1
            }
        }
        let eventCount = events(from: ordered).count

        return NodeActivitySummary(
            duration: duration,
            frameDelta: frameDelta,
            averageFramesPerMinute: rate,
            peerMinimum: peers.min(),
            peerMaximum: peers.max(),
            peerDelta: last.peers - first.peers,
            continuity: continuity,
            lifecycleChanges: lifecycleChanges,
            eventCount: eventCount
        )
    }

    public static func events(from samples: [NodeActivitySample]) -> [NodeActivityEvent] {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard ordered.count > 1 else { return [] }
        var output: [NodeActivityEvent] = []

        for (previous, current) in zip(ordered, ordered.dropFirst()) {
            if previous.isRunning != current.isRunning {
                output.append(
                    event(
                        at: current.timestamp,
                        category: .runtime,
                        kind: current.isRunning ? .nodeStarted : .nodeStopped,
                        title: current.isRunning ? "Node process started" : "Node process stopped",
                        detail: current.isRunning
                            ? "Local process evidence returned." : "Local process evidence disappeared."
                    ))
            }
            if let old = previous.version, let new = current.version, old != new {
                output.append(
                    event(
                        at: current.timestamp,
                        category: .runtime,
                        kind: .versionChanged,
                        title: "Node version changed",
                        detail: "\(old) → \(new)"
                    ))
            }
            if previous.chainProgressState != current.chainProgressState {
                if current.chainProgressState == .archiveRecovery {
                    output.append(
                        event(
                            at: current.timestamp,
                            category: .network,
                            kind: .archiveRecoveryStarted,
                            title: "Archive recovery detected",
                            detail:
                                "Reachable archives matched the local head while shared state convergence retries remained active. No local restart was recommended."
                        ))
                } else if previous.chainProgressState == .archiveRecovery {
                    output.append(
                        event(
                            at: current.timestamp,
                            category: .network,
                            kind: .archiveRecoveryEnded,
                            title: "Archive recovery cleared",
                            detail: "Local evidence no longer indicates a shared archive recovery hold."
                        ))
                }
            }
            appendCountChange(
                old: previous.totalAllocations,
                new: current.totalAllocations,
                at: current.timestamp,
                category: .proving,
                kind: .allocationChanged,
                title: "Allocation count changed",
                noun: "allocations",
                to: &output
            )
            appendCountChange(
                old: previous.pendingJoins,
                new: current.pendingJoins,
                at: current.timestamp,
                category: .proving,
                kind: .pendingJoinChanged,
                title: "Joining state changed",
                noun: "allocations joining",
                to: &output
            )
            appendCountChange(
                old: previous.activeShards,
                new: current.activeShards,
                at: current.timestamp,
                category: .proving,
                kind: .activeShardChanged,
                title: "Active allocation count changed",
                noun: "active allocations",
                to: &output
            )

            let peerThreshold = max(5, Int((Double(max(previous.peers, 1)) * 0.20).rounded(.up)))
            if abs(current.peers - previous.peers) >= peerThreshold {
                output.append(
                    event(
                        at: current.timestamp,
                        category: .network,
                        kind: .peerMeshChanged,
                        title: "Peer mesh moved",
                        detail: "A significant local peer-count change was observed.",
                        sensitiveValue: "\(signed(current.peers - previous.peers)) · now \(current.peers) peers"
                    ))
            }
            if let newInbound = current.inboundConnections,
                (previous.inboundConnections ?? 0) == 0,
                newInbound > 0
            {
                output.append(
                    event(
                        at: current.timestamp,
                        category: .network,
                        kind: .inboundObserved,
                        title: "Inbound peer evidence observed",
                        detail: "Remote traffic crossed the local network boundary.",
                        sensitiveValue: "+\(newInbound - (previous.inboundConnections ?? 0)) established locally"
                    ))
            }
            if let newSeniority = current.seniority,
                let oldSeniority = previous.seniority,
                newSeniority != oldSeniority
            {
                output.append(
                    event(
                        at: current.timestamp,
                        category: .identity,
                        kind: .seniorityChanged,
                        title: "Chain seniority changed",
                        detail: newSeniority > oldSeniority ? "Consensus value increased" : "Consensus value changed",
                        sensitiveValue: "\(oldSeniority) → \(newSeniority)"
                    ))
            }
            if let credit = current.lastRewardCreditFrame,
                credit != previous.lastRewardCreditFrame
            {
                output.append(
                    event(
                        at: current.timestamp,
                        category: .rewards,
                        kind: .rewardCredited,
                        title: "Reward credit observed",
                        detail: "The local prover state reported a new credit frame.",
                        sensitiveValue: String(credit)
                    ))
            }
            if let drops = current.routerDrops,
                drops > (previous.routerDrops ?? 0)
            {
                let previousDrops = previous.routerDrops ?? 0
                let increase = drops - previousDrops
                let meaningfulIncrease = max(UInt64(10), previousDrops / 10)
                guard increase >= meaningfulIncrease else { continue }
                output.append(
                    event(
                        at: current.timestamp,
                        category: .network,
                        kind: .routerDropsIncreased,
                        title: "Router filtered messages",
                        detail: "The local router rejected invalid or stale messages.",
                        sensitiveValue: "+\(increase) messages"
                    ))
            }
        }

        return coalesced(output).sorted { $0.timestamp > $1.timestamp }
    }

    /// Recovery and transport evidence may flicker at the collector boundary
    /// while the underlying network condition is unchanged. Preserve the first
    /// transition in each short window instead of flooding the operator journal
    /// with alternating observations that imply more incidents than occurred.
    private static func coalesced(_ events: [NodeActivityEvent]) -> [NodeActivityEvent] {
        let minimumSpacingByKind: [NodeActivityEventKind: TimeInterval] = [
            .archiveRecoveryStarted: 10 * 60,
            .archiveRecoveryEnded: 10 * 60,
            .peerMeshChanged: 5 * 60,
            .routerDropsIncreased: 5 * 60,
        ]
        var lastTimestampByKind: [NodeActivityEventKind: Date] = [:]
        var result: [NodeActivityEvent] = []

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let minimumSpacing = minimumSpacingByKind[event.kind],
                let previousTimestamp = lastTimestampByKind[event.kind],
                event.timestamp.timeIntervalSince(previousTimestamp) < minimumSpacing
            {
                continue
            }
            result.append(event)
            lastTimestampByKind[event.kind] = event.timestamp
        }
        return result
    }

    private static func appendCountChange(
        old: Int,
        new: Int,
        at timestamp: Date,
        category: NodeActivityCategory,
        kind: NodeActivityEventKind,
        title: String,
        noun: String,
        to output: inout [NodeActivityEvent]
    ) {
        guard old != new else { return }
        output.append(
            event(
                at: timestamp,
                category: category,
                kind: kind,
                title: title,
                detail: "The local \(noun) lifecycle changed.",
                sensitiveValue: "\(signed(new - old)) · now \(new)"
            ))
    }

    private static func event(
        at timestamp: Date,
        category: NodeActivityCategory,
        kind: NodeActivityEventKind,
        title: String,
        detail: String,
        sensitiveValue: String? = nil
    ) -> NodeActivityEvent {
        NodeActivityEvent(
            id: "\(timestamp.timeIntervalSince1970)-\(kind.rawValue)-\(title)",
            timestamp: timestamp,
            category: category,
            kind: kind,
            title: title,
            detail: detail,
            sensitiveValue: sensitiveValue
        )
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : String(value)
    }
}
