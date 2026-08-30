import AppKit
import Foundation

/// Owns the macOS capability-selection panels used by wallet workflows. It
/// returns only operator-selected directory URLs and never reads their files.
@MainActor
enum WalletDirectoryPicker {
    static func chooseKeysetDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a Quilibrium keyset"
        panel.message =
            "Select the folder containing config.yml and keys.yml. The QuilNode interface never opens key files; the signed local service validates this selected folder on your Mac."
        panel.prompt = "Inspect Keyset"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseRecoveryDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose encrypted backup storage"
        panel.message =
            "Choose an encrypted external drive, encrypted disk image, or password-protected vault. The signed local service writes and verifies the recovery package; the QuilNode interface never opens key files."
        panel.prompt = "Save Verified Recovery Copy"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func reveal(_ directory: URL) {
        NSWorkspace.shared.open(directory)
    }
}
