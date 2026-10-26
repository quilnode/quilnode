import Foundation
import Security

extension QuilNodeHelper {
    struct FirewallEntry {
        var path: String
        var rule: FirewallStatusPayload.NodeRule
    }

    static func firewallEntries(in output: String) -> [FirewallEntry] {
        let lines = output.components(separatedBy: .newlines)
        return lines.indices.compactMap { index in
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard let prefix = line.range(of: #"^\d+\s*:\s*"#, options: .regularExpression) else { return nil }
            let path = String(line[prefix.upperBound...]).trimmingCharacters(in: .whitespaces)
            let detail = index + 1 < lines.count ? lines[index + 1] : ""
            let rule: FirewallStatusPayload.NodeRule
            if detail.localizedCaseInsensitiveContains("allow incoming") {
                rule = .allowed
            } else if detail.localizedCaseInsensitiveContains("block incoming") {
                rule = .blocked
            } else {
                rule = .unavailable
            }
            return FirewallEntry(path: path, rule: rule)
        }
    }

    /// ALF can coalesce different Rust builds by their linker signing identifier
    /// while retaining the old path. An explicit allowed rule must move before
    /// adding its replacement. A default "permitted" query is not proof: macOS
    /// returns that answer even for nonexistent executables.
    static func staleFirewallRulePaths(for binary: URL) throws -> [String] {
        let output = try run(
            URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw"),
            ["--listapps"], timeout: 8
        )
        return try staleFirewallRulePaths(for: binary.path, entries: firewallEntries(in: output)) { path in
            let url = URL(fileURLWithPath: path)
            try validateRootOwnedExecutable(url, maximumBytes: 600_000_000)
            var code: SecStaticCode?
            guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
                let code,
                SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess
            else { return nil }
            var information: CFDictionary?
            guard SecCodeCopySigningInformation(code, [], &information) == errSecSuccess,
                let information = information as? [String: Any]
            else { return nil }
            return information[kSecCodeInfoIdentifier as String] as? String
        }
    }

    static func staleFirewallRulePaths(
        for currentPath: String,
        entries: [FirewallEntry],
        signingIdentifier: (String) throws -> String?
    ) rethrows -> [String] {
        guard let currentID = try signingIdentifier(currentPath), !currentID.isEmpty else { return [] }
        return entries.compactMap { entry in
            guard entry.path != currentPath, entry.rule == .allowed,
                isInstalledNodePath(entry.path),
                entry.path == URL(fileURLWithPath: entry.path).standardizedFileURL.path,
                let oldID = try? signingIdentifier(entry.path), oldID == currentID
            else { return nil }
            return entry.path
        }
    }

    static func replacingStaleFirewallRules<T>(
        _ paths: [String],
        command: (String, String) throws -> Void,
        operation: () throws -> T
    ) throws -> T {
        var removed: [String] = []
        do {
            for path in paths {
                try command("--remove", path)
                removed.append(path)
            }
            return try operation()
        } catch {
            // Restore only the previously allowed rules; never relax unrelated
            // entries or global policy, even when replacement verification fails.
            var restorationFailed = false
            for path in removed {
                do {
                    try command("--add", path)
                    try command("--unblockapp", path)
                } catch {
                    restorationFailed = true
                }
            }
            if restorationFailed {
                throw HelperFailure.service(
                    "The node firewall rule could not be replaced or restored. Review the node rule in macOS Firewall settings."
                )
            }
            throw error
        }
    }
}
