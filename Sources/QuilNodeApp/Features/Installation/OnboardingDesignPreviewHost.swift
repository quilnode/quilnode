#if DEBUG
    import AppKit
    import SwiftUI

    #if canImport(QuilNodeCore)
        import QuilNodeCore
    #endif

    struct OnboardingDesignPreviewHost: View {
        @StateObject private var walletManager: WalletManager

        init() {
            let defaults = UserDefaults(suiteName: "QuilNode.OnboardingDesignPreview") ?? .standard
            let identity = ManagedKeyset(
                name: "Existing node identity",
                format: .current25,
                health: .ready,
                isActive: true,
                isManaged: false,
                keyCount: 11,
                keyTypes: ["proving", "consensus", "wallet"],
                sourceLabel: "Detected active keyset",
                fingerprint: "preview-only-public-fingerprint"
            )
            _walletManager = StateObject(
                wrappedValue: WalletManager(
                    previewInventory: WalletInventory(
                        keysets: [identity],
                        activeKeysetID: identity.id,
                        serviceSupportsTransactions: true,
                        recoveryVaultHealthy: true
                    ),
                    defaults: defaults
                ))
        }

        var body: some View {
            WalletOnboardingView()
                .environmentObject(walletManager)
                .quilThemed(.quilNode)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
                            return
                        }
                        window.setContentSize(NSSize(width: 900, height: 680))
                        window.center()
                        window.makeKeyAndOrderFront(nil)
                    }
                }
        }
    }
#endif
