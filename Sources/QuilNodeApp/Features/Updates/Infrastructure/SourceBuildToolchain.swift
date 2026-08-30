import Darwin
import Foundation

struct SourceBuildToolchain: Sendable {
    let cargoExecutable: URL
    let cargoBin: URL
    let rustupHome: URL
    let flintDirectory: URL
    let gmpDirectory: URL
    let mpfrDirectory: URL
    let opensslDirectory: URL
    let macOSSDK: URL
    let parallelJobs: Int

    static func discover(
        operatorHome: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        sdkPath: () throws -> String = {
            try ReleaseChecker.runChecked(
                "/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-path"], timeout: 15
            )
        }
    ) throws -> SourceBuildToolchain {
        let cargoBin = operatorHome.appendingPathComponent(".cargo/bin", isDirectory: true)
        let cargo = cargoBin.appendingPathComponent("cargo")
        let rustup = operatorHome.appendingPathComponent(".rustup", isDirectory: true)
        let flint = operatorHome.appendingPathComponent(
            ".local/share/QuilNode/Toolchains/flint-3.6.0",
            isDirectory: true
        )
        guard fileManager.isExecutableFile(atPath: cargo.path),
            isDirectory(rustup, fileManager: fileManager),
            try isSafeRegularFile(
                flint.appendingPathComponent("lib/libflint.a"),
                fileManager: fileManager
            ),
            fileManager.fileExists(atPath: flint.appendingPathComponent("include/flint/flint.h").path)
        else { throw UpdateCenterError.sourceToolMissing("isolated Rust/Flint toolchain") }

        let gmp = try dependencyRoot(
            name: "GMP", formula: "gmp",
            requiredFiles: ["lib/libgmp.a", "include/gmp.h"],
            fileManager: fileManager
        )
        let mpfr = try dependencyRoot(
            name: "MPFR", formula: "mpfr",
            requiredFiles: ["lib/libmpfr.a", "include/mpfr.h"],
            fileManager: fileManager
        )
        let openssl = try dependencyRoot(
            name: "OpenSSL", formula: "openssl@3",
            requiredFiles: ["lib/libssl.a", "lib/libcrypto.a", "include/openssl/ssl.h"],
            fileManager: fileManager
        )
        let sdk = URL(
            fileURLWithPath: try sdkPath().trimmingCharacters(in: .whitespacesAndNewlines),
            isDirectory: true
        ).standardizedFileURL
        let approvedSDKRoots = [
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/",
            "/Library/Developer/CommandLineTools/SDKs/",
        ]
        guard approvedSDKRoots.contains(where: { sdk.path.hasPrefix($0) }),
            isDirectory(sdk, fileManager: fileManager)
        else { throw UpdateCenterError.sourceToolMissing("macOS SDK") }

        let processInfo = ProcessInfo.processInfo
        return SourceBuildToolchain(
            cargoExecutable: cargo,
            cargoBin: cargoBin,
            rustupHome: rustup,
            flintDirectory: flint,
            gmpDirectory: gmp,
            mpfrDirectory: mpfr,
            opensslDirectory: openssl,
            macOSSDK: sdk,
            parallelJobs: recommendedParallelJobs(
                availableProcessors: processInfo.activeProcessorCount,
                physicalMemoryBytes: processInfo.physicalMemory,
                thermalState: processInfo.thermalState,
                lowPowerMode: processInfo.isLowPowerModeEnabled
            )
        )
    }

    /// Preserve two processors for the live node and UI, while giving Cargo
    /// enough jobserver tokens for parallel native compilation. The upper bound
    /// avoids memory spikes on unusually large hosts.
    static func recommendedParallelJobs(
        availableProcessors: Int,
        physicalMemoryBytes: UInt64 = 32 * 1_024 * 1_024 * 1_024,
        thermalState: ProcessInfo.ThermalState = .nominal,
        lowPowerMode: Bool = false
    ) -> Int {
        let processors = max(availableProcessors, 1)
        let processorLimit = processors <= 4 ? max(processors - 1, 1) : processors - 2
        let memoryGiB = Double(physicalMemoryBytes) / 1_073_741_824
        let memoryLimit = max(Int((max(memoryGiB - 4, 1) / 1.25).rounded(.down)), 1)
        var jobs = min(processorLimit, memoryLimit, 12)
        if lowPowerMode { jobs = max(jobs / 2, 1) }
        switch thermalState {
        case .nominal: break
        case .fair: jobs = max(Int((Double(jobs) * 0.75).rounded(.down)), 1)
        case .serious: jobs = max(jobs / 2, 1)
        case .critical: jobs = 1
        @unknown default: jobs = max(jobs / 2, 1)
        }
        return jobs
    }

    static func dependencyRoot(
        name: String,
        formula: String,
        requiredFiles: [String],
        searchRoots: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/opt", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/opt", isDirectory: true),
        ],
        fileManager: FileManager = .default
    ) throws -> URL {
        for searchRoot in searchRoots {
            let candidate = searchRoot.appendingPathComponent(formula, isDirectory: true)
            let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
            let approvedRoot = searchRoot.deletingLastPathComponent().standardizedFileURL.path + "/"
            guard resolved.path.hasPrefix(approvedRoot), isDirectory(resolved, fileManager: fileManager)
            else { continue }
            if try requiredFiles.allSatisfy({
                try isSafeRegularFile(candidate.appendingPathComponent($0), fileManager: fileManager)
            }) {
                // Preserve Homebrew's stable `opt` path in the build environment;
                // the sandbox separately binds both it and its resolved Cellar path.
                return candidate
            }
        }
        throw UpdateCenterError.sourceToolMissing(name)
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func isSafeRegularFile(
        _ url: URL,
        fileManager _: FileManager
    ) throws -> Bool {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else { return false }
        return metadata.st_mode & S_IFMT == S_IFREG
            && metadata.st_size > 0
            && metadata.st_mode & 0o022 == 0
    }
}
