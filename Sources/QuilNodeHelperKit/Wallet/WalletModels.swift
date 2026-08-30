import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

typealias WalletTransactionKind = QuilNodeShared.WalletTransactionKind
typealias WalletTransactionManifest = QuilNodeShared.WalletTransactionManifest
typealias KeysetInspectionPayload = QuilNodeShared.KeysetInspection
typealias WalletPublicIdentityPayload = QuilNodeShared.KeysetPublicIdentity
typealias ManagedKeysetPayload = QuilNodeShared.ManagedKeyset
typealias WalletInventoryPayload = QuilNodeShared.WalletInventory

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
