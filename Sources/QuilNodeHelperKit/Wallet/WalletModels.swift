import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

// The release helper compiles Shared and HelperKit into one sealed executable,
// while SwiftPM imports Shared as a module. Unqualified aliases support both
// composition modes without duplicating the privileged wire schema.
typealias KeysetInspectionPayload = KeysetInspection
typealias WalletPublicIdentityPayload = KeysetPublicIdentity
typealias ManagedKeysetPayload = ManagedKeyset
typealias WalletInventoryPayload = WalletInventory

struct StoredWalletProfile: Codable {
    var id: UUID
    var name: String
    var sourceLabel: String
    var directoryName: String
    var createdAt: Date?
    var importedAt: Date?
    var lastActivatedAt: Date?
    var lastVerifiedBackupAt: Date?
    var lastExternalBackupAt: Date? = nil
}

struct WalletRegistry: Codable {
    var schemaVersion = 1
    var activeKeysetID: UUID?
    var profiles: [StoredWalletProfile]
}
