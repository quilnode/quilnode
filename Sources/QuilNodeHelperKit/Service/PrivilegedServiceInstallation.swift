import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func createServiceAccount() throws {
        if let existing = getpwnam(serviceUser) {
            guard existing.pointee.pw_uid == serviceUID,
                existing.pointee.pw_gid == serviceGID
            else { throw HelperFailure.migration("an incompatible _quilnode account already exists") }
            return
        }
        guard getpwuid(serviceUID) == nil, getgrgid(serviceGID) == nil else {
            throw HelperFailure.migration("UID or GID 350 is already assigned")
        }
        let dscl = URL(fileURLWithPath: "/usr/bin/dscl")
        let commands = [
            [".", "-create", "/Groups/\(serviceGroup)"],
            [".", "-create", "/Groups/\(serviceGroup)", "PrimaryGroupID", "\(serviceGID)"],
            [".", "-create", "/Groups/\(serviceGroup)", "RealName", "QuilNode Service"],
            [".", "-create", "/Users/\(serviceUser)"],
            [".", "-create", "/Users/\(serviceUser)", "UniqueID", "\(serviceUID)"],
            [".", "-create", "/Users/\(serviceUser)", "PrimaryGroupID", "\(serviceGID)"],
            [".", "-create", "/Users/\(serviceUser)", "UserShell", "/usr/bin/false"],
            [".", "-create", "/Users/\(serviceUser)", "NFSHomeDirectory", "/var/empty"],
            [".", "-create", "/Users/\(serviceUser)", "IsHidden", "1"],
        ]
        for arguments in commands { _ = try run(dscl, arguments, timeout: 15) }
        guard let created = getpwnam(serviceUser),
            created.pointee.pw_uid == serviceUID,
            created.pointee.pw_gid == serviceGID
        else { throw HelperFailure.migration("the restricted service account was not created correctly") }
    }

    static func installOperatorService(
        from sourceHelper: URL,
        signingCertificate: URL,
        controllerUID: UInt32,
        requirement: String
    ) throws {
        let fm = FileManager.default
        let signingDigest = try controllerCertificateDigest(signingCertificate)
        guard requirement.contains("certificate leaf = H\"\(signingDigest)\"") else {
            throw HelperFailure.migration("the component certificate does not match the controller requirement")
        }
        let sourceVerifier = sourceHelper.deletingLastPathComponent()
            .appendingPathComponent("QuilNodeReleaseVerifier")
        try validateRegularFile(sourceVerifier, maximumBytes: 40_000_000)
        try fm.createDirectory(
            at: URL(fileURLWithPath: operatorSupport, isDirectory: true),
            withIntermediateDirectories: true
        )
        guard chown(operatorSupport, 0, 0) == 0,
            chmod(operatorSupport, 0o700) == 0
        else { throw HelperFailure.migration("unable to secure the service support directory") }
        let temporaryBinary = "\(operatorBinary).\(getpid()).tmp"
        try? fm.removeItem(atPath: temporaryBinary)
        try fm.copyItem(atPath: sourceHelper.path, toPath: temporaryBinary)
        let temporaryVerifier = "\(operatorVerifier).\(getpid()).tmp"
        try? fm.removeItem(atPath: temporaryVerifier)
        try fm.copyItem(atPath: sourceVerifier.path, toPath: temporaryVerifier)

        // The source bundle remains user-visible while this root operation is
        // running. Verify the exact bytes after they have crossed into the
        // root-only 0700 directory, closing the bundle-validation-to-copy race.
        // Both nested executables must carry the same pinned project leaf.
        try verifyProjectSignedComponent(
            URL(fileURLWithPath: temporaryBinary),
            certificateDigest: signingDigest
        )
        try verifyProjectSignedComponent(
            URL(fileURLWithPath: temporaryVerifier),
            certificateDigest: signingDigest
        )
        // The app uses the stable local certificate so clients have a durable
        // identity. Root launchd does not inherit that per-user trust setting,
        // so install the already-verified helper with a local ad-hoc signature.
        // Root ownership and the fixed path protect this executable; caller
        // authorization is independently pinned to the app certificate below.
        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            ["--force", "--sign", "-", "--options", "runtime", "--timestamp=none", temporaryBinary],
            timeout: 30
        )
        // Finder/Codex may attach transport provenance to the app bundle. The
        // helper was already verified as part of that signed bundle; remove
        // transport-only metadata from the root-owned installed copy so launchd
        // can execute it without a second Gatekeeper interaction.
        _ = removexattr(temporaryBinary, "com.apple.quarantine", 0)
        _ = removexattr(temporaryBinary, "com.apple.provenance", 0)
        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            ["--verify", "--strict", temporaryBinary],
            timeout: 30
        )
        guard chown(temporaryBinary, 0, 0) == 0,
            chmod(temporaryBinary, 0o755) == 0
        else { throw HelperFailure.migration("unable to prepare the root-owned service executable") }

        _ = removexattr(temporaryVerifier, "com.apple.quarantine", 0)
        _ = removexattr(temporaryVerifier, "com.apple.provenance", 0)
        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            ["--force", "--sign", "-", "--options", "runtime", "--timestamp=none", temporaryVerifier],
            timeout: 30
        )
        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            ["--verify", "--strict", temporaryVerifier],
            timeout: 30
        )
        guard chown(temporaryVerifier, 0, 0) == 0,
            chmod(temporaryVerifier, 0o755) == 0,
            rename(temporaryVerifier, operatorVerifier) == 0,
            rename(temporaryBinary, operatorBinary) == 0
        else { throw HelperFailure.migration("unable to atomically install the root-owned service components") }

        let configuration = ServiceConfiguration(
            controllerUID: controllerUID,
            controllerRequirement: requirement,
            installedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try writeRootFile(try encoder.encode(configuration), to: operatorConfig, mode: 0o600)

        let plist: [String: Any] = [
            "Label": operatorLabel,
            "ProgramArguments": [operatorBinary, "serve"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
            "StandardOutPath": "/var/log/quilnode-operator.log",
            "StandardErrorPath": "/var/log/quilnode-operator.log",
        ]
        try writeRootPlist(plist, to: operatorPlist)
    }

    /// Replaces the privileged service from the already authenticated, sealed
    /// app bundle. The pinned certificate must remain identical. This is the
    /// durable passwordless path for future QuilNode releases; a certificate
    /// rotation intentionally falls back to one explicit macOS authorization.
    static func upgradeOperatorService(configuration: ServiceConfiguration) throws -> String {
        let appURL = URL(fileURLWithPath: "/Applications/QuilNode.app", isDirectory: true)
        let sourceHelper = appURL.appendingPathComponent("Contents/Helpers/QuilNodeHelper")
        let certificateURL = appURL.appendingPathComponent(
            "Contents/Resources/\(AppReleaseIdentity.certificateFileName)"
        )
        guard FileManager.default.isExecutableFile(atPath: sourceHelper.path) else {
            throw HelperFailure.service("the signed app does not contain its privileged service")
        }
        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            ["--verify", "--deep", "--strict", appURL.path],
            timeout: 30
        )
        let newRequirement = try controllerRequirement(forCertificate: certificateURL)
        let transitionRequirement = try transitionalControllerRequirement(forCertificate: certificateURL)
        guard
            newRequirement == configuration.controllerRequirement
                || transitionRequirement == configuration.controllerRequirement
        else {
            throw HelperFailure.service("the app signing identity changed; explicit macOS authorization is required")
        }
        try installOperatorService(
            from: sourceHelper,
            signingCertificate: certificateURL,
            controllerUID: configuration.controllerUID,
            requirement: newRequirement
        )

        // Return the authenticated response before replacing this running
        // process. launchd then starts the newly installed binary at the same
        // fixed path; no credential or arbitrary executable is involved.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75) {
            _ = try? runLaunchctl(["kickstart", "-k", operatorTarget])
        }
        return "Secure local service update installed; launchd is switching to it now."
    }
}
