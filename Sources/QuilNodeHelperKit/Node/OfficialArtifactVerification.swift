import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    /// Re-verifies the official trust bundle inside the root boundary. The
    /// service does not trust the GUI's prior verification or signature count.
    static func verifySignedRelease(_ manifest: ActivationManifest, stage: URL) throws {
        try validateRootOwnedExecutable(
            URL(fileURLWithPath: operatorVerifier), maximumBytes: 40_000_000
        )
        let binary = stage.appendingPathComponent(manifest.binaryFileName)
        let digest = stage.appendingPathComponent("\(manifest.binaryFileName).dgst")
        try validateRegularFile(digest, maximumBytes: 8_192)
        guard
            let digestText = String(
                data: try readSecureRegularFile(digest, maximumBytes: 8_192),
                encoding: .utf8
            )
        else { throw HelperFailure.invalidManifest("the published digest is not UTF-8") }
        let escapedName = NSRegularExpression.escapedPattern(for: manifest.binaryFileName)
        let pattern = "^SHA3-256\\(\(escapedName)\\)= ([0-9a-fA-F]{64})\\n?$"
        let expression = try NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(digestText.startIndex..<digestText.endIndex, in: digestText)
        guard let match = expression.firstMatch(in: digestText, range: fullRange),
            match.range == fullRange,
            let claimedRange = Range(match.range(at: 1), in: digestText)
        else { throw HelperFailure.invalidManifest("the published SHA3-256 digest is malformed") }
        let claimed = digestText[claimedRange].lowercased()
        let computed = try run(
            URL(fileURLWithPath: operatorVerifier),
            ["sha3-256", binary.path], timeout: 120
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard computed.count == 64, computed.lowercased() == claimed else {
            throw HelperFailure.invalidManifest("the staged binary does not match the published SHA3-256 digest")
        }

        var verified = 0
        for index in manifest.signatureIndices {
            guard ReleaseTrustPolicy.signatories.indices.contains(index - 1) else {
                throw HelperFailure.invalidManifest("the release signature index is invalid")
            }
            let signature = stage.appendingPathComponent("\(manifest.binaryFileName).dgst.sig.\(index)")
            try validateRegularFile(signature, maximumBytes: 256)
            _ = try run(
                URL(fileURLWithPath: operatorVerifier),
                ["verify-ed448", ReleaseTrustPolicy.signatories[index - 1], signature.path, digest.path],
                timeout: 15
            )
            verified += 1
        }
        guard verified >= ReleaseTrustPolicy.minimumSignatures else {
            throw HelperFailure.invalidManifest("the official Ed448 signature quorum was not verified")
        }
    }

    /// Generic root-boundary verification for official artifacts. The GUI's
    /// verification is useful feedback, never an authority decision.
    static func verifyOfficialArtifact(
        _ artifact: SignedArtifactActivation,
        stage: URL,
        maximumBinaryBytes: UInt64
    ) throws {
        try validateRootOwnedExecutable(
            URL(fileURLWithPath: operatorVerifier), maximumBytes: 40_000_000
        )
        let binary = stage.appendingPathComponent(artifact.binaryFileName)
        try validateRegularFile(binary, maximumBytes: maximumBinaryBytes)
        let digest = stage.appendingPathComponent("\(artifact.binaryFileName).dgst")
        try validateRegularFile(digest, maximumBytes: 8_192)
        guard
            let digestText = String(
                data: try readSecureRegularFile(digest, maximumBytes: 8_192),
                encoding: .utf8
            )
        else { throw HelperFailure.invalidManifest("the qclient digest is not UTF-8") }
        let escapedName = NSRegularExpression.escapedPattern(for: artifact.binaryFileName)
        let expression = try NSRegularExpression(
            pattern: "^SHA3-256\\(\(escapedName)\\)= ([0-9a-fA-F]{64})\\n?$"
        )
        let fullRange = NSRange(digestText.startIndex..<digestText.endIndex, in: digestText)
        guard let match = expression.firstMatch(in: digestText, range: fullRange),
            match.range == fullRange,
            let claimedRange = Range(match.range(at: 1), in: digestText)
        else { throw HelperFailure.invalidManifest("the qclient SHA3-256 digest is malformed") }
        let computed = try run(
            URL(fileURLWithPath: operatorVerifier), ["sha3-256", binary.path], timeout: 120
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard computed.lowercased() == digestText[claimedRange].lowercased(),
            sha256(binary) == artifact.sha256.lowercased()
        else { throw HelperFailure.invalidManifest("qclient does not match its signed digest or staged SHA-256") }

        var verified = 0
        for index in artifact.signatureIndices {
            guard ReleaseTrustPolicy.signatories.indices.contains(index - 1) else {
                throw HelperFailure.invalidManifest("the qclient signature index is invalid")
            }
            let signature = stage.appendingPathComponent("\(artifact.binaryFileName).dgst.sig.\(index)")
            try validateRegularFile(signature, maximumBytes: 256)
            _ = try run(
                URL(fileURLWithPath: operatorVerifier),
                ["verify-ed448", ReleaseTrustPolicy.signatories[index - 1], signature.path, digest.path],
                timeout: 15
            )
            verified += 1
        }
        guard verified >= ReleaseTrustPolicy.minimumSignatures else {
            throw HelperFailure.invalidManifest("the official qclient signature quorum was not verified")
        }
    }
}
