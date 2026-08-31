#if DEBUG
    import AppKit
    import SwiftUI

    #if canImport(QuilNodeCore)
        import QuilNodeCore
    #endif

    enum OnboardingDesignPreviewMode {
        case firstInstallExistingIdentity
        case identityExisting

        init(argument: String) {
            self =
                argument == "onboarding-first-install-existing"
                ? .firstInstallExistingIdentity
                : .identityExisting
        }
    }

    struct OnboardingDesignPreviewHost: View {
        @StateObject private var walletManager: WalletManager
        @StateObject private var installer: InstallationCoordinator
        @StateObject private var privacyMode = PrivacyModeController()
        private let mode: OnboardingDesignPreviewMode

        init(mode: OnboardingDesignPreviewMode = .identityExisting) {
            self.mode = mode
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
            _installer = StateObject(
                wrappedValue: InstallationCoordinator(
                    previewPreflight: Self.cleanMacPreflight,
                    identityPlan: .importExisting,
                    signedRelease: SignedReleaseInfo(
                        version: "2.1.0.24",
                        binaryFileName: "node-2.1.0.24-darwin-arm64",
                        digestPublished: true,
                        signatureIndices: [1, 2, 8, 11, 13, 14, 17],
                        manifestModifiedAt: nil
                    ),
                    qclientRelease: OfficialQClientRelease(
                        releaseVersion: "2.1.0.23",
                        binaryFileName: "qclient-2.1.0.23-darwin-arm64",
                        digestPublished: true,
                        signatureIndices: [1, 2, 8, 11, 13, 14, 17]
                    )
                ))
        }

        var body: some View {
            Group {
                switch mode {
                case .firstInstallExistingIdentity:
                    FirstInstallView()
                        .environmentObject(installer)
                case .identityExisting:
                    WalletOnboardingView(preferredChoice: .importKeyset)
                        .environmentObject(walletManager)
                }
            }
            .quilThemed(.quilNode)
            .environmentObject(privacyMode)
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

        private static let cleanMacPreflight = InstallationPreflight(
            hardware: [
                .init(id: "platform", title: "Apple Silicon", detail: "arm64 is supported", state: .pass),
                .init(id: "macos", title: "macOS", detail: "26.0.1 · macOS 14 or newer", state: .pass),
                .init(id: "cpu", title: "CPU threads", detail: "10 detected · 4 minimum", state: .pass),
                .init(id: "memory", title: "Memory", detail: "32 GB detected · 8 GB minimum", state: .pass),
                .init(id: "storage", title: "Free storage", detail: "300 GB available · 16 GB minimum", state: .pass),
            ],
            productionRequirements: [
                .init(
                    id: "verifier", title: "Release trust verifier",
                    detail: "Bundled, code-signed, and self-contained", state: .pass
                ),
                .init(
                    id: "files", title: "File descriptor ceiling",
                    detail: "Will be raised once during authorization", state: .warning
                ),
                .init(
                    id: "toolchain", title: "Build toolchain",
                    detail: "Not required for official signed releases", state: .notRequired
                ),
            ],
            sourceToolchain: [],
            nodeInstalled: false,
            secureServiceReady: false
        )
    }
#endif
