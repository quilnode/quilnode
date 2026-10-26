import Foundation

extension NodeSnapshot {
    /// Wallet, identity, and prover reads can finish during a telemetry pass.
    /// Merge their latest results only for the same process and public peer.
    /// A replacement node must establish its own identity and balance evidence.
    mutating func preserveConcurrentReads(from current: NodeSnapshot) -> Bool {
        guard processID == current.processID,
            current.peerID == nil || peerID == nil || current.peerID == peerID
        else { return false }
        quilBalance = current.quilBalance
        quilAccount = current.quilAccount
        balanceUpdatedAt = current.balanceUpdatedAt
        balanceError = current.balanceError
        walletBalance = current.walletBalance
        legacyPeerID = legacyPeerID ?? current.legacyPeerID
        proverAddress = proverAddress ?? current.proverAddress
        preferNewerSeniorityObservation(from: current)
        preferNewerProverObservation(from: current)
        peerScore = current.peerScore
        reachable = current.reachable
        allocatedWorkers = current.allocatedWorkers
        lastReceivedFrame = current.lastReceivedFrame
        lastGlobalHeadFrame = current.lastGlobalHeadFrame
        epoch = current.epoch
        epochLength = current.epochLength
        nextEpochFrame = current.nextEpochFrame
        shardAllocations = current.shardAllocations
        networkShards = current.networkShards
        networkShardSummary = current.networkShardSummary
        networkShardError = current.networkShardError
        inboundConnectionsEstablished = inboundConnectionsEstablished ?? current.inboundConnectionsEstablished
        outboundConnectionsEstablished = outboundConnectionsEstablished ?? current.outboundConnectionsEstablished
        localWorkerCount = localWorkerCount ?? current.localWorkerCount
        localWorkers = localWorkers ?? current.localWorkers
        return true
    }
}
