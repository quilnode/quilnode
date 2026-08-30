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

        public init(
            workspace: URL,
            repository: URL,
            cargoHome: URL,
            isolatedHome: URL,
            temporaryDirectory: URL,
            rustupHome: URL,
            cargoBin: URL,
            flintDirectory: URL
        ) {
            self.workspace = workspace
            self.repository = repository
            self.cargoHome = cargoHome
            self.isolatedHome = isolatedHome
            self.temporaryDirectory = temporaryDirectory
            self.rustupHome = rustupHome
            self.cargoBin = cargoBin
            self.flintDirectory = flintDirectory
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
            \(readRules)
            \(writeRules)
            """
    }

    public static func environment(layout: Layout) throws -> [String: String] {
        let home = try validatedPath(layout.isolatedHome)
        let cargoHome = try validatedPath(layout.cargoHome)
        let rustupHome = try validatedPath(layout.rustupHome)
        let temporary = try validatedPath(layout.temporaryDirectory)
        let flint = try validatedPath(layout.flintDirectory)
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
            "CARGO_BUILD_JOBS": "4",
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
