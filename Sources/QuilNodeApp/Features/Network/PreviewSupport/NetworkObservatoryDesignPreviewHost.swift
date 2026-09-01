#if DEBUG
    import SwiftUI

    #if canImport(QuilNodeCore)
        import QuilNodeCore
    #endif

    struct NetworkObservatoryDesignPreviewHost: View {
        @StateObject private var monitor: NodeMonitor
        let privacyEnabled: Bool
        let layoutClass: DashboardLayoutClass

        init(privacyEnabled: Bool = false, layoutClass: DashboardLayoutClass = .wide) {
            self.privacyEnabled = privacyEnabled
            self.layoutClass = layoutClass
            _monitor = StateObject(wrappedValue: NodeMonitor(previewSnapshot: Self.previewSnapshot))
        }

        var body: some View {
            ZStack {
                ThemeCanvasBackground().ignoresSafeArea()
                ScrollView {
                    NetworkWorkspaceView(forcedMode: .observatory)
                        .padding(24)
                }
            }
            .environmentObject(monitor)
            .environment(\.dashboardLayoutClass, layoutClass)
            .redacted(reason: privacyEnabled ? .privacy : [])
            .frame(minWidth: layoutClass.isWide ? 1_180 : 680, minHeight: 760)
        }

        private static let previewSnapshot: NodeSnapshot = {
            let proverCounts = [8, 11, 6, 5, 3, 0, 7, 9, 4, 2, 6, 8, 5, 7, 1, 10, 6, 3, 9, 0, 4, 7]
            let allocated = Set([1, 3, 6, 8, 11, 13, 16, 18, 21])
            let shards = proverCounts.enumerated().map { index, provers in
                NetworkShardObservation(
                    filter: String(format: "%04x%08x%04x", index + 1, (index + 7) * 7_919, 0xD00D - index),
                    shardSize: String(format: "%.1f GB", 2.8 + Double(index) * 0.74),
                    dataShards: (index % 4) + 1,
                    activeProvers: provers,
                    ring: min(provers / 8, 3),
                    estimatedRewardPerFrame: String(format: "%.5f", provers == 0 ? 0 : 0.0042 / Double(provers)),
                    isAllocated: allocated.contains(index),
                    worker: allocated.contains(index) ? String((index % 9) + 1) : nil
                )
            }
            let observedAt = Date(timeIntervalSince1970: 1_788_268_800)
            return NodeSnapshot(
                collectedAt: observedAt,
                isRunning: true,
                version: "2.1.0.25",
                epoch: 1_083,
                shardAllocations: shards.filter(\.isAllocated).enumerated().map { index, shard in
                    ShardAllocation(
                        index: index,
                        filter: shard.filter,
                        status: "active",
                        worker: shard.worker
                    )
                },
                networkShards: shards,
                networkShardSummary: NetworkShardSummary(
                    shards: shards,
                    frame: 779_842,
                    difficulty: 12_984,
                    worldState: "78.4 GB",
                    observedAt: observedAt
                ),
                frame: 779_842,
                peers: 238,
                archivePeers: 5,
                archiveEndpointCount: 5,
                activeShards: allocated.count,
                totalAllocations: allocated.count,
                metricsUpdatedAt: observedAt
            )
        }()
    }
#endif
