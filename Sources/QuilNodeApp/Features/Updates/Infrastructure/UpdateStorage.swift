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
    nonisolated static func newStagingDirectory(prefix: String) throws -> URL {
        let safePrefix = prefix.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]"#, with: "-", options: .regularExpression
        )
        let root = try applicationSupportDirectory().appendingPathComponent("UpdateStaging", isDirectory: true)
        try PrivateLocalFileSystem.ensureDirectory(at: root)
        let directory = root.appendingPathComponent("\(safePrefix)-\(UUID().uuidString)", isDirectory: true)
        try PrivateLocalFileSystem.createExclusiveDirectory(at: directory)
        return directory
    }

    nonisolated static func applicationSupportDirectory() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw UpdateCenterError.applicationSupportUnavailable
        }
        let directory = base.appendingPathComponent("QuilNode", isDirectory: true)
        try PrivateLocalFileSystem.ensureDirectory(at: directory)
        return directory
    }

    nonisolated static func retainBuildLog(
        _ source: URL?,
        manifest: UpdateActivationManifest
    ) -> URL? {
        guard let source else { return nil }
        do {
            let support = try applicationSupportDirectory()
            let stagingRoot = support.appendingPathComponent("UpdateStaging", isDirectory: true)
            guard
                let sourceData = try? TrustedLocalFile.read(
                    source,
                    inside: stagingRoot,
                    relativeDepth: 2,
                    allowedFileNames: ["build.log"],
                    maximumBytes: 128 * 1_024 * 1_024,
                    allowGrowth: true
                )
            else { return nil }

            let root = support.appendingPathComponent("BuildLogs", isDirectory: true)
            try PrivateLocalFileSystem.ensureDirectory(at: root)
            let commit = manifest.commit.map { String($0.prefix(8)) } ?? "signed"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let identity = "\(manifest.channel)-\(manifest.version)-\(commit)".replacingOccurrences(
                of: #"[^A-Za-z0-9._-]"#,
                with: "-",
                options: .regularExpression
            )
            let destination = root.appendingPathComponent(
                "\(identity)-\(formatter.string(from: Date())).log"
            )
            try PrivateLocalFileSystem.write(sourceData, atomicallyTo: destination)

            let logs = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "log" }.sorted {
                let left =
                    (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? .distantPast
                let right =
                    (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? .distantPast
                return left > right
            }
            for oldLog in logs.dropFirst(10) { try? FileManager.default.removeItem(at: oldLog) }
            return destination
        } catch {
            return nil
        }
    }

    nonisolated static func writeManifest(_ manifest: UpdateActivationManifest, directory: URL) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = directory.appendingPathComponent("activation.json")
        try PrivateLocalFileSystem.write(try encoder.encode(manifest), atomicallyTo: url)
        return url
    }

    nonisolated static func decodeManifest(at url: URL) throws -> UpdateActivationManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            UpdateActivationManifest.self,
            from: BoundedLocalData.read(from: url, maximumBytes: 64 * 1_024)
        )
    }

    nonisolated static func validatedRestoredLogURL(_ path: String?) -> URL? {
        guard let path, let support = try? applicationSupportDirectory() else { return nil }
        let candidate = URL(fileURLWithPath: path)
        let staging = support.appendingPathComponent("UpdateStaging", isDirectory: true)
        if let staged = TrustedLocalFile.validate(
            candidate,
            inside: staging,
            relativeDepth: 2,
            allowedFileNames: ["build.log"]
        ) {
            return staged
        }
        let retained = support.appendingPathComponent("BuildLogs", isDirectory: true)
        return TrustedLocalFile.validate(
            candidate,
            inside: retained,
            relativeDepth: 1,
            allowedPathExtensions: ["log"]
        )
    }

    nonisolated static func restoredManifest(_ path: String?) -> (URL, UpdateActivationManifest)? {
        guard let path, let support = try? applicationSupportDirectory() else { return nil }
        let candidate = URL(fileURLWithPath: path)
        let root = support.appendingPathComponent("UpdateStaging", isDirectory: true)
        guard
            let data = try? TrustedLocalFile.read(
                candidate,
                inside: root,
                relativeDepth: 2,
                allowedFileNames: ["activation.json"],
                maximumBytes: 64 * 1_024
            )
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(UpdateActivationManifest.self, from: data) else { return nil }
        return (candidate.standardizedFileURL, manifest)
    }

    nonisolated static func parseNodeVersion(at url: URL) -> String? {
        guard let data = try? BoundedLocalData.read(from: url, maximumBytes: 2 * 1_024 * 1_024) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        guard
            let regex = try? NSRegularExpression(
                pattern: #"VERSION_STRING\s*:\s*&str\s*=\s*\"([0-9]+(?:\.[0-9]+){2,})\""#),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    nonisolated static func sha256(of url: URL) -> String? {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        var before = stat()
        guard fstat(descriptor, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_nlink == 1,
            before.st_size > 0,
            before.st_size <= 1_024 * 1_024 * 1_024
        else { return nil }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 4 * 1_024 * 1_024)
        var total: off_t = 0
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { return nil }
            if count == 0 { break }
            total += off_t(count)
            guard total <= before.st_size else { return nil }
            hasher.update(data: Data(buffer.prefix(count)))
        }
        var after = stat()
        guard total == before.st_size,
            fstat(descriptor, &after) == 0,
            before.st_dev == after.st_dev,
            before.st_ino == after.st_ino,
            before.st_mode == after.st_mode,
            before.st_nlink == after.st_nlink,
            before.st_uid == after.st_uid,
            before.st_gid == after.st_gid,
            before.st_size == after.st_size,
            before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
            before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
            before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
            before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
        else { return nil }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
