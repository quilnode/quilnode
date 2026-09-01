import Foundation

/// Semantic dashboard copy shared across themes.
///
/// Themes may change casing, typography, and visual treatment, but they must
/// not add decorative words to operator-facing labels. Keeping compact copy in
/// one place also prevents cards from drifting into different terminology.
enum DashboardCopy {
    enum Brand {
        static let localConsole = "LOCAL NODE CONSOLE"
    }

    enum Overview {
        static let eyebrow = "PROVER STATUS"
        static let frame = "FRAME"
        static let peers = "PEERS"
        static let seniority = "SENIORITY"
        static let quil = "QUIL"
        static let uptime = "UPTIME"

        static let chainRegistry = "Chain registry"
        static let nodeProcess = "Node process"
        static let chainValueRead = "Chain value read"
    }

    enum Activity {
        static let liveMesh = "Live mesh"
        static let syncSources = "Sync sources"
        static let servingNow = "Serving now"

        static func allocationDetail(activeShards: Int, pendingJoins: Int) -> String {
            if activeShards > 0 { return "Assigned work" }
            if pendingJoins > 0 { return "Joining work" }
            return "None assigned"
        }
    }

    enum Identity {
        static let registryEvidence = "Official node · synchronized registry"
        static let evidenceExplanation =
            "Seniority updates when the node applies new chain evidence."
        static let custodyBoundary =
            "Only public identifiers and balance reach the dashboard. Private key bytes remain inside the isolated node and custody service."
    }

    enum Updates {
        static let releaseChannels = "Release channels"
        static let nodeServiceRunning = "Node service running"
    }
}
