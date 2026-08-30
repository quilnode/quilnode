import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func prepareExternalRecoveryExport(
        id: UUID,
        parentPath: String,
        configuration: ServiceConfiguration
    ) throws -> String {
        let registry = try loadWalletRegistry()
        guard let profile = registry.profiles.first(where: { $0.id == id }) else {
            throw HelperFailure.service("the selected identity package no longer exists")
        }
        let exportRoot = try validateOperatorSelectedDirectory(
            parentPath,
            configuration: configuration,
            purpose: .recoveryDestination
        )
        let safeName = profile.name.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]+"#,
            with: "-",
            options: .regularExpression
        )
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let destination = exportRoot.appendingPathComponent(
            "QuilNode-Recovery-\(safeName)-\(stamp)-\(UUID().uuidString.prefix(8))",
            isDirectory: true
        )
        let source = walletProfiles.appendingPathComponent(profile.directoryName, isDirectory: true)
        let sourceInspection = try inspectKeyset(source)
        let configData = try readSecureRegularFile(
            source.appendingPathComponent("config.yml"),
            maximumBytes: 2_000_000,
            requiredOwner: serviceUID
        )
        let keysData = try readSecureRegularFile(
            source.appendingPathComponent("keys.yml"),
            maximumBytes: 20_000_000,
            requiredOwner: serviceUID
        )

        // Bind every destination operation to open directory descriptors. The
        // selected parent is user-writable by design; path-based copies would
        // let a same-user process rename or replace the new directory between
        // validation and a root write.
        let parentFD = open(exportRoot.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else {
            throw HelperFailure.service("the selected recovery destination could not be opened safely")
        }
        defer { close(parentFD) }
        let destinationName = destination.lastPathComponent
        guard mkdirat(parentFD, destinationName, 0o700) == 0 else {
            throw HelperFailure.service("the unique recovery destination could not be created")
        }
        let destinationFD = openat(
            parentFD,
            destinationName,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard destinationFD >= 0 else {
            _ = unlinkat(parentFD, destinationName, AT_REMOVEDIR)
            throw HelperFailure.service("the recovery destination changed during creation")
        }
        defer { close(destinationFD) }
        var completedFiles: [String] = []
        do {
            try writeVerifiedExportFile(
                configData,
                named: "config.yml",
                directoryFD: destinationFD,
                owner: uid_t(configuration.controllerUID)
            )
            completedFiles.append("config.yml")
            try writeVerifiedExportFile(
                keysData,
                named: "keys.yml",
                directoryFD: destinationFD,
                owner: uid_t(configuration.controllerUID)
            )
            completedFiles.append("keys.yml")
            guard sourceInspection.fingerprint == keysetFingerprint(configData, keysData) else {
                throw HelperFailure.service("the recovery copy failed cryptographic hash verification")
            }
            let manifest =
                "QuilNode recovery export\nIdentity: \(profile.name)\nFingerprint: \(sourceInspection.fingerprint)\nCreated: \(ISO8601DateFormatter().string(from: Date()))\nKeep config.yml and keys.yml together in encrypted offline storage.\n"
            try writeVerifiedExportFile(
                Data(manifest.utf8),
                named: "RECOVERY.txt",
                directoryFD: destinationFD,
                owner: uid_t(configuration.controllerUID)
            )
            completedFiles.append("RECOVERY.txt")
            guard fsync(destinationFD) == 0,
                fchown(destinationFD, uid_t(configuration.controllerUID), 20) == 0,
                fchmod(destinationFD, 0o700) == 0
            else { throw HelperFailure.service("unable to finalize recovery export ownership") }
        } catch {
            for name in completedFiles { _ = unlinkat(destinationFD, name, 0) }
            _ = unlinkat(parentFD, destinationName, AT_REMOVEDIR)
            throw error
        }
        return destination.path
    }

    static func writeVerifiedExportFile(
        _ data: Data,
        named name: String,
        directoryFD: Int32,
        owner: uid_t
    ) throws {
        guard ["config.yml", "keys.yml", "RECOVERY.txt"].contains(name) else {
            throw HelperFailure.service("an unexpected recovery filename was rejected")
        }
        let descriptor = openat(
            directoryFD,
            name,
            O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard descriptor >= 0 else {
            throw HelperFailure.service("unable to create \(name) exclusively")
        }
        defer { close(descriptor) }
        var writeFailure = false
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(descriptor, base.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else {
                    writeFailure = true
                    return
                }
                offset += count
            }
        }
        guard !writeFailure,
            fsync(descriptor) == 0,
            fchown(descriptor, owner, 20) == 0,
            fchmod(descriptor, 0o600) == 0,
            try readBackExportFile(descriptor, expectedBytes: data.count) == data
        else {
            _ = unlinkat(directoryFD, name, 0)
            throw HelperFailure.service("recovery file \(name) failed write-back verification")
        }
    }

    static func readBackExportFile(_ descriptor: Int32, expectedBytes: Int) throws -> Data {
        var result = Data()
        result.reserveCapacity(expectedBytes)
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        var offset: off_t = 0
        while result.count < expectedBytes {
            let requested = min(buffer.count, expectedBytes - result.count)
            let count = pread(descriptor, &buffer, requested, offset)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else {
                throw HelperFailure.service("recovery file changed during verification")
            }
            result.append(buffer, count: count)
            offset += off_t(count)
        }
        var extra: UInt8 = 0
        guard pread(descriptor, &extra, 1, offset) == 0 else {
            throw HelperFailure.service("recovery file size changed during verification")
        }
        return result
    }
}
