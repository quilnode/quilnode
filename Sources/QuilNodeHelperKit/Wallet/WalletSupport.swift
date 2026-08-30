import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func readActivePublicIdentity() -> WalletPublicIdentityPayload {
        var current: String?, legacy: String?, prover: String?
        if let nodeInfo = try? runNodeTool(["--node-info"], timeout: 15) {
            current = lineValue("Peer ID", in: nodeInfo)
            prover = lineValue("Prover Address", in: nodeInfo)
        }
        if let peerInfo = try? runNodeTool(["--peer-info"], timeout: 10) {
            legacy = lineValue("Legacy Peer ID (Ed448)", in: peerInfo)
        }
        return WalletPublicIdentityPayload(
            currentPeerID: current, legacySeniorityPeerID: legacy, proverAddress: prover, accountAddress: nil)
    }

    static func emptyWalletIdentity() -> WalletPublicIdentityPayload {
        .init(currentPeerID: nil, legacySeniorityPeerID: nil, proverAddress: nil, accountAddress: nil)
    }

    static func lineValue(_ label: String, in text: String) -> String? {
        text.split(separator: "\n").first { $0.hasPrefix("\(label):") }.map {
            $0.dropFirst(label.count + 1).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func encodeWalletPayload<T: Encodable>(_ payload: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    static func controllerHome(_ configuration: ServiceConfiguration) throws -> URL {
        guard let record = getpwuid(uid_t(configuration.controllerUID)),
            let raw = record.pointee.pw_dir,
            let home = String(validatingCString: raw), home.hasPrefix("/Users/")
        else { throw HelperFailure.service("the controlling account home directory is unavailable") }
        return URL(fileURLWithPath: home, isDirectory: true)
    }

    static func keyEntrySummaries(_ yaml: String) -> [(String, Int)] {
        let expression = try! NSRegularExpression(
            pattern: #"(?ms)^\s{0,2}[A-Za-z0-9._-]+:\s*\n(?:\s+.*\n)*?\s+id:\s*([^\n#]+).*?\s+type:\s*([0-9]+)"#)
        return expression.matches(in: yaml, range: NSRange(yaml.startIndex..., in: yaml)).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: yaml),
                let typeRange = Range(match.range(at: 2), in: yaml),
                let type = Int(yaml[typeRange].trimmingCharacters(in: .whitespacesAndNewlines))
            else { return nil }
            return (yaml[idRange].trimmingCharacters(in: .whitespacesAndNewlines), type)
        }
    }

    static func regexCapture(_ pattern: String, in text: String) -> String? {
        let expression = try! NSRegularExpression(pattern: pattern)
        guard let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    static func keyTypeLabel(_ value: Int) -> String {
        switch value {
        case 0: "Ed448"
        case 1: "X448"
        case 2: "BLS48-581"
        case 3: "BLS48-581 G2"
        case 4: "Decaf448"
        case 8: "Falcon-512"
        case 9: "sntrup761"
        default: "Type \(value)"
        }
    }

    static func keysetFingerprint(_ config: Data?, _ keys: Data?) -> String {
        var hasher = SHA256()
        hasher.update(data: Data("QuilNode keyset fingerprint v1\0".utf8))
        hasher.update(data: config ?? Data())
        hasher.update(data: Data([0]))
        hasher.update(data: keys ?? Data())
        return hasher.finalize().prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    static func stableUUID(from fingerprint: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(fingerprint.utf8)).prefix(16))
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    static func validWalletName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 48
            && !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    static func recoveryCopyCount(for id: UUID) -> Int {
        let prefix = id.uuidString.lowercased() + "-"
        return ((try? FileManager.default.contentsOfDirectory(atPath: walletRecovery.path)) ?? []).filter {
            $0.hasPrefix(prefix)
        }.count
    }

    static func walletVaultIsHealthy() -> Bool {
        var info = stat()
        return lstat(walletRoot.path, &info) == 0 && (info.st_mode & S_IFMT) == S_IFDIR && info.st_uid == 0
            && info.st_mode & 0o077 == 0
    }
}
