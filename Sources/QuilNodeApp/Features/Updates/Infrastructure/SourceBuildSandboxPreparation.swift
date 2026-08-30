import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension ReleaseChecker {
    nonisolated static func prepareSourceBuildSandbox(
        workspace: URL,
        repository: URL
    ) throws -> PreparedSourceBuildSandbox {
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: SourceBuildSandbox.executable) else {
            throw UpdateCenterError.sourceSandboxUnavailable
        }
        let toolchain = try SourceBuildToolchain.discover(fileManager: fileManager)

        let sandboxRoot = workspace.appendingPathComponent("sandbox", isDirectory: true)
        let cargoHome = sandboxRoot.appendingPathComponent("cargo-home", isDirectory: true)
        let isolatedHome = sandboxRoot.appendingPathComponent("home", isDirectory: true)
        let temporary = sandboxRoot.appendingPathComponent("tmp", isDirectory: true)
        for directory in [sandboxRoot, cargoHome, isolatedHome, temporary] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        let layout = SourceBuildSandbox.Layout(
            workspace: workspace,
            repository: repository,
            cargoHome: cargoHome,
            isolatedHome: isolatedHome,
            temporaryDirectory: temporary,
            rustupHome: toolchain.rustupHome,
            cargoBin: toolchain.cargoBin,
            flintDirectory: toolchain.flintDirectory,
            gmpDirectory: toolchain.gmpDirectory,
            mpfrDirectory: toolchain.mpfrDirectory,
            opensslDirectory: toolchain.opensslDirectory,
            macOSSDK: toolchain.macOSSDK
        )
        let fetchProfile = sandboxRoot.appendingPathComponent("dependency-fetch.sb")
        let compileProfile = sandboxRoot.appendingPathComponent("compile-no-network.sb")
        try writePrivateBuildPolicy(
            try SourceBuildSandbox.profile(layout: layout, allowsNetwork: true),
            to: fetchProfile
        )
        try writePrivateBuildPolicy(
            try SourceBuildSandbox.profile(layout: layout, allowsNetwork: false),
            to: compileProfile
        )
        let environment = try SourceBuildSandbox.environment(layout: layout)

        // Fail closed before cloning or compiling if the host OS can no longer
        // apply this policy. Source updates are optional; silently building
        // unsandboxed is never an acceptable compatibility fallback.
        do {
            _ = try runChecked(
                SourceBuildSandbox.executable,
                try SourceBuildSandbox.arguments(
                    profileURL: compileProfile,
                    executable: "/usr/bin/true",
                    arguments: []
                ),
                currentDirectory: repository,
                environment: environment,
                timeout: 10
            )
        } catch {
            throw UpdateCenterError.sourceSandboxUnavailable
        }
        return PreparedSourceBuildSandbox(
            fetchProfile: fetchProfile,
            compileProfile: compileProfile,
            cargoExecutable: toolchain.cargoExecutable.path,
            environment: environment
        )
    }

    nonisolated static func validateSourceBuildArtifact(
        _ url: URL,
        maximumBytes: UInt64
    ) throws {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFREG,
            metadata.st_nlink == 1,
            metadata.st_uid == getuid(),
            metadata.st_size > 0,
            UInt64(metadata.st_size) <= maximumBytes,
            metadata.st_mode & 0o111 != 0,
            metadata.st_mode & 0o022 == 0
        else { throw UpdateCenterError.sourceArtifactUnsafe(url.lastPathComponent) }
    }

    nonisolated private static func writePrivateBuildPolicy(
        _ policy: String,
        to url: URL
    ) throws {
        try Data(policy.utf8).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
