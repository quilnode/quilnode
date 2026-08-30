import Foundation

/// Generates a deny-by-default macOS sandbox for untrusted upstream source
/// builds. A pinned commit identifies source; it does not make build scripts
/// safe to execute with access to the operator's home directory.
public enum SourceBuildSandbox {
    public static let executable = "/usr/bin/sandbox-exec"

    public struct Layout: Sendable {
        public var workspace: URL
        public var repository: URL
        public var cargoHome: URL
        public var isolatedHome: URL
        public var temporaryDirectory: URL
        public var rustupHome: URL
        public var cargoBin: URL
        public var flintDirectory: URL
        public var gmpDirectory: URL
        public var mpfrDirectory: URL
        public var opensslDirectory: URL
        public var macOSSDK: URL

        public init(
            workspace: URL,
            repository: URL,
            cargoHome: URL,
            isolatedHome: URL,
            temporaryDirectory: URL,
            rustupHome: URL,
            cargoBin: URL,
            flintDirectory: URL,
            gmpDirectory: URL,
            mpfrDirectory: URL,
            opensslDirectory: URL,
            macOSSDK: URL
        ) {
            self.workspace = workspace
            self.repository = repository
            self.cargoHome = cargoHome
            self.isolatedHome = isolatedHome
            self.temporaryDirectory = temporaryDirectory
            self.rustupHome = rustupHome
            self.cargoBin = cargoBin
            self.flintDirectory = flintDirectory
            self.gmpDirectory = gmpDirectory
            self.mpfrDirectory = mpfrDirectory
            self.opensslDirectory = opensslDirectory
            self.macOSSDK = macOSSDK
        }
    }

    /// The dependency-fetch phase may contact registries but still cannot read
    /// the operator's files. Compilation uses the same profile with networking
    /// denied, so build scripts cannot scan the LAN or exfiltrate build state.
    public static func profile(layout: Layout, allowsNetwork: Bool) throws -> String {
        let controlledRoots = [
            layout.workspace, layout.repository,
            layout.cargoHome, layout.isolatedHome, layout.temporaryDirectory,
            layout.rustupHome, layout.cargoBin, layout.flintDirectory,
            layout.gmpDirectory, layout.mpfrDirectory,
            layout.opensslDirectory, layout.macOSSDK,
        ]
        let paths = try controlledRoots.flatMap(validatedPathAliases)
        let systemReadRoots = [
            "/System", "/usr", "/bin", "/sbin", "/opt/homebrew",
            "/usr/local", "/Library", "/Applications/Xcode.app",
            "/private/etc", "/private/var/db", "/private/var/select", "/dev",
        ]
        let systemPaths = try systemReadRoots.flatMap {
            try validatedPathAliases(URL(fileURLWithPath: $0, isDirectory: true))
        }
        // Canonicalization traverses every parent before opening an allowed
        // workspace, toolchain, registry cache, or Darwin resolver socket.
        // Permit metadata reads for those ancestors only. `literal` deliberately
        // exposes neither directory contents nor recursive subtrees (including
        // the operator's home), while avoiding fragile per-machine exceptions.
        let traversalPaths = Set((systemPaths + paths).flatMap(pathAncestors))
        let traversalRules = traversalPaths.sorted().map {
            "(allow file-read* (literal \(sandboxLiteral($0))))"
        }.joined(separator: "\n")
        let readRules = Array(Set(systemPaths + paths)).sorted().map {
            "(allow file-read* (subpath \(sandboxLiteral($0))))"
        }.joined(separator: "\n")
        let writablePaths = try [
            layout.workspace, layout.cargoHome,
            layout.isolatedHome, layout.temporaryDirectory,
        ].flatMap(validatedPathAliases)
        let writeRules = Array(Set(writablePaths)).sorted().map {
            "(allow file-write* (subpath \(sandboxLiteral($0))))"
        }.joined(separator: "\n")
        let deviceWriteRules = "(allow file-write* (literal \"/dev/null\"))"
        let networkRule = allowsNetwork ? "    (allow network-outbound)" : "    (deny network*)"

        return """
            (version 1)
            (deny default)
            (allow process*)
            (allow signal (target self))
            (allow sysctl-read)
            (allow mach-lookup)
            (allow ipc-posix*)
            \(networkRule)
            (allow file-read* (literal "/"))
            \(traversalRules)
            \(readRules)
            \(writeRules)
            \(deviceWriteRules)
            """
    }

    public static func environment(layout: Layout) throws -> [String: String] {
        let home = try validatedPath(layout.isolatedHome)
        let cargoHome = try validatedPath(layout.cargoHome)
        let rustupHome = try validatedPath(layout.rustupHome)
        let temporary = try validatedPath(layout.temporaryDirectory)
        let flint = try validatedPath(layout.flintDirectory)
        let gmp = try validatedPath(layout.gmpDirectory)
        let mpfr = try validatedPath(layout.mpfrDirectory)
        let openssl = try validatedPath(layout.opensslDirectory)
        let sdk = try validatedPath(layout.macOSSDK)
        return [
            "PATH": [
                try validatedPath(layout.cargoBin),
                "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
                "/usr/sbin", "/sbin",
            ].joined(separator: ":"),
            "HOME": home,
            "CARGO_HOME": cargoHome,
            "RUSTUP_HOME": rustupHome,
            "TMPDIR": temporary + "/",
            "FLINT_DIR": flint,
            "GMP_DIR": gmp,
            "MPFR_DIR": mpfr,
            "OPENSSL_DIR": openssl,
            "SDKROOT": sdk,
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        ]
    }

    public static func arguments(
        profileURL: URL,
        executable: String,
        arguments: [String]
    ) throws -> [String] {
        guard executable.hasPrefix("/"),
            !executable.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { throw SourceBuildSandboxError.invalidPath(executable) }
        return ["-f", try validatedPath(profileURL), executable] + arguments
    }

    private static func validatedPath(_ url: URL) throws -> String {
        let path = url.standardizedFileURL.path
        guard path.hasPrefix("/"), path != "/",
            !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { throw SourceBuildSandboxError.invalidPath(path) }
        return path
    }

    /// macOS exposes a few system directories through equivalent names
    /// (`/tmp` and `/private/tmp`, for example). Foundation and the sandbox
    /// kernel may report different names for the same vnode. Binding both
    /// aliases avoids either weakening the whole filesystem policy or denying
    /// a legitimately controlled workspace.
    private static func validatedPathAliases(_ url: URL) throws -> [String] {
        let lexical = try validatedPath(url)
        let resolved = try validatedPath(url.resolvingSymlinksInPath())
        var aliases = Set([lexical, resolved])
        if lexical == "/tmp" || lexical.hasPrefix("/tmp/") || lexical == "/var" || lexical.hasPrefix("/var/")
            || lexical == "/etc" || lexical.hasPrefix("/etc/")
        {
            aliases.insert("/private" + lexical)
        } else if lexical == "/private/tmp" || lexical.hasPrefix("/private/tmp/") || lexical == "/private/var"
            || lexical.hasPrefix("/private/var/") || lexical == "/private/etc" || lexical.hasPrefix("/private/etc/")
        {
            aliases.insert(String(lexical.dropFirst("/private".count)))
        }
        return aliases.sorted()
    }

    private static func pathAncestors(_ path: String) -> [String] {
        var ancestors: [String] = []
        var parent = URL(fileURLWithPath: path, isDirectory: true)
            .deletingLastPathComponent().standardizedFileURL.path
        while parent != "/" && !parent.isEmpty {
            ancestors.append(parent)
            let next = URL(fileURLWithPath: parent, isDirectory: true)
                .deletingLastPathComponent().standardizedFileURL.path
            guard next != parent else { break }
            parent = next
        }
        return ancestors
    }

    private static func sandboxLiteral(_ value: String) -> String {
        "\""
            + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

public enum SourceBuildSandboxError: LocalizedError, Equatable {
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath:
            "The source-build sandbox received an unsafe filesystem path."
        }
    }
}
