import CryptoKit
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension ReleaseChecker {
    nonisolated static func probeUpdateSignal(
        policy: NodeUpdatePolicy,
        baseline: UpdateSignalBaseline?,
        releaseEndpoint: URL,
        repositoryURL: String
    ) throws -> UpdateSignalProbe {
        switch policy {
        case .manual:
            throw UpdateCenterError.updateSignalUnavailable
        case .signedStable:
            return try probeSignedReleaseSignal(
                endpoint: releaseEndpoint,
                baseline: baseline
            )
        case .approvedDevelopment, .bleedingEdge:
            return try probeSourceReleaseSignal(
                policy: policy,
                repositoryURL: repositoryURL,
                baseline: baseline
            )
        }
    }

    nonisolated static func probeSignedReleaseSignal(
        endpoint: URL,
        baseline: UpdateSignalBaseline?
    ) throws -> UpdateSignalProbe {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 15
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        if let entityTag = baseline?.entityTag, !entityTag.isEmpty {
            request.setValue(entityTag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try downloadBoundedDataSynchronously(
            request,
            maximumBytes: 128_000,
            timeout: 30,
            acceptedStatusCodes: [200, 304]
        )
        guard exactReleaseURL(response.url, path: "/release") else {
            throw UpdateCenterError.updateSignalUnavailable
        }
        if response.statusCode == 304, let baseline {
            return UpdateSignalProbe(
                result: .unchanged,
                fingerprint: baseline.fingerprint,
                entityTag: response.value(forHTTPHeaderField: "ETag") ?? baseline.entityTag
            )
        }
        guard response.statusCode == 200,
            ReleaseManifestParser.latest(in: String(decoding: data, as: UTF8.self)) != nil
        else { throw UpdateCenterError.updateSignalUnavailable }
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return UpdateSignalProbe(
            result: baseline?.fingerprint == fingerprint ? .unchanged : .changed,
            fingerprint: fingerprint,
            entityTag: response.value(forHTTPHeaderField: "ETag")
        )
    }

    nonisolated static func probeSourceReleaseSignal(
        policy: NodeUpdatePolicy,
        repositoryURL: String,
        baseline: UpdateSignalBaseline?
    ) throws -> UpdateSignalProbe {
        let pattern = policy == .approvedDevelopment ? "refs/heads/v*" : "refs/heads/*"
        let output = try runChecked(
            gitExecutable,
            ["ls-remote", "--refs", "--heads", repositoryURL, pattern],
            environment: sourceControlEnvironment(),
            timeout: 30,
            maximumOutputBytes: 2 * 1_024 * 1_024
        )
        let references = try canonicalRemoteReferences(output)
        guard !references.isEmpty else { throw UpdateCenterError.updateSignalUnavailable }
        let data = Data(references.joined(separator: "\n").utf8)
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return UpdateSignalProbe(
            result: baseline?.fingerprint == fingerprint ? .unchanged : .changed,
            fingerprint: fingerprint,
            entityTag: nil
        )
    }

    nonisolated static func canonicalRemoteReferences(_ output: String) throws -> [String] {
        let lines = output.split(whereSeparator: \.isNewline)
        guard lines.count <= 2_000 else { throw UpdateCenterError.updateSignalUnavailable }
        return try lines.map { rawLine in
            let fields = rawLine.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2,
                fields[0].count == 40,
                fields[0].allSatisfy(\.isHexDigit),
                fields[1].hasPrefix("refs/heads/"),
                fields[1].utf8.count <= 512,
                !fields[1].contains(".."),
                !fields[1].contains("\\"),
                !fields[1].contains("\0")
            else { throw UpdateCenterError.updateSignalUnavailable }
            return "\(fields[0].lowercased())\t\(fields[1])"
        }.sorted()
    }
}
