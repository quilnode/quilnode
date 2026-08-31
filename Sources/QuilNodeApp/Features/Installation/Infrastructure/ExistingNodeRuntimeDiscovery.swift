import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Detects only a running Quilibrium executable outside QuilNode's fixed
/// runtime path. It deliberately does not crawl the operator's home directory,
/// inspect configuration files, or retain executable paths.
enum ExistingNodeRuntimeDiscovery {
    static let managedExecutable = "/opt/quilibrium/node/quilibrium-node"

    static func isExternalNodeRunning() -> Bool {
        let result = BoundedCommandRunner.run(
            executable: "/bin/ps",
            arguments: ["-axo", "comm="],
            timeout: 5,
            maximumOutputBytes: 512 * 1_024
        )
        guard result.exitCode == 0 else { return false }
        return isExternalNodeRunning(processTable: result.output)
    }

    static func isExternalNodeRunning(
        processTable: String,
        managedExecutable: String = managedExecutable
    ) -> Bool {
        processTable
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { executable in
                guard !executable.isEmpty,
                    URL(fileURLWithPath: executable).standardizedFileURL.path
                        != URL(fileURLWithPath: managedExecutable).standardizedFileURL.path
                else { return false }
                return isNodeExecutableName(URL(fileURLWithPath: executable).lastPathComponent)
            }
    }

    private static func isNodeExecutableName(_ name: String) -> Bool {
        if name == "quilibrium-node" { return true }
        return name.range(
            of: #"^node-[0-9]+(?:\.[0-9]+){2,}(?:-source-[0-9a-fA-F]+)?-darwin-(?:arm64|amd64)$"#,
            options: .regularExpression
        ) != nil
    }
}
