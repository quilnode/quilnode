import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func verifySignedBundle(binary: URL, signatureIndices: [Int]) throws -> Int {
        let verifier = try releaseVerifierURL()
        let digestURL = binary.appendingPathExtension("dgst")
        let digestData = try BoundedLocalData.read(from: digestURL, maximumBytes: 8_192)
        let digestText = String(decoding: digestData, as: UTF8.self)
        let fields = digestText.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 2, fields[1].count >= 64 else { throw UpdateCenterError.invalidDigest }
        let claimed = String(fields[1].prefix(64)).lowercased()
        let computed = try runChecked(verifier.path, ["sha3-256", binary.path])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard computed.count == 64, computed.lowercased() == claimed
        else { throw UpdateCenterError.digestMismatch }

        var valid = 0
        for index in signatureIndices {
            guard (1...ReleaseTrustPolicy.signatories.count).contains(index) else {
                throw UpdateCenterError.invalidSignatureIndex
            }
            _ = try runChecked(
                verifier.path,
                [
                    "verify-ed448", ReleaseTrustPolicy.signatories[index - 1],
                    "\(binary.path).dgst.sig.\(index)", digestURL.path,
                ]
            )
            valid += 1
        }
        return valid
    }

    nonisolated static func bundledSHA3Digest(of file: URL) throws -> String {
        let output = try runChecked(releaseVerifierURL().path, ["sha3-256", file.path])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.count == 64, output.allSatisfy({ $0.isHexDigit }) else {
            throw UpdateCenterError.releaseVerifierInvalid
        }
        return output.lowercased()
    }

    nonisolated static func releaseVerifierURL() throws -> URL {
        let verifier =
            Bundle.main.url(forAuxiliaryExecutable: "QuilNodeReleaseVerifier")
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/QuilNodeReleaseVerifier")
        guard FileManager.default.isExecutableFile(atPath: verifier.path) else {
            throw UpdateCenterError.releaseVerifierUnavailable
        }
        return verifier
    }
}
