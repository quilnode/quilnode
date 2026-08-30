import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct PendingKeysetImport: Identifiable {
    let id = UUID()
    let keysetID = UUID()
    /// A capability chosen by the operator. The GUI retains the URL only; it
    /// never opens, parses, hashes, copies, or displays either key file.
    let selectedDirectory: URL
    let inspection: KeysetInspection
    var suggestedName: String
}

enum PendingKeysetImportResult: Equatable {
    case failed
    case imported
    case importedAndActivated
    case importedActivationFailed(keysetID: UUID)
}

struct WalletOperationError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
