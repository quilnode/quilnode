import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum InstallationHostInspector {
    static func inspect() -> InstallationPreflight {
        let process = ProcessInfo.processInfo
        let version = process.operatingSystemVersion
        let isAppleSilicon = commandOutput("/usr/bin/uname", ["-m"]) == "arm64"

        let memoryGB = Double(process.physicalMemory) / 1_073_741_824
        let root = URL(fileURLWithPath: "/")
        let capacity = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
        let freeGB = Double(capacity ?? 0) / 1_073_741_824
        let nodeLink = "/opt/quilibrium/node/quilibrium-node"
        let nodeInstalled = FileManager.default.isExecutableFile(atPath: nodeLink)
        let nodeTarget = commandOutput("/usr/bin/readlink", [nodeLink])
        let installedNodeBuild = nodeTarget.isEmpty ? nil : InstalledNodeBuildParser.parse(symlinkTarget: nodeTarget)
        let externalNodeRunning = !nodeInstalled && ExistingNodeRuntimeDiscovery.isExternalNodeRunning()

        let hardware = [
            InstallationCheck(
                id: "platform", title: "Apple Silicon",
                detail: isAppleSilicon ? "arm64 is supported" : "QuilNode production builds require Apple Silicon",
                state: isAppleSilicon ? .pass : .blocked
            ),
            InstallationCheck(
                id: "macos", title: "macOS",
                detail:
                    "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion) · QuilNode requires macOS 14 or newer",
                state: version.majorVersion >= 14 ? .pass : .blocked
            ),
            InstallationCheck(
                id: "cpu", title: "CPU threads",
                detail: "\(process.processorCount) detected · 4 minimum",
                state: process.processorCount >= 4 ? .pass : .blocked
            ),
            InstallationCheck(
                id: "memory", title: "Memory",
                detail: String(format: "%.0f GB detected · 8 GB minimum", memoryGB),
                state: memoryGB >= 8 ? .pass : .blocked
            ),
            InstallationCheck(
                id: "storage", title: "Free storage",
                detail: String(format: "%.0f GB available · 16 GB minimum", freeGB),
                state: freeGB >= 16 ? .pass : .blocked
            ),
        ]

        let releaseVerifier =
            Bundle.main.url(forAuxiliaryExecutable: "QuilNodeReleaseVerifier")
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/QuilNodeReleaseVerifier")
        let verifierReady = FileManager.default.isExecutableFile(atPath: releaseVerifier.path)
        let currentLimit = Int(commandOutput("/usr/sbin/sysctl", ["-n", "kern.maxfilesperproc"])) ?? 0
        var production = [
            InstallationCheck(
                id: "verifier", title: "Release trust verifier",
                detail: verifierReady
                    ? "Bundled, code-signed, and self-contained" : "Signed release verifier is missing",
                state: verifierReady ? .pass : .blocked
            ),
            InstallationCheck(
                id: "files", title: "File descriptor ceiling",
                detail: currentLimit >= 524_288
                    ? "\(currentLimit) available" : "Will be raised once during authorization",
                state: currentLimit >= 524_288 ? .pass : .warning
            ),
            InstallationCheck(
                id: "toolchain", title: "Build toolchain",
                detail: "Not required for official signed releases",
                state: .notRequired
            ),
        ]
        if externalNodeRunning {
            production.insert(
                InstallationCheck(
                    id: "external-node",
                    title: "Existing node is running",
                    detail: "Stop its current service, then run these checks again. QuilNode has not changed it.",
                    state: .blocked
                ),
                at: 0
            )
        }

        let sourceToolDefinitions: [(String, String, String)] = [
            ("xcode", "Xcode command-line tools", "/usr/bin/xcodebuild"),
            ("homebrew", "Homebrew", "/opt/homebrew/bin/brew"),
            ("git-lfs", "Git LFS", "/opt/homebrew/bin/git-lfs"),
            (
                "rust", "Rust",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cargo/bin/rustc").path
            ),
            ("protoc", "Protocol Buffers", "/opt/homebrew/bin/protoc"),
            ("cmake", "CMake", "/opt/homebrew/bin/cmake"),
            ("pkgconfig", "pkg-config", "/opt/homebrew/bin/pkg-config"),
        ]
        let sourceTools: [InstallationCheck] = sourceToolDefinitions.map { id, title, path in
            let present = FileManager.default.isExecutableFile(atPath: path)
            return InstallationCheck(
                id: id, title: title,
                detail: present ? "Detected" : "Needed only for advanced source builds",
                state: present ? .pass : .warning
            )
        }

        let serviceBuild = PrivilegedServiceClient.installedServiceBuild(timeout: 3)
        let serviceReady = (serviceBuild ?? -1) >= requiredServiceBuild
        let qclientStatus =
            serviceReady
            ? PrivilegedServiceClient.readQClientStatus(timeout: 8).status
            : nil
        let qclientCompatible: Bool =
            switch installedNodeBuild?.kind {
            case .signed:
                qclientStatus?.isReady == true && qclientStatus?.trust == .officialSigned
            case .source:
                qclientStatus?.isReady == true
                    && QClientCompatibility.isCompatible(
                        qclientReleaseVersion: qclientStatus?.releaseVersion,
                        nodeVersion: installedNodeBuild?.version
                    )
            case .unknown, nil:
                false
            }
        return InstallationPreflight(
            hardware: hardware,
            productionRequirements: production,
            sourceToolchain: sourceTools,
            nodeInstalled: nodeInstalled,
            secureServiceReady: serviceReady,
            secureServiceBuild: serviceBuild,
            qclientStatus: qclientStatus,
            qclientCompatibleWithNode: qclientCompatible,
            installedNodeBuild: installedNodeBuild
        )
    }

    private static var requiredServiceBuild: Int {
        PrivilegedServiceClient.minimumSupportedServiceBuild
    }

    private static func commandOutput(_ executable: String, _ arguments: [String]) -> String {
        let result = BoundedCommandRunner.run(
            executable: executable,
            arguments: arguments,
            timeout: 15,
            maximumOutputBytes: 256 * 1_024
        )
        return result.exitCode == 0 ? result.output : ""
    }
}
