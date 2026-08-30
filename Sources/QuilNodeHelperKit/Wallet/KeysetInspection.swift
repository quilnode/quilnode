import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func inspectKeyset(_ directory: URL) throws -> KeysetInspectionPayload {
        let configURL = directory.appendingPathComponent("config.yml")
        let keysURL = directory.appendingPathComponent("keys.yml")
        let hasConfig = FileManager.default.fileExists(atPath: configURL.path)
        let hasKeys = FileManager.default.fileExists(atPath: keysURL.path)
        guard hasConfig, hasKeys else {
            return .init(
                format: .empty, health: .incomplete, requiresMigration: false, keyCount: 0, keyTypes: [],
                fingerprint: keysetFingerprint(nil, nil),
                warnings: ["A complete keyset requires both config.yml and keys.yml."], hasConfig: hasConfig,
                hasKeys: hasKeys)
        }
        try validateSensitiveRegularFile(configURL, maximumBytes: 2_000_000)
        try validateSensitiveRegularFile(keysURL, maximumBytes: 20_000_000)
        let configData = try readSecureRegularFile(configURL, maximumBytes: 2_000_000)
        let keysData = try readSecureRegularFile(keysURL, maximumBytes: 20_000_000)
        guard let config = String(data: configData, encoding: .utf8),
            let keys = String(data: keysData, encoding: .utf8)
        else {
            return .init(
                format: .unreadable, health: .invalid, requiresMigration: false, keyCount: 0, keyTypes: [],
                fingerprint: keysetFingerprint(configData, keysData),
                warnings: ["The selected files are not readable Quilibrium YAML."], hasConfig: true, hasKeys: true)
        }

        let peerLength = regexCapture(#"(?m)^\s*peerPrivKey:\s*['\"]?([0-9a-fA-F]+)"#, in: config)?.count ?? 0
        let encryption = regexCapture(#"(?m)^\s*encryptionKey:\s*['\"]?([0-9a-fA-F]+)"#, in: config)
        let entries = keyEntrySummaries(keys)
        let current = entries.contains { $0.0 == "q-prover-key" && $0.1 == 8 }
        let old = entries.contains { ($0.0 == "q-prover-key" || $0.0 == "default-proving-key") && $0.1 != 8 }
        let walletKeys = entries.contains { $0.0 == "q-view-key" } && entries.contains { $0.0 == "q-spend-key" }
        var warnings: [String] = []
        if peerLength < 114 { warnings.append("The Ed448 seniority root is missing or malformed.") }
        if encryption?.count != 64 { warnings.append("The keystore encryption key is missing or malformed.") }
        if encryption?.allSatisfy({ $0 == "0" }) == true { warnings.append("The keystore encryption key is all-zero.") }
        if entries.isEmpty { warnings.append("keys.yml contains no generated key entries yet.") }

        let format: NodeKeysetFormat
        let health: KeysetHealth
        let migration: Bool
        let usableEncryption =
            encryption?.count == 64
            && encryption?.allSatisfy({ $0 == "0" }) == false
        if current {
            format = walletKeys ? .current25 : .transitional25
            migration = !walletKeys
            health =
                peerLength < 114 || !usableEncryption
                ? .invalid
                : (migration ? .migrationRequired : .ready)
        } else if old || peerLength >= 114 {
            format = .legacyPre25
            migration = true
            health = peerLength >= 114 && usableEncryption ? .migrationRequired : .invalid
        } else if entries.isEmpty {
            format = .empty
            migration = false
            health = .incomplete
        } else {
            format = .unreadable
            migration = false
            health = .invalid
        }
        return .init(
            format: format, health: health, requiresMigration: migration,
            keyCount: entries.count,
            keyTypes: Array(Set(entries.map { keyTypeLabel($0.1) })).sorted(),
            fingerprint: keysetFingerprint(configData, keysData), warnings: warnings,
            hasConfig: true, hasKeys: true
        )
    }

    static func readWalletManifest(
        _ path: String,
        configuration: ServiceConfiguration
    ) throws -> WalletTransactionManifest {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let home = try controllerHome(configuration)
        let root = home.appendingPathComponent("Library/Application Support/QuilNode/WalletStaging", isDirectory: true)
        guard url.lastPathComponent == "wallet-transaction.json",
            url.path.hasPrefix(root.path + "/")
        else { throw HelperFailure.unsafeStage("wallet manifest is outside QuilNode's fixed staging directory") }
        try validatePathWithoutSymlinks(url, permittedRoot: root)
        try validateControllerFile(url, configuration: configuration, maximumBytes: 64_000)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            WalletTransactionManifest.self,
            from: readSecureRegularFile(
                url,
                maximumBytes: 64_000,
                requiredOwner: uid_t(configuration.controllerUID)
            )
        )
    }

    enum SelectedDirectoryPurpose: Equatable {
        case keysetSource
        case recoveryDestination
    }

    /// Treats an NSOpenPanel-selected path as a narrow capability, never as an
    /// arbitrary privileged filesystem request. Only the controller's home and
    /// mounted volumes are eligible; system and node-runtime paths are denied.
    static func validateOperatorSelectedDirectory(
        _ path: String,
        configuration: ServiceConfiguration,
        purpose: SelectedDirectoryPurpose
    ) throws -> URL {
        let directory = URL(fileURLWithPath: path).standardizedFileURL
        let home = try controllerHome(configuration)
        let allowedRoots = [home, URL(fileURLWithPath: "/Volumes", isDirectory: true)]
        guard
            allowedRoots.contains(where: {
                directory.path == $0.path || directory.path.hasPrefix($0.path + "/")
            }),
            !directory.path.hasPrefix(nodeDirectory.path + "/"),
            directory.path != nodeDirectory.path
        else {
            throw HelperFailure.unsafeStage("the selected folder is outside the operator's home and mounted volumes")
        }
        guard
            let root = allowedRoots.first(where: {
                directory.path == $0.path || directory.path.hasPrefix($0.path + "/")
            })
        else { throw HelperFailure.unsafeStage("the selected folder has no permitted root") }
        try validatePathWithoutSymlinks(directory, permittedRoot: root)

        var info = stat()
        guard lstat(directory.path, &info) == 0,
            (info.st_mode & S_IFMT) == S_IFDIR,
            info.st_uid == configuration.controllerUID || info.st_uid == 0
        else { throw HelperFailure.unsafeStage("the selected folder ownership or type is unsafe") }

        if purpose == .keysetSource {
            for name in ["config.yml", "keys.yml"] {
                let file = directory.appendingPathComponent(name)
                try validateControllerSelectedFile(
                    file,
                    configuration: configuration,
                    maximumBytes: name == "config.yml" ? 2_000_000 : 20_000_000
                )
            }
        }
        return directory
    }

    static func validateControllerSelectedFile(
        _ url: URL,
        configuration: ServiceConfiguration,
        maximumBytes: UInt64
    ) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0,
            (info.st_mode & S_IFMT) == S_IFREG,
            info.st_nlink == 1,
            info.st_uid == configuration.controllerUID,
            info.st_size > 0,
            UInt64(info.st_size) <= maximumBytes,
            info.st_mode & 0o022 == 0
        else {
            throw HelperFailure.unsafeStage(
                "the selected \(url.lastPathComponent) ownership, links, size, or permissions are unsafe")
        }
    }

    static func validatePathWithoutSymlinks(_ url: URL, permittedRoot: URL) throws {
        guard url.path == permittedRoot.path || url.path.hasPrefix(permittedRoot.path + "/") else {
            throw HelperFailure.unsafeStage("path escapes its fixed staging root")
        }
        var current = URL(fileURLWithPath: "/")
        for component in url.pathComponents.dropFirst() {
            current.appendPathComponent(component)
            var info = stat()
            guard lstat(current.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else {
                throw HelperFailure.unsafeStage("a wallet staging path component is missing or symbolic")
            }
        }
    }

    static func validateControllerFile(_ url: URL, configuration: ServiceConfiguration, maximumBytes: UInt64) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
            info.st_nlink == 1, info.st_uid == configuration.controllerUID,
            info.st_size > 0, UInt64(info.st_size) <= maximumBytes,
            info.st_mode & 0o022 == 0
        else { throw HelperFailure.unsafeStage("wallet staging file ownership or permissions are unsafe") }
    }

    static func validateSensitiveRegularFile(_ url: URL, maximumBytes: UInt64) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
            info.st_nlink == 1, info.st_size > 0, UInt64(info.st_size) <= maximumBytes,
            info.st_mode & 0o022 == 0
        else { throw HelperFailure.unsafeStage("\(url.lastPathComponent) is not a safe keyset file") }
    }

    /// Opens first, validates the opened object, and reads only through that
    /// descriptor. A second metadata check rejects concurrent mutation. This is
    /// the primitive for key material and other attacker-influenced manifests;
    /// path-based `lstat` followed by a separate open is not a security check.
    static func readSecureRegularFile(
        _ url: URL,
        maximumBytes: UInt64,
        requiredOwner: uid_t? = nil
    ) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else {
            throw HelperFailure.unsafeStage("\(url.lastPathComponent) could not be opened safely")
        }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_nlink == 1,
            before.st_size > 0,
            UInt64(before.st_size) <= maximumBytes,
            before.st_mode & 0o022 == 0,
            requiredOwner == nil || before.st_uid == requiredOwner
        else {
            throw HelperFailure.unsafeStage("\(url.lastPathComponent) failed secure file validation")
        }

        var result = Data()
        result.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while result.count < Int(before.st_size) {
            let requested = min(buffer.count, Int(before.st_size) - result.count)
            let count = Darwin.read(descriptor, &buffer, requested)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else {
                throw HelperFailure.unsafeStage("\(url.lastPathComponent) changed while it was read")
            }
            result.append(buffer, count: count)
        }

        var after = stat()
        guard fstat(descriptor, &after) == 0,
            before.st_dev == after.st_dev,
            before.st_ino == after.st_ino,
            before.st_size == after.st_size,
            before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
            before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
        else {
            throw HelperFailure.unsafeStage("\(url.lastPathComponent) changed during secure read")
        }
        return result
    }

}
