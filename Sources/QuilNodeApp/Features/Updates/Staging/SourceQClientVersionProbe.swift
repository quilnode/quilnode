import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func expectedQClientRuntimeVersion(repository: URL, sourceVersion: String) throws -> String {
        guard let base = NodeVersion(sourceVersion), base.components.count == 4 else { return sourceVersion }
        let versionFile = repository.appendingPathComponent("crates/quil-config/src/version.rs")
        let source = String(
            decoding: try BoundedLocalData.read(from: versionFile, maximumBytes: 128_000), as: UTF8.self)
        guard source.contains("pub fn display_version()") else { return sourceVersion }
        let subpatchFile = repository.appendingPathComponent("subpatch")
        guard FileManager.default.fileExists(atPath: subpatchFile.path) else { return sourceVersion }
        let subpatch = String(decoding: try BoundedLocalData.read(from: subpatchFile, maximumBytes: 64), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subpatch.isEmpty, subpatch.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw UpdateCenterError.versionValidationFailed
        }
        return "\(sourceVersion).\(subpatch)"
    }

    nonisolated static func sourceQClientRuntimeVersion(
        binary: URL, repository: URL, sandbox: PreparedSourceBuildSandbox, sourceVersion: String
    ) throws -> String {
        let expected = try expectedQClientRuntimeVersion(repository: repository, sourceVersion: sourceVersion)
        for arguments in [["--version"], ["-y", "version"]] {
            let output = try? runChecked(
                SourceBuildSandbox.executable,
                try SourceBuildSandbox.arguments(
                    profileURL: sandbox.compileProfile, executable: binary.path, arguments: arguments
                ),
                currentDirectory: repository, environment: sandbox.environment, timeout: 15
            )
            if let output, let version = QClientRuntimeVersionParser.parse(output) {
                guard version.contains("-p") || version == expected else {
                    throw UpdateCenterError.versionValidationFailed
                }
                return version
            }
        }
        throw UpdateCenterError.versionValidationFailed
    }
}
