import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func prepareWalletVault() throws {
        for directory in [walletRoot, walletProfiles, walletRecovery] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard chown(directory.path, 0, serviceGID) == 0, chmod(directory.path, 0o700) == 0 else {
                throw HelperFailure.service("unable to secure the identity recovery vault")
            }
        }
    }

    static func loadWalletRegistry() throws -> WalletRegistry {
        guard FileManager.default.fileExists(atPath: walletRegistryURL.path) else {
            return WalletRegistry(activeKeysetID: nil, profiles: [])
        }
        try validateSensitiveRegularFile(walletRegistryURL, maximumBytes: 2_000_000)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let registry = try decoder.decode(
            WalletRegistry.self,
            from: readSecureRegularFile(
                walletRegistryURL,
                maximumBytes: 2_000_000,
                requiredOwner: 0
            )
        )
        guard registry.schemaVersion == 1 else { throw HelperFailure.service("wallet registry version is unsupported") }
        return registry
    }

    static func saveWalletRegistry(_ registry: WalletRegistry) throws {
        try prepareWalletVault()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try writeRootFile(try encoder.encode(registry), to: walletRegistryURL.path, mode: 0o600)
    }

    static func replaceKeysetFiles(from source: URL, to destination: URL) throws {
        let inspection = try inspectKeyset(source)
        guard inspection.health != .invalid, inspection.health != .incomplete else {
            throw HelperFailure.service("refusing to copy an incomplete identity package")
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        guard chown(destination.path, serviceUID, serviceGID) == 0, chmod(destination.path, 0o700) == 0 else {
            throw HelperFailure.service("unable to secure the identity package directory")
        }
        for name in ["config.yml", "keys.yml"] {
            let data = try readSecureRegularFile(
                source.appendingPathComponent(name),
                maximumBytes: name == "config.yml" ? 2_000_000 : 20_000_000
            )
            try atomicWriteKeysetFile(data, to: destination.appendingPathComponent(name))
        }
        let copied = try inspectKeyset(destination)
        guard copied.fingerprint == inspection.fingerprint else {
            throw HelperFailure.service("identity package verification failed after copy")
        }
    }

    /// The official qclient intentionally creates config.yml plus a `null:`
    /// keys.yml placeholder; the official node fills the complete standard key
    /// set on first start. This path is accepted only for a profile created in
    /// this transaction, never for an imported or user-supplied keyset.
    static func copyFreshPlaceholder(from source: URL, to destination: URL) throws {
        let config = source.appendingPathComponent("config.yml")
        let keys = source.appendingPathComponent("keys.yml")
        try validateSensitiveRegularFile(config, maximumBytes: 2_000_000)
        try validateSensitiveRegularFile(keys, maximumBytes: 20_000_000)
        let keysData = try readSecureRegularFile(keys, maximumBytes: 20_000_000)
        guard String(data: keysData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "null:" else {
            throw HelperFailure.service("fresh identity generation returned an unexpected placeholder")
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        guard chown(destination.path, serviceUID, serviceGID) == 0, chmod(destination.path, 0o700) == 0 else {
            throw HelperFailure.service("unable to secure the fresh identity directory")
        }
        try atomicWriteKeysetFile(
            try readSecureRegularFile(config, maximumBytes: 2_000_000),
            to: destination.appendingPathComponent("config.yml")
        )
        try atomicWriteKeysetFile(keysData, to: destination.appendingPathComponent("keys.yml"))
    }

    /// Switch only identity-bearing material. Network ports, worker counts,
    /// store paths, logging, archive mode, and other machine-specific settings
    /// remain those of this Mac. This prevents an imported server config from
    /// silently redirecting stores or trying to bind stale addresses.
    static func installIdentityOnly(
        from source: URL,
        runtimeConfig: Data,
        to destination: URL,
        allowsFreshPlaceholder: Bool
    ) throws {
        let sourceConfigURL = source.appendingPathComponent("config.yml")
        let sourceKeysURL = source.appendingPathComponent("keys.yml")
        try validateSensitiveRegularFile(sourceConfigURL, maximumBytes: 2_000_000)
        try validateSensitiveRegularFile(sourceKeysURL, maximumBytes: 20_000_000)
        let sourceConfig = try readSecureRegularFile(sourceConfigURL, maximumBytes: 2_000_000)
        let sourceKeys = try readSecureRegularFile(sourceKeysURL, maximumBytes: 20_000_000)
        if allowsFreshPlaceholder {
            guard String(data: sourceKeys, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "null:"
            else {
                throw HelperFailure.service("fresh identity placeholder changed before activation")
            }
        } else {
            let inspection = try inspectKeyset(source)
            guard inspection.health != .invalid, inspection.health != .incomplete else {
                throw HelperFailure.service("the identity package cannot be activated")
            }
        }
        guard let runtimeText = String(data: runtimeConfig, encoding: .utf8),
            let sourceText = String(data: sourceConfig, encoding: .utf8)
        else { throw HelperFailure.service("identity config YAML is unreadable") }
        let merged = try mergeIdentityFields(runtime: runtimeText, source: sourceText)
        try atomicWriteKeysetFile(Data(merged.utf8), to: destination.appendingPathComponent("config.yml"))
        try atomicWriteKeysetFile(sourceKeys, to: destination.appendingPathComponent("keys.yml"))
    }

    static func mergeIdentityFields(runtime: String, source: String) throws -> String {
        guard let sourcePeer = yamlScalar(path: ["p2p", "peerPrivKey"], in: source),
            sourcePeer.range(of: #"^[0-9a-fA-F]{114,}$"#, options: .regularExpression) != nil,
            let sourceEncryption = yamlScalar(path: ["key", "keyManagerFile", "encryptionKey"], in: source),
            sourceEncryption.range(of: #"^[0-9a-fA-F]{64}$"#, options: .regularExpression) != nil
        else { throw HelperFailure.service("the source identity or keystore encryption key is missing or malformed") }
        let provingID = yamlScalar(path: ["engine", "provingKeyId"], in: source)

        var output = runtime
        output = try replacingYAMLScalar(path: ["p2p", "peerPrivKey"], value: sourcePeer, in: output)
        output = try replacingYAMLScalar(
            path: ["key", "keyManagerFile", "encryptionKey"], value: sourceEncryption, in: output)
        if let provingID, !provingID.isEmpty {
            output = try replacingYAMLScalar(path: ["engine", "provingKeyId"], value: provingID, in: output)
        }
        // The installed node always reads the active pair from this fixed path.
        output = try replacingYAMLScalar(
            path: ["key", "keyManagerFile", "path"], value: ".config/keys.yml", in: output)
        return output
    }

    static func yamlScalar(path: [String], in yaml: String) -> String? {
        var parents: [(indent: Int, key: String)] = []
        for raw in yaml.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon])
            while let last = parents.last, last.indent >= indent { parents.removeLast() }
            let fullPath = parents.map(\.key) + [key]
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if fullPath == path {
                return value.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
            if value.isEmpty { parents.append((indent, key)) }
        }
        return nil
    }

    static func replacingYAMLScalar(path: [String], value: String, in yaml: String) throws -> String {
        var parents: [(indent: Int, key: String)] = []
        var found = false
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map { raw -> String in
            let line = String(raw)
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let colon = trimmed.firstIndex(of: ":") else {
                return line
            }
            let key = String(trimmed[..<colon])
            while let last = parents.last, last.indent >= indent { parents.removeLast() }
            let fullPath = parents.map(\.key) + [key]
            let currentValue = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if fullPath == path {
                found = true
                return String(repeating: " ", count: indent) + key + ": " + value
            }
            if currentValue.isEmpty { parents.append((indent, key)) }
            return line
        }
        guard found else {
            throw HelperFailure.service("runtime config is missing required field \(path.joined(separator: "."))")
        }
        return lines.joined(separator: "\n")
    }

    static func atomicWriteKeysetFile(_ data: Data, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: [.atomic])
        guard chown(temporary.path, serviceUID, serviceGID) == 0,
            chmod(temporary.path, 0o600) == 0,
            rename(temporary.path, destination.path) == 0
        else {
            try? FileManager.default.removeItem(at: temporary)
            throw HelperFailure.service("atomic keyset write failed")
        }
    }

    @discardableResult
    static func createRecoveryCopy(from source: URL, keysetID: UUID, reason: String) throws -> Date {
        try prepareWalletVault()
        let date = Date()
        let stamp = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
        let destination = walletRecovery.appendingPathComponent(
            "\(keysetID.uuidString.lowercased())-\(stamp)-\(reason)", isDirectory: true)
        try replaceKeysetFiles(from: source, to: destination)
        let inspection = try inspectKeyset(destination)
        let record: [String: Any] = [
            "schemaVersion": 1,
            "keysetID": keysetID.uuidString,
            "createdAt": ISO8601DateFormatter().string(from: date),
            "reason": reason,
            "fingerprint": inspection.fingerprint,
            "configSHA256": sha256(destination.appendingPathComponent("config.yml")) ?? "",
            "keysSHA256": sha256(destination.appendingPathComponent("keys.yml")) ?? "",
        ]
        let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        try writeRootFile(data, to: destination.appendingPathComponent("recovery-manifest.json").path, mode: 0o600)
        return date
    }

    static func generateFreshConfig(named name: String, in home: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        guard chown(home.path, serviceUID, serviceGID) == 0, chmod(home.path, 0o700) == 0 else {
            throw HelperFailure.service("unable to secure fresh identity generation workspace")
        }
        let (qclient, qclientRecord) = try trustedQClient()
        let trustArguments = qclientRecord.trust == .officialSigned ? ["--signature-check=false"] : ["-y"]
        _ = try run(
            URL(fileURLWithPath: "/usr/bin/sudo"),
            ["-n", "-H", "-u", serviceUser, "--", "/usr/bin/env", "HOME=\(home.path)", qclient.path] + trustArguments
                + ["node", "config", "create", name],
            timeout: 30
        )
    }
}
