import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func loadServiceConfiguration() throws -> ServiceConfiguration {
        let attributes = try FileManager.default.attributesOfItem(atPath: operatorConfig)
        guard (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == 0,
            ((attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o777) & 0o077 == 0
        else { throw HelperFailure.service("configuration ownership or permissions are unsafe") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let configuration = try decoder.decode(
            ServiceConfiguration.self,
            from: readSecureRegularFile(
                URL(fileURLWithPath: operatorConfig),
                maximumBytes: 64_000,
                requiredOwner: 0
            )
        )
        guard configuration.schemaVersion == 1,
            getpwuid(uid_t(configuration.controllerUID)) != nil,
            configuration.controllerRequirement.count < 4_096
        else { throw HelperFailure.service("configuration is invalid") }
        return configuration
    }

    static func controllerRequirement(forCertificate certificateURL: URL) throws -> String {
        let digest = try controllerCertificateDigest(certificateURL)
        return "identifier \"\(permanentAppIdentifier)\" and certificate leaf = H\"\(digest)\""
    }

    static func legacyControllerRequirement(forCertificate certificateURL: URL) throws -> String {
        let digest = try controllerCertificateDigest(certificateURL)
        return "identifier \"\(legacyAppIdentifier)\" and certificate leaf = H\"\(digest)\""
    }

    static func transitionalControllerRequirement(forCertificate certificateURL: URL) throws -> String {
        let digest = try controllerCertificateDigest(certificateURL)
        return
            "(identifier \"\(legacyAppIdentifier)\" or identifier \"\(permanentAppIdentifier)\") and certificate leaf = H\"\(digest)\""
    }

    static func controllerCertificateDigest(_ certificateURL: URL) throws -> String {
        var info = stat()
        guard lstat(certificateURL.path, &info) == 0,
            (info.st_mode & S_IFMT) == S_IFREG,
            info.st_size > 0,
            info.st_size < 64_000,
            let leaf = SecCertificateCreateWithData(
                nil,
                try readSecureRegularFile(certificateURL, maximumBytes: 64_000) as CFData
            ),
            SecCertificateCopySubjectSummary(leaf) as String? == AppReleaseIdentity.subjectSummary
        else { throw HelperFailure.migration("the bundled project signing certificate is invalid") }
        return Insecure.SHA1.hash(data: SecCertificateCopyData(leaf) as Data)
            .map { String(format: "%02x", $0) }.joined()
    }

    static func verifyProjectSignedComponent(
        _ componentURL: URL,
        certificateDigest digest: String
    ) throws {
        var requirement: SecRequirement?
        guard
            SecRequirementCreateWithString(
                "certificate leaf = H\"\(digest)\"" as CFString,
                [],
                &requirement
            ) == errSecSuccess,
            let requirement
        else { throw HelperFailure.migration("the project component requirement is invalid") }
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(componentURL as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode
        else { throw HelperFailure.migration("a copied service component is not signed code") }
        let strictFlags = SecCSFlags(rawValue: (1 << 0) | (1 << 3) | (1 << 4))
        guard SecStaticCodeCheckValidity(staticCode, strictFlags, requirement) == errSecSuccess else {
            throw HelperFailure.migration(
                "a copied service component does not match the pinned project certificate"
            )
        }
    }

    static func migrateLegacyControllerRequirementIfNeeded(
        _ configuration: ServiceConfiguration
    ) throws -> ServiceConfiguration {
        let certificateURL = URL(
            fileURLWithPath: "/Applications/QuilNode.app/Contents/Resources/\(AppReleaseIdentity.certificateFileName)"
        )
        let legacy = try legacyControllerRequirement(forCertificate: certificateURL)
        guard configuration.controllerRequirement == legacy else { return configuration }
        var migrated = configuration
        migrated.controllerRequirement = try transitionalControllerRequirement(forCertificate: certificateURL)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try writeRootFile(try encoder.encode(migrated), to: operatorConfig, mode: 0o600)
        return migrated
    }

    static func writeRootPlist(_ plist: [String: Any], to path: String) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try writeRootFile(data, to: path, mode: 0o644)
    }

    static func writeRootFile(_ data: Data, to path: String, mode: mode_t) throws {
        let temporary = "\(path).quilnode-\(getpid()).tmp"
        try data.write(to: URL(fileURLWithPath: temporary), options: [.atomic])
        guard chown(temporary, 0, 0) == 0,
            chmod(temporary, mode) == 0,
            rename(temporary, path) == 0
        else {
            unlink(temporary)
            throw HelperFailure.command("Unable to install \(URL(fileURLWithPath: path).lastPathComponent)")
        }
    }

    static func recursivelySetOwner(_ root: URL, uid: uid_t, gid: gid_t) throws {
        var rootInfo = stat()
        guard lstat(root.path, &rootInfo) == 0, (rootInfo.st_mode & S_IFMT) == S_IFDIR else {
            throw HelperFailure.migration("runtime path is missing or symbolic")
        }
        guard lchown(root.path, uid, gid) == 0 else {
            throw HelperFailure.migration("unable to update runtime directory ownership")
        }
        let keys: [URLResourceKey] = [.isSymbolicLinkKey]
        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            )
        else { throw HelperFailure.migration("unable to enumerate runtime data") }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true, lchown(url.path, uid, gid) == 0 else {
                throw HelperFailure.migration("unsafe symbolic link or ownership failure in runtime data")
            }
        }
    }
}
