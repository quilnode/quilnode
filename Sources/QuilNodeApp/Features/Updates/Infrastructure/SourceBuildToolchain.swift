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
    let nativeCompilerEnvironment: [String: String]

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

        return SourceBuildToolchain(
            cargoExecutable: cargo,
            cargoBin: cargoBin,
            rustupHome: rustup,
            flintDirectory: flint,
            gmpDirectory: gmp,
            mpfrDirectory: mpfr,
            opensslDirectory: openssl,
            macOSSDK: sdk,
            nativeCompilerEnvironment: try resolveNativeCompilers(fileManager: fileManager)
        )
    }

    /// Apple's /usr/bin compiler shims repeatedly try to create xcrun caches
    /// outside the isolated build home. Resolve the real tools once, before
    /// entering the sandbox, without granting access to the user's cache.
    static func resolveNativeCompilers(
        fileManager: FileManager = .default,
        lookup: (String) throws -> String = { tool in
            try ReleaseChecker.runChecked("/usr/bin/xcrun", ["--find", tool], timeout: 15)
        }
    ) throws -> [String: String] {
        let roots = [
            "/Applications/Xcode.app/Contents/Developer/Toolchains/",
            "/Library/Developer/CommandLineTools/usr/bin/",
        ]
        var environment: [String: String] = [:]
        for (key, tool) in [("CC", "clang"), ("CXX", "clang++"), ("AR", "ar"), ("RANLIB", "ranlib")] {
            let path = try lookup(tool).trimmingCharacters(in: .whitespacesAndNewlines)
            // Validate text before constructing a URL. Avoid a bound
            // CharacterSet predicate: release builds rejected valid Apple
            // paths despite their containing no control characters.
            guard path.hasPrefix("/"), path.rangeOfCharacter(from: .controlCharacters) == nil else {
                throw UpdateCenterError.appleDeveloperToolUnavailable(tool)
            }
            let executable = URL(fileURLWithPath: path).standardizedFileURL
            let resolved = executable.resolvingSymlinksInPath().standardizedFileURL.path
            guard executable.lastPathComponent == tool,
                roots.contains(where: { executable.path.hasPrefix($0) }),
                roots.contains(where: { resolved.hasPrefix($0) })
            else { throw UpdateCenterError.appleDeveloperToolUnavailable(tool) }
            guard fileManager.isExecutableFile(atPath: executable.path) else {
                throw UpdateCenterError.appleDeveloperToolUnavailable(tool)
            }
            // Validate the symlink target, but invoke the original driver.
            // clang++ and ranlib select behavior from their executable name.
            environment[key] = executable.path
        }
        environment["CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER"] = environment["CC"]
        return environment
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
