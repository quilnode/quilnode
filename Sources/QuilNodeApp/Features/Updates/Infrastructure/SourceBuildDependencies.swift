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
    nonisolated static func prepareSourceDependencies(
        repository: URL,
        sandbox: PreparedSourceBuildSandbox,
        logURL: URL
    ) throws -> SourceBuildDependencyLock {
        let lockURL = repository.appendingPathComponent("Cargo.lock")
        let upstream = try sourceCargoLockfileData(repository: repository, upstream: true)
        let original = try sourceCargoLockfileData(repository: repository)
        guard CargoLockfileIntegrity.permitsLocalDependencyRepair(upstream: upstream, resolved: original) else {
            throw UpdateCenterError.sourceDependencyLockInvalid
        }
        var completed = false
        defer {
            if !completed { try? original.write(to: lockURL, options: .atomic) }
        }
        do {
            try runSourceCargoFetch(repository: repository, sandbox: sandbox, logURL: logURL, offline: false)
        } catch let UpdateCenterError.commandFailed(message)
            where message.contains("cannot update the lock file") && message.contains("--locked")
        {
            // Reconcile stale local graph entries only. No online resolution,
            // dependency upgrade, or upstream source patch is permitted.
            do {
                try runSourceCargoFetch(repository: repository, sandbox: sandbox, logURL: logURL, offline: true)
            } catch let UpdateCenterError.commandFailed(message) {
                // Cargo may write the reconciled lock before an offline fetch
                // reports an uncached archive. Validate that lock first, then
                // let the locked online fetch acquire only pinned packages.
                guard try sourceCargoLockfileData(repository: repository) != original else {
                    throw UpdateCenterError.commandFailed(message)
                }
            }
            let repaired = try sourceCargoLockfileData(repository: repository)
            guard CargoLockfileIntegrity.permitsLocalDependencyRepair(upstream: upstream, resolved: repaired) else {
                throw UpdateCenterError.sourceDependencyLockInvalid
            }
            try runSourceCargoFetch(repository: repository, sandbox: sandbox, logURL: logURL, offline: false)
        }
        let resolved = try sourceCargoLockfileData(repository: repository)
        guard CargoLockfileIntegrity.permitsLocalDependencyRepair(upstream: upstream, resolved: resolved) else {
            throw UpdateCenterError.sourceDependencyLockInvalid
        }
        let receipt = SourceBuildDependencyLock(
            upstreamSHA256: cargoLockfileSHA256(upstream),
            resolvedSHA256: cargoLockfileSHA256(resolved)
        )
        try resolved.write(
            to: logURL.deletingLastPathComponent().appendingPathComponent("Cargo.lock"), options: .atomic)
        try JSONEncoder().encode(receipt).write(
            to: logURL.deletingLastPathComponent().appendingPathComponent("cargo-lock-receipt.json"), options: .atomic
        )
        completed = true
        return receipt
    }

    nonisolated static func validatedSourceCargoLockfileSHA256(repository: URL) throws -> String {
        let upstream = try sourceCargoLockfileData(repository: repository, upstream: true)
        let resolved = try sourceCargoLockfileData(repository: repository)
        guard CargoLockfileIntegrity.permitsLocalDependencyRepair(upstream: upstream, resolved: resolved) else {
            throw UpdateCenterError.sourceDependencyLockInvalid
        }
        return cargoLockfileSHA256(resolved)
    }

    nonisolated static func sourceCargoLockfileData(repository: URL, upstream: Bool = false) throws -> Data {
        if upstream {
            return Data(
                try runChecked(gitExecutable, ["-C", repository.path, "show", "HEAD:Cargo.lock"], timeout: 30).utf8
            )
        }
        let url = repository.appendingPathComponent("Cargo.lock")
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0,
            metadata.st_mode & S_IFMT == S_IFREG,
            metadata.st_nlink == 1, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0
        else { throw UpdateCenterError.sourceDependencyLockInvalid }
        return try BoundedLocalData.read(from: url, maximumBytes: 2 * 1_024 * 1_024)
    }

    nonisolated private static func cargoLockfileSHA256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func runSourceCargoFetch(
        repository: URL,
        sandbox: PreparedSourceBuildSandbox,
        logURL: URL,
        offline: Bool
    ) throws {
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: offline ? sandbox.compileProfile : sandbox.fetchProfile,
                executable: sandbox.cargoExecutable,
                arguments: offline ? ["fetch", "--offline"] : ["fetch", "--locked"]
            ),
            currentDirectory: repository, environment: sandbox.environment,
            timeout: offline ? 120 : 30 * 60, logURL: logURL
        )
    }
}
