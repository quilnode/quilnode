import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
final class UpdateActivityGuard {
    static let shared = UpdateActivityGuard()
    private(set) var isInstalling = false

    func setInstalling(_ value: Bool) {
        isInstalling = value
    }
}

extension ReleaseChecker {
    /// Shared one-time authorization entry point for feature migrations that
    /// replace the pinned root service without storing administrator secrets.
    nonisolated static func authorizeServiceMigration(controllerUID: UInt32) -> (output: String, exitCode: Int32) {
        runAuthorizedHelper(arguments: ["bootstrap", "\(controllerUID)"])
    }
}
