import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    /// Applies only to the fixed, validated node job. Editing its next-launch
    /// policy does not unload or restart the currently running process.
    static func configureNodeStartup(enabled: Bool) throws {
        try validateLaunchDaemonPlist()
        let plist = nodeStartupPlist(try readPlist(), enabled: enabled)
        try writeRootPlist(plist, to: plistPath)
        if enabled { try runLaunchctl(["enable", serviceTarget]) }
        try validateLaunchDaemonPlist()
    }

    static func nodeStartupPlist(_ existing: [String: Any], enabled: Bool) -> [String: Any] {
        var plist = existing
        plist["RunAtLoad"] = enabled
        plist["KeepAlive"] = enabled
        return plist
    }

    static func nodeStartupResponse() throws -> PrivilegedServiceResponse {
        try validateLaunchDaemonPlist()
        let plist = try readPlist()
        let overrides = try runLaunchctl(["print-disabled", "system"])
        let disabled =
            overrides.range(
                of: #""com\.quilibrium\.node"\s*=>\s*true"#, options: .regularExpression) != nil
        let enabled = plist["RunAtLoad"] as? Bool == true && plist["KeepAlive"] as? Bool == true && !disabled
        return PrivilegedServiceResponse(
            success: true,
            message: enabled
                ? "The node starts at boot and restarts after an unexpected exit."
                : "The node starts manually. The current process is unchanged.",
            nodeStartAtBoot: enabled
        )
    }
}
