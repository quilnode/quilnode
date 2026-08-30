import Foundation

/// Small, deterministic policies shared by update discovery and its tests.
/// Network and process work stays in the app target; selection and freshness
/// decisions live here so they can be verified without touching the network.
public enum UpdateDiscoveryPolicy {
    public static let defaultFreshnessInterval: TimeInterval = 5 * 60
    public static let signalInterval: TimeInterval = 5 * 60
    public static let fullReconciliationInterval: TimeInterval = 6 * 60 * 60
    public static let maximumSignalBackoff: TimeInterval = 60 * 60

    public static func shouldRefresh(
        lastCheckedAt: Date?,
        now: Date = Date(),
        freshnessInterval: TimeInterval = defaultFreshnessInterval
    ) -> Bool {
        guard let lastCheckedAt else { return true }
        return now.timeIntervalSince(lastCheckedAt) >= max(freshnessInterval, 0)
    }

    /// Signal checks are intentionally lightweight and jittered so many Macs do
    /// not query the same upstream at once. Failures back off exponentially;
    /// successful probes return to the five-minute cadence. The jitter input is
    /// explicit to keep the policy deterministic in tests.
    public static func nextSignalDelay(
        consecutiveFailures: Int,
        jitterUnit: Double
    ) -> TimeInterval {
        let exponent = min(max(consecutiveFailures, 0), 4)
        let base = min(
            signalInterval * pow(2, Double(exponent)),
            maximumSignalBackoff
        )
        let boundedJitter = min(max(jitterUnit, 0), 1)
        return base + base * 0.1 * boundedJitter
    }
}

/// Builds a bounded, safe sparse-checkout plan for protocol metadata scans.
/// Upstream paths are treated as untrusted input: only relative Rust source
/// files under `crates/` are eligible, and traversal components are rejected.
public enum ProtocolSourcePlan {
    public static let defaultMaximumPathCount = 1_200

    public static func paths(
        previous: [String],
        recentlyChanged: [String],
        required: [String],
        maximumPathCount: Int = defaultMaximumPathCount
    ) -> [String] {
        let maximum = max(maximumPathCount, 0)
        guard maximum > 0 else { return [] }

        let preferred = required + previous
        let overflow = recentlyChanged
        var accepted = Set<String>()
        var result: [String] = []

        func append(_ value: String) {
            guard result.count < maximum,
                isSafeRustSourcePath(value),
                accepted.insert(value).inserted
            else { return }
            result.append(value)
        }

        preferred.forEach(append)
        overflow.sorted().forEach(append)
        return result
    }

    public static func isSafeRustSourcePath(_ path: String) -> Bool {
        guard path.hasPrefix("crates/"),
            path.hasSuffix(".rs"),
            path.utf8.count <= 512,
            !path.hasPrefix("/"),
            !path.contains("\\"),
            !path.contains("\0")
        else { return false }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
    }
}
