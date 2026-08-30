/// Central policy and persistence key for privacy-aware presentation.
///
/// The node model always retains its real local values. Privacy Mode changes
/// presentation only, so monitoring and alerts continue working normally.
enum PrivacyMode {
    static let defaultsKey = "privacyModeEnabled"
}

/// Fixed visual density for redacted collections.
///
/// Masking text is not enough when one rendered row still corresponds to one
/// private item. Privacy-aware collection views use this constant instead of
/// their model count, so layout cannot reveal worker or allocation cardinality.
enum PrivacyLayoutPolicy {
    static let collectionPlaceholderCount = 3
}

/// The single privacy vocabulary used by every dashboard surface.
///
/// A field is classified by what it reveals, not by where it happens to be
/// rendered. This keeps the dashboard, menu bar, recovery views, and future
/// themes consistent. New sensitive values must choose a case here before
/// they can be displayed with `PrivacyProtectedText`.
enum PrivacyField: String, CaseIterable {
    case activeShardCount
    case allocationCount
    case shardAllocation
    case seniority
    case quilBalance
    case nodeUptime
    case hardwareProfile
    case networkIdentifier
    case networkPort
    case networkActivity
    case recoveryMetadata
    case localTimestamp

    var mask: PrivacyMaskStyle {
        switch self {
        case .activeShardCount, .allocationCount, .hardwareProfile, .networkActivity:
            .compact
        case .networkIdentifier, .shardAllocation:
            .identifier
        case .networkPort, .seniority, .quilBalance, .nodeUptime, .recoveryMetadata, .localTimestamp:
            .standard
        }
    }

    var accessibilityName: String {
        switch self {
        case .activeShardCount: "Active shard count"
        case .allocationCount: "Allocation count"
        case .shardAllocation: "Shard allocation"
        case .seniority: "Seniority"
        case .quilBalance: "QUIL balance"
        case .nodeUptime: "Node uptime"
        case .hardwareProfile: "Hardware detail"
        case .networkIdentifier: "Network identifier"
        case .networkPort: "Network port"
        case .networkActivity: "Network activity"
        case .recoveryMetadata: "Recovery detail"
        case .localTimestamp: "Local timestamp"
        }
    }
}

/// A small vocabulary of familiar, non-semantic masks. Fixed lengths avoid
/// disclosing the magnitude or exact character count of the hidden value.
enum PrivacyMaskStyle {
    case compact
    case standard
    case identifier

    var text: String {
        switch self {
        case .compact: "***"
        case .standard: "*****"
        case .identifier: "**********"
        }
    }
}
