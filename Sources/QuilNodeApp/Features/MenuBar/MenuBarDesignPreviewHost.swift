#if DEBUG
    import AppKit
    import SwiftUI

    #if canImport(QuilNodeCore)
        import QuilNodeCore
    #endif

    /// Deterministic fixture used only for native visual regression captures.
    /// It does not start, stop, or inspect the installed node.
    struct MenuBarDesignPreviewHost: View {
        let privacyEnabled: Bool

        private let snapshot = NodeSnapshot(
            collectedAt: Date(),
            isRunning: true,
            version: "2.1.0.25",
            quilBalance: "182.7401",
            lastRewardCreditFrame: nil,
            seniority: 13_219_200,
            reachable: true,
            lastReceivedFrame: 753_568,
            lastGlobalHeadFrame: 753_568,
            epoch: 1_046,
            epochLength: 720,
            nextEpochFrame: 753_840,
            frame: 753_568,
            peers: 249,
            inboundConnectionsEstablished: 37,
            outboundConnectionsEstablished: 624,
            archivePeers: 11,
            activeShards: 9,
            totalAllocations: 9,
            framesReceived: 48_200,
            cpuPercent: 18,
            cpuCoreEquivalent: 1.8,
            memoryMB: 2_336,
            processUptime: "18:42:11",
            logLastModifiedAt: Date(),
            metricsUpdatedAt: Date(),
            frameLastAdvancedAt: Date(),
            framesPerMinute: 6.2,
            lowerFramesPerMinute: 5.8,
            upperFramesPerMinute: 6.7
        )

        private let milestones = [
            ProtocolMilestone(
                symbol: "QUIL_PROVER_RESET_V4_FRAME",
                title: "QUIL Prover Reset V4",
                kind: .reset,
                targetFrame: 754_000,
                summary: "A scheduled prover-state reset.",
                operatorImpact: "The node may pause briefly while state converges.",
                sourcePath: "crates/node/src/main.rs",
                sourceLine: 1,
                branch: "develop",
                commit: "preview",
                committedAt: Date(),
                checkedAt: Date(),
                installedSupport: .included
            )
        ]

        var body: some View {
            MenuBarContent(
                snapshot: snapshot,
                phase: .ready,
                milestones: milestones,
                isRefreshing: false,
                privacyEnabled: privacyEnabled,
                onOpenDashboard: { _ in },
                onRefresh: {},
                onTogglePrivacy: {},
                onOpenSettings: {},
                onQuit: {}
            )
            .quilThemed(.quilNode)
            .onAppear {
                DispatchQueue.main.async {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
                        return
                    }
                    window.setContentSize(NSSize(width: 420, height: 590))
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
#endif
