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
    struct Token: Hashable {
        fileprivate let id = UUID()
    }

    static let shared = UpdateActivityGuard()
    private var terminationHandlers: [Token: @MainActor () async -> Void] = [:]

    var isInstalling: Bool { !terminationHandlers.isEmpty }

    @discardableResult
    func beginInstalling(terminationHandler: @escaping @MainActor () async -> Void) -> Token {
        let token = Token()
        terminationHandlers[token] = terminationHandler
        return token
    }

    func finishInstalling(_ token: Token) {
        terminationHandlers[token] = nil
    }

    func stopAtSafePointForTermination() async {
        let handlers = Array(terminationHandlers.values)
        for handler in handlers {
            await handler()
        }
    }
}

extension ReleaseChecker {
    /// Shared one-time authorization entry point for feature migrations that
    /// replace the pinned root service without storing administrator secrets.
    nonisolated static func authorizeServiceMigration(controllerUID: UInt32) -> (output: String, exitCode: Int32) {
        runAuthorizedHelper(arguments: ["bootstrap", "\(controllerUID)"])
    }
}
