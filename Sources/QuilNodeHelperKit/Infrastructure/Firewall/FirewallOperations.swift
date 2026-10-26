import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func currentFirewallBinary() throws -> URL {
        let target = try FileManager.default.destinationOfSymbolicLink(atPath: nodeLink.path)
        try validateInstalledTarget(target)
        let url = URL(fileURLWithPath: target).standardizedFileURL
        try validateRootOwnedExecutable(url, maximumBytes: 600_000_000)
        return url
    }

    static func inspectFirewall() throws -> FirewallStatusPayload {
        let firewall = URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
        let binary = try currentFirewallBinary()
        let global = try run(firewall, ["--getglobalstate"], timeout: 5)
        let blockAll = try run(firewall, ["--getblockall"], timeout: 5)
        let stealth = try run(firewall, ["--getstealthmode"], timeout: 5)
        let apps = try run(firewall, ["--listapps"], timeout: 8)
        let rule = firewallRule(for: binary.path, in: apps)
        let record = readManagedFirewallRecord()
        return FirewallStatusPayload(
            globalEnabled: global.localizedCaseInsensitiveContains("enabled"),
            blockAllEnabled: blockAll.localizedCaseInsensitiveContains("enabled"),
            stealthEnabled: stealth.localizedCaseInsensitiveContains("enabled")
                || stealth.localizedCaseInsensitiveContains("is on"),
            nodeRule: rule,
            managedByQuilNode: record?.nodeBinaryPath == binary.path,
            verifiedAt: Date()
        )
    }

    /// A deliberately narrow transaction: preserve every unrelated rule and
    /// firewall preference, add/allow the current node only, enable the global
    /// firewall when needed, then fail closed unless the result can be proven.
    static func configureFirewall() throws -> FirewallStatusPayload {
        let firewall = URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
        let binary = try currentFirewallBinary()
        let before = try inspectFirewall()
        guard !before.blockAllEnabled else {
            throw HelperFailure.service("Block All is enabled; review that intentional macOS setting first")
        }
        let stalePaths = before.nodeRule == .missing ? try staleFirewallRulePaths(for: binary) : []
        _ = try replacingStaleFirewallRules(stalePaths) { option, path in
            _ = try run(firewall, [option, path], timeout: 10)
        } operation: {
            if before.nodeRule == .missing {
                _ = try run(firewall, ["--add", binary.path], timeout: 10)
            }
            _ = try run(firewall, ["--unblockapp", binary.path], timeout: 10)
            if !before.globalEnabled {
                _ = try run(firewall, ["--setglobalstate", "on"], timeout: 10)
            }
            let verified = try inspectFirewall()
            guard verified.globalEnabled,
                !verified.blockAllEnabled,
                verified.nodeRule == .allowed
            else {
                throw HelperFailure.service("macOS did not confirm the node firewall rule")
            }
            return verified
        }

        let previousRecord = readManagedFirewallRecord()
        let record = ManagedFirewallRecord(
            nodeBinaryPath: binary.path,
            firewallWasEnabledBeforeManagement: previousRecord?.firewallWasEnabledBeforeManagement
                ?? before.globalEnabled,
            managedAt: previousRecord?.managedAt ?? Date(),
            lastVerifiedAt: Date()
        )
        try writeManagedFirewallRecord(record)

        // Keep distinct older identities available for rollback. Removing an
        // old path again after migration can remove the new rule too: ALF may
        // resolve both paths to the same signing identifier.
        return try inspectFirewall()
    }

    static func refreshManagedFirewallAfterUpdate() throws {
        guard readManagedFirewallRecord() != nil else { return }
        _ = try configureFirewall()
    }

    static func firewallRule(
        for path: String,
        in listOutput: String
    ) -> FirewallStatusPayload.NodeRule {
        firewallEntries(in: listOutput).first { $0.path == path }?.rule ?? .missing
    }

    static func readManagedFirewallRecord() -> ManagedFirewallRecord? {
        guard
            let data = try? readSecureRegularFile(
                firewallRecordURL,
                maximumBytes: 64_000,
                requiredOwner: 0
            )
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let record = try? decoder.decode(ManagedFirewallRecord.self, from: data),
            record.schemaVersion == 1,
            isInstalledNodePath(record.nodeBinaryPath)
        else { return nil }
        return record
    }

    static func writeManagedFirewallRecord(_ record: ManagedFirewallRecord) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try writeRootFile(try encoder.encode(record), to: firewallRecordURL.path, mode: 0o600)
    }

    static func isInstalledNodePath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return url.deletingLastPathComponent().path == nodeDirectory.path
            && url.lastPathComponent.hasPrefix("node-")
            && !url.lastPathComponent.contains("keys")
            && !url.lastPathComponent.contains(".dgst")
    }

    static func encodeFirewallPayload(_ payload: FirewallStatusPayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    static func firewallSummary(_ status: FirewallStatusPayload) -> String {
        if status.blockAllEnabled { return "macOS Firewall is blocking every incoming connection." }
        if !status.globalEnabled { return "macOS Firewall is off." }
        switch status.nodeRule {
        case .allowed: return "macOS Firewall is on and the current node is allowed."
        case .blocked: return "macOS Firewall is on, but the current node is blocked."
        case .missing: return "macOS Firewall is on, but the current node has no explicit rule."
        case .unavailable: return "The node firewall rule could not be verified."
        }
    }

    // MARK: - Identity package management

}
