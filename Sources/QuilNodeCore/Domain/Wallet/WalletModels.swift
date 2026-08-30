import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

// Preserve the Core-facing API while keeping the app/helper wire schema in the
// lowest shared module. These aliases prevent either process from redeclaring
// Codable fields that could drift across the privilege boundary.
public typealias NodeKeysetFormat = QuilNodeShared.NodeKeysetFormat
public typealias KeysetHealth = QuilNodeShared.KeysetHealth
public typealias KeysetPublicIdentity = QuilNodeShared.KeysetPublicIdentity
public typealias ManagedKeyset = QuilNodeShared.ManagedKeyset
public typealias WalletInventory = QuilNodeShared.WalletInventory
public typealias KeysetInspection = QuilNodeShared.KeysetInspection
public typealias WalletTransactionKind = QuilNodeShared.WalletTransactionKind
public typealias WalletTransactionManifest = QuilNodeShared.WalletTransactionManifest

public extension NodeKeysetFormat {
    var label: String {
        switch self {
        case .legacyPre25: "Legacy (pre-.25)"
        case .transitional25: ".25 migration required"
        case .current25: "Current .25"
        case .empty: "Empty keyset"
        case .unreadable: "Unrecognized keyset"
        }
    }
}
