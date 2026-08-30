#if DEBUG
    import SwiftUI

    #if canImport(QuilNodeCore)
        import QuilNodeCore
    #endif

    enum IdentityTransactionPreviewMode: Equatable {
        case importKeyset
        case importRecoveryOnly
        case create
        case activate
    }

    struct IdentityTransactionDesignPreviewHost: View {
        @StateObject private var walletManager: WalletManager
        private let context: IdentityTransactionContext
        private let privacyEnabled: Bool
        private let initialDisposition: IdentityImportDisposition

        init(mode: IdentityTransactionPreviewMode, privacyEnabled: Bool = false) {
            let defaults = UserDefaults(suiteName: "QuilNode.IdentityTransactionPreview") ?? .standard
            let identity = Self.previewIdentity
            _walletManager = StateObject(
                wrappedValue: WalletManager(
                    previewInventory: WalletInventory(
                        keysets: [identity],
                        activeKeysetID: nil,
                        serviceSupportsTransactions: true,
                        recoveryVaultHealthy: true
                    ),
                    defaults: defaults
                )
            )
            self.privacyEnabled = privacyEnabled
            initialDisposition = mode == .importRecoveryOnly ? .recoveryOnly : .activate

            switch mode {
            case .importKeyset, .importRecoveryOnly:
                context = .importKeyset(
                    PendingKeysetImport(
                        selectedDirectory: URL(fileURLWithPath: "/preview/identity-package"),
                        inspection: KeysetInspection(
                            format: .legacyPre25,
                            health: .migrationRequired,
                            requiresMigration: true,
                            keyCount: 11,
                            keyTypes: ["proving", "consensus", "wallet"],
                            fingerprint: "f3b7a61d549b2980c944d1cf50aa9a1c",
                            warnings: [],
                            hasConfig: true,
                            hasKeys: true
                        ),
                        suggestedName: "Seniority identity"
                    )
                )
            case .create:
                context = .create(suggestedName: "My Quilibrium identity")
            case .activate:
                context = .activate(identity)
            }
        }

        var body: some View {
            IdentityTransactionAssistantView(
                context: context,
                initialDisposition: initialDisposition
            )
            .environmentObject(walletManager)
            .redacted(reason: privacyEnabled ? .privacy : [])
            .quilThemed(.quilNode)
        }

        private static let previewIdentity = ManagedKeyset(
            id: UUID(uuidString: "0E0B9D02-4933-4453-9026-48A84048B078")!,
            name: "Seniority identity",
            format: .legacyPre25,
            health: .migrationRequired,
            isActive: false,
            isManaged: true,
            requiresMigration: true,
            keyCount: 11,
            keyTypes: ["proving", "consensus", "wallet"],
            sourceLabel: "Imported legacy keyset",
            automaticRecoveryCopies: 1,
            fingerprint: "f3b7a61d549b2980c944d1cf50aa9a1c"
        )
    }
#endif
