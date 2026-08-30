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

extension ReleaseChecker {
    nonisolated static func runAuthorizedActivation(manifestURL: URL) -> (output: String, exitCode: Int32) {
        runAuthorizedHelper(
            arguments: ["activate", manifestURL.path],
            durableOperation: true
        )
    }

    nonisolated static func runAuthorizedHelper(
        arguments: [String],
        durableOperation: Bool = false
    ) -> (output: String, exitCode: Int32) {
        if let actionName = arguments.first,
            let action = privilegedServiceAction(named: actionName)
        {
            let manifestPath = arguments.count == 2 ? arguments[1] : nil
            let serviceResult =
                durableOperation
                ? PrivilegedServiceClient.requestOperation(
                    action,
                    manifestPath: manifestPath,
                    timeout: 420
                )
                : PrivilegedServiceClient.request(
                    action,
                    manifestPath: manifestPath,
                    timeout: 120
                )
            if serviceResult.exitCode != 69 && serviceResult.exitCode != 77 {
                return serviceResult
            }
        }
        let helperURL =
            Bundle.main.url(forAuxiliaryExecutable: "QuilNodeHelper")
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/QuilNodeHelper")
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            return ("The bundled update helper is missing.", 1)
        }
        let command = ([shellQuote(helperURL.path)] + arguments.map(shellQuote)).joined(separator: " ")
        let prompt = authorizationPrompt(for: arguments)
        let script =
            "do shell script \(appleScriptLiteral(command)) with administrator privileges with prompt \(appleScriptLiteral(prompt))"
        let result = BoundedCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script],
            environment: [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                "LANG": "C.UTF-8",
                "LC_ALL": "C.UTF-8",
            ],
            timeout: 15 * 60,
            maximumOutputBytes: 1_048_576
        )
        return (result.output, result.exitCode)
    }

    nonisolated private static func privilegedServiceAction(
        named helperAction: String
    ) -> PrivilegedServiceAction? {
        switch helperAction {
        case "qclient-install": .qclientInstall
        case "wallet-transact": .walletTransact
        default: PrivilegedServiceAction(rawValue: helperAction)
        }
    }

    nonisolated static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated static func appleScriptLiteral(_ value: String) -> String {
        "\""
            + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    nonisolated static func authorizationPrompt(for arguments: [String]) -> String {
        switch arguments.first {
        case "bootstrap", "migrate":
            "QuilNode needs one-time administrator approval to install its fixed local service, restricted node account, and launchd configuration. Your password is handled only by macOS and is never stored by QuilNode."
        case "install":
            "QuilNode needs administrator approval to install the already verified official node release. No keyset or store will be deleted."
        case "activate":
            "This node was built from an exact source commit but has no official release-signature quorum. Administrator approval confirms that you accept this development-code trust boundary. Your keys and stores remain local."
        case "qclient-install":
            "This qclient was built from source and is not covered by the official release-signature quorum. Administrator approval is required because qclient operates beside the private node configuration."
        case "wallet-transact":
            "QuilNode is about to create, import, activate, or export local identity material. Administrator approval provides fresh user presence; private key bytes remain inside the root service and are never returned to the interface."
        case "rollback":
            "QuilNode needs administrator approval because its authenticated local service is unavailable and you requested a node rollback."
        default:
            "QuilNode needs administrator approval for the requested local node operation. Your password is handled only by macOS and is never stored by QuilNode."
        }
    }
}
