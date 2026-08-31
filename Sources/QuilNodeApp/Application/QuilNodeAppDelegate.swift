import AppKit
import SwiftUI

/// Owns AppKit-only lifecycle integration. Keeping this bridge out of the
/// SwiftUI scene composition makes termination policy and preview-window
/// behavior independently discoverable.
@MainActor
final class QuilNodeAppDelegate: NSObject, NSApplicationDelegate {
    private var quitInterlockPresenter: ApplicationQuitInterlockPresenter?

    #if DEBUG
        private var designPreviewWindow: NSWindow?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        ApplicationIcon.installForCurrentProcess()
        #if DEBUG
            presentStandaloneDesignPreviewIfRequested()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UpdateActivityGuard.shared.isInstalling else { return .terminateNow }
        guard quitInterlockPresenter == nil else { return .terminateLater }

        let presenter = ApplicationQuitInterlockPresenter()
        quitInterlockPresenter = presenter
        presenter.present { [weak self, weak sender] shouldQuit in
            self?.quitInterlockPresenter = nil
            guard shouldQuit else {
                sender?.reply(toApplicationShouldTerminate: false)
                return
            }
            Task { @MainActor in
                await UpdateActivityGuard.shared.stopAtSafePointForTermination()
                sender?.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    #if DEBUG
        /// SwiftUI intentionally restores a previously closed WindowGroup as
        /// closed. Visual-regression launches need a deterministic window, so
        /// preview-only modes use an isolated hosting window and never start
        /// production coordinators.
        private func presentStandaloneDesignPreviewIfRequested() {
            let value = ProcessInfo.processInfo.arguments.first {
                $0.hasPrefix("--design-preview=onboarding-")
                    || $0 == "--design-preview=menu-bar"
                    || $0 == "--design-preview=menu-bar-private"
                    || $0.hasPrefix("--design-preview=network-inbound-")
                    || $0.hasPrefix("--design-preview=identity-transaction-")
                    || $0.hasPrefix("--design-preview=operator-interlock-")
                    || $0 == "--design-preview=theme-library"
                    || $0 == "--design-preview=build-evidence"
            }
            guard let value else { return }

            let mode = String(value.dropFirst("--design-preview=".count))
            let content = standaloneDesignPreview(mode: mode)
            let previewSize =
                mode.hasPrefix("menu-bar")
                ? NSSize(width: 420, height: 590)
                : NSSize(width: 980, height: 730)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: previewSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "QuilNode Design Preview"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: content)
            window.center()
            window.makeKeyAndOrderFront(nil)
            designPreviewWindow = window
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                for candidate in NSApp.windows where candidate !== window {
                    candidate.orderOut(nil)
                }
                window.makeKeyAndOrderFront(nil)
                self.designPreviewWindow = window
                self.captureDesignPreviewIfRequested(window)
            }
        }

        /// Captures the exact preview host without requiring macOS Screen
        /// Recording permission. This exists only in DEBUG builds.
        private func captureDesignPreviewIfRequested(_ window: NSWindow) {
            let prefix = "--capture-design-preview="
            guard
                let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
                !argument.dropFirst(prefix.count).isEmpty
            else { return }
            let destination = URL(fileURLWithPath: String(argument.dropFirst(prefix.count)))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard let contentView = window.contentView else { return }
                contentView.displayIfNeeded()
                guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else { return }
                contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
                try? FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? png.write(to: destination, options: .atomic)
            }
        }

        @ViewBuilder
        private func standaloneDesignPreview(mode: String) -> some View {
            if mode.hasPrefix("onboarding-") {
                OnboardingDesignPreviewHost(mode: .init(argument: mode))
                    .quilThemed(.quilNode)
            } else if mode == "menu-bar" || mode == "menu-bar-private" {
                MenuBarDesignPreviewHost(privacyEnabled: mode == "menu-bar-private")
                    .quilThemed(.quilNode)
            } else if mode == "theme-library" {
                ThemeLibraryDesignPreviewHost()
            } else if mode == "build-evidence" {
                BuildEvidenceDesignPreviewHost()
                    .quilThemed(.quilNode)
            } else if mode.hasPrefix("operator-interlock-") {
                let previewMode: OperatorInterlockPreviewMode =
                    switch mode {
                    case "operator-interlock-firewall": .firewall
                    case "operator-interlock-updates": .updates
                    case "operator-interlock-quit": .quit
                    default: .restart
                    }
                OperatorInterlockDesignPreviewHost(mode: previewMode)
                    .quilThemed(.quilNode)
            } else if mode.hasPrefix("identity-transaction-") {
                let previewMode: IdentityTransactionPreviewMode =
                    switch mode {
                    case "identity-transaction-create": .create
                    case "identity-transaction-activate": .activate
                    case "identity-transaction-recovery": .importRecoveryOnly
                    default: .importKeyset
                    }
                IdentityTransactionDesignPreviewHost(
                    mode: previewMode,
                    privacyEnabled: mode == "identity-transaction-private"
                )
                .quilThemed(.quilNode)
            } else {
                let initialStep: InboundSetupStep =
                    switch mode {
                    case "network-inbound-firewall": .firewall
                    case "network-inbound-router": .router
                    case "network-inbound-proof": .inboundProof
                    default: .listenerProfile
                    }
                InboundSetupDesignPreviewHost(
                    initialStep: initialStep,
                    privacyEnabled: mode == "network-inbound-private",
                    profileKind: mode == "network-inbound-custom" ? .custom : .recommendedResidential
                )
                .quilThemed(.quilNode)
            }
        }
    #endif
}
