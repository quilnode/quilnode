import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct AutomaticNodeUpdatePolicyRecord: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var policy: AutomaticNodeUpdatePolicy
    var updatedAt: Date
}

extension QuilNodeHelper {
    /// Missing policy data deliberately means signed-only. Source activation
    /// therefore stays interactive until the authenticated app explicitly
    /// synchronizes the operator's selected automatic channel.
    static func loadAutomaticNodeUpdatePolicy() throws -> AutomaticNodeUpdatePolicy {
        guard FileManager.default.fileExists(atPath: nodeUpdatePolicyURL.path) else {
            return .signedStable
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(
            AutomaticNodeUpdatePolicyRecord.self,
            from: readSecureRegularFile(
                nodeUpdatePolicyURL,
                maximumBytes: 8_192,
                requiredOwner: 0
            )
        )
        guard record.schemaVersion == 1 else {
            throw HelperFailure.service("the automatic update policy schema is unsupported")
        }
        return record.policy
    }

    static func configureAutomaticNodeUpdatePolicy(
        _ policy: AutomaticNodeUpdatePolicy
    ) throws {
        let record = AutomaticNodeUpdatePolicyRecord(policy: policy, updatedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try writeRootFile(
            try encoder.encode(record),
            to: nodeUpdatePolicyURL.path,
            mode: 0o600
        )
    }

    static func automaticNodeUpdatePolicyPermits(channel: String) -> Bool {
        let policy = (try? loadAutomaticNodeUpdatePolicy()) ?? .signedStable
        return policy.permitsPasswordlessActivation(channel: channel)
    }
}
