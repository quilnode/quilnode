import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func validateLaunchDaemonPlist() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: plistPath)
        let owner = attributes[.ownerAccountID] as? NSNumber
        let permissions = attributes[.posixPermissions] as? NSNumber
        guard owner?.uint32Value == 0 else { throw HelperFailure.unsafePlist("it is not owned by root") }
        guard let mode = permissions?.uint16Value, mode & 0o022 == 0 else {
            throw HelperFailure.unsafePlist("it is writable by group or other users")
        }
        let plist = try readPlist()
        let configuredUser = plist["UserName"] as? String
        let configuredGroup = plist["GroupName"] as? String
        guard plist["Label"] as? String == "com.quilibrium.node",
            let arguments = plist["ProgramArguments"] as? [String],
            arguments == ["/opt/quilibrium/node/quilibrium-node"],
            configuredUser == nil || configuredUser == serviceUser,
            configuredUser == nil || configuredGroup == serviceGroup
        else { throw HelperFailure.unsafePlist("its label or executable does not match the fixed node service") }
    }

    static func performLifecycle(_ action: HelperAction) throws {
        switch action {
        case .start:
            if isLoaded() {
                try runLaunchctl(["kickstart", serviceTarget])
            } else {
                try runLaunchctl(["bootstrap", "system", plistPath])
            }
        case .stop:
            if isLoaded() { try runLaunchctl(["bootout", "system", plistPath]) }
        case .restart:
            if isLoaded() {
                try runLaunchctl(["kickstart", "-k", serviceTarget])
            } else {
                try runLaunchctl(["bootstrap", "system", plistPath])
            }
        default:
            throw HelperFailure.usage
        }
    }

    static func migrate(controllerUID: UInt32) throws {
        guard controllerUID != 0, getpwuid(uid_t(controllerUID)) != nil else {
            throw HelperFailure.migration("the controlling macOS account is invalid")
        }
        try validateLaunchDaemonPlist()

        let sourceHelper = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let appURL = sourceHelper.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard sourceHelper.lastPathComponent == "QuilNodeHelper",
            appURL.path == "/Applications/QuilNode.app",
            FileManager.default.fileExists(atPath: appURL.path)
        else { throw HelperFailure.migration("the installer is not inside /Applications/QuilNode.app") }

        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"), ["--verify", "--deep", "--strict", appURL.path], timeout: 30)
        let certificateURL = appURL.appendingPathComponent(
            "Contents/Resources/\(AppReleaseIdentity.certificateFileName)"
        )
        let requirement = try controllerRequirement(forCertificate: certificateURL)
        try createServiceAccount()
        try installOperatorService(
            from: sourceHelper,
            signingCertificate: certificateURL,
            controllerUID: controllerUID,
            requirement: requirement
        )

        let existingPlist = try readPlist()
        if existingPlist["UserName"] as? String == serviceUser {
            try bootstrapOperatorService()
            print("Secure passwordless service updated; the running non-root node was left untouched.")
            return
        }

        try createMigrationBackup()

        do {
            if isLoaded() { try runLaunchctl(["bootout", "system", plistPath]) }
            try prepareRuntimeOwnership()
            try writeNodeServicePlist(signatureCheck: currentSignatureCheck())
            try runLaunchctl(["bootstrap", "system", plistPath])
            try restartAndValidate(expectedVersion: nil)
            try bootstrapOperatorService()
            print(
                "Secure passwordless service installed. Quilibrium now runs as _quilnode; identity, configuration, and stores were preserved."
            )
        } catch {
            try? rollbackRuntimeMigration(controllerUID: controllerUID)
            try? removeOperatorService()
            throw HelperFailure.migration("\(error). The original root service configuration was restored.")
        }
    }

    /// Installs the smallest possible privileged control plane. Existing node
    /// installations take the proven migration path; a clean Mac receives only
    /// the authenticated operator service and restricted runtime account. The
    /// signed node is downloaded and verified without privilege, then installed
    /// through this service without another password prompt.
    static func bootstrap(controllerUID: UInt32) throws {
        if FileManager.default.fileExists(atPath: plistPath) {
            try migrate(controllerUID: controllerUID)
            return
        }
        guard controllerUID != 0, getpwuid(uid_t(controllerUID)) != nil else {
            throw HelperFailure.migration("the controlling macOS account is invalid")
        }

        let sourceHelper = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let appURL = sourceHelper.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard sourceHelper.lastPathComponent == "QuilNodeHelper",
            appURL.path == "/Applications/QuilNode.app",
            FileManager.default.fileExists(atPath: appURL.path)
        else { throw HelperFailure.migration("the installer is not inside /Applications/QuilNode.app") }

        _ = try run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            ["--verify", "--deep", "--strict", appURL.path],
            timeout: 30
        )
        let certificateURL = appURL.appendingPathComponent(
            "Contents/Resources/\(AppReleaseIdentity.certificateFileName)"
        )
        let requirement = try controllerRequirement(forCertificate: certificateURL)
        try createServiceAccount()
        try installOperatorService(
            from: sourceHelper,
            signingCertificate: certificateURL,
            controllerUID: controllerUID,
            requirement: requirement
        )
        do {
            try bootstrapOperatorService()
            print(
                "Secure QuilNode service authorized. Signed installs, updates, lifecycle controls, and read-only inspection are passwordless. Source-code installs and identity-changing or recovery-export operations require fresh macOS approval."
            )
        } catch {
            try? removeOperatorService()
            throw HelperFailure.migration("unable to start the secure service: \(error)")
        }
    }
}
