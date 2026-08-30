import AppKit
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

enum NodeLifecycleAction: String, CaseIterable, Identifiable, Sendable {
    case start
    case restart
    case stop

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .start: "play.fill"
        case .restart: "arrow.clockwise"
        case .stop: "stop.fill"
        }
    }
}

@MainActor
final class NodeLifecycleController: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var activeAction: NodeLifecycleAction?
    @Published private(set) var lastMessage: String?
    @Published private(set) var lastError: String?
    @Published private(set) var passwordlessServiceAvailable: Bool?

    func refreshServiceStatus() async {
        let available = await Task.detached(priority: .utility) {
            PrivilegedServiceClient.isAvailable()
        }.value
        passwordlessServiceAvailable = available
    }

    func perform(_ action: NodeLifecycleAction, monitor: NodeMonitor) async {
        guard !isWorking else { return }
        isWorking = true
        activeAction = action
        lastMessage = nil
        lastError = nil
        defer {
            isWorking = false
            activeAction = nil
        }

        let result = await Task.detached(priority: .userInitiated) {
            let passwordless = PrivilegedServiceClient.request(
                PrivilegedServiceAction(rawValue: action.rawValue)!,
                timeout: 110
            )
            return passwordless.exitCode == 69
                ? Self.runAuthorizedHelper(action)
                : passwordless
        }.value

        if result.exitCode == 0 {
            lastMessage =
                result.output.isEmpty
                ? "Node \(action.rawValue) request completed."
                : result.output
            try? await Task.sleep(for: .seconds(2))
            await monitor.refresh(forceNodeInfo: action != .stop)
        } else if result.exitCode == -128 {
            lastMessage = "Administrator authorization was cancelled."
        } else {
            lastError =
                result.output.isEmpty
                ? "Unable to \(action.rawValue) the node service."
                : result.output
        }
        await refreshServiceStatus()
    }

    private nonisolated static func runAuthorizedHelper(
        _ action: NodeLifecycleAction
    ) -> (output: String, exitCode: Int32) {
        let helperURL =
            Bundle.main.url(forAuxiliaryExecutable: "QuilNodeHelper")
            ?? Bundle.main.bundleURL.appendingPathComponent(
                "Contents/Helpers/QuilNodeHelper"
            )
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            return ("The bundled lifecycle helper is missing.", 1)
        }

        let command = "\(shellQuote(helperURL.path)) \(action.rawValue)"
        let prompt =
            "QuilNode's authenticated local service is unavailable. macOS needs administrator approval for this one \(action.rawValue) request. QuilNode never receives or stores your password."
        let script =
            "do shell script \(appleScriptLiteral(command)) with administrator privileges with prompt \(appleScriptLiteral(prompt))"
        let result = BoundedCommandRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script],
            environment: authorizationEnvironment(),
            timeout: 15 * 60,
            maximumOutputBytes: 1_048_576
        )
        return (result.output, result.exitCode)
    }

    private nonisolated static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private nonisolated static func appleScriptLiteral(_ value: String) -> String {
        "\""
            + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private nonisolated static func authorizationEnvironment() -> [String: String] {
        [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        ]
    }
}
