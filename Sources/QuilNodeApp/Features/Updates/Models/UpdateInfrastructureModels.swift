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

struct PreparedSourceBuildSandbox: Sendable {
    var fetchProfile: URL
    var compileProfile: URL
    var cargoExecutable: String
    var environment: [String: String]
}

enum UpdateCenterError: LocalizedError {
    case invalidSignedManifest, invalidQClientManifest, noSignedRelease, noOfficialBranches, noProtocolMilestones
    case applicationSupportUnavailable, signatureQuorumMissing
    case releaseVerifierUnavailable, releaseVerifierInvalid
    case invalidDigest, digestMismatch, invalidSignatureIndex, versionValidationFailed
    case commitValidationFailed, branchIsNotNodeBuildable(String), sourceBuildMissing, sourceQClientMissing
    case matchingSourceCheckoutUnavailable
    case sourceCheckoutModified, sourceToolMissing(String)
    case sourceSandboxUnavailable, sourceArtifactUnsafe(String)
    case seniorityDatasetUnavailable, sourceCacheInvalid
    case hashFailed, downloadFailed, downloadTimedOut, authorizationCancelled
    case activationFailed(String), commandFailed(String), commandTimedOut(String, TimeInterval)

    var errorDescription: String? {
        switch self {
        case .invalidSignedManifest: "The official signed manifest response was invalid."
        case .invalidQClientManifest:
            "The official qclient manifest is invalid or lacks the required signed trust bundle."
        case .noSignedRelease: "No signed Apple Silicon release was listed."
        case .noOfficialBranches: "No branch heads were returned by the official repository."
        case .noProtocolMilestones:
            "No executable protocol frame gates were found in the bounded official source index."
        case .applicationSupportUnavailable: "QuilNode's local application-support directory is unavailable."
        case .signatureQuorumMissing: "The signed release does not contain the required seven-signature quorum."
        case .releaseVerifierUnavailable: "The signed release verifier is missing from this QuilNode build."
        case .releaseVerifierInvalid: "The signed release verifier returned malformed integrity data."
        case .invalidDigest: "The signed release digest has an invalid format."
        case .digestMismatch: "The downloaded binary does not match its published SHA3-256 digest."
        case .invalidSignatureIndex: "The release contains an invalid signatory index."
        case .versionValidationFailed: "The staged binary did not report the expected version."
        case .commitValidationFailed: "The source checkout did not resolve to the exact selected commit."
        case let .branchIsNotNodeBuildable(branch):
            "The newest branch ‘\(branch)’ does not contain a compatible node build."
        case .sourceBuildMissing: "The source build completed without producing a node binary."
        case .sourceQClientMissing: "The source build completed without producing the matching qclient binary."
        case .matchingSourceCheckoutUnavailable:
            "The exact source checkout used by the installed node is unavailable; QuilNode will not substitute a qclient from another commit."
        case .sourceCheckoutModified:
            "The matching source checkout contains tracked modifications; QuilNode will not label its qclient as an exact commit build."
        case let .sourceToolMissing(tool):
            "\(tool) is required for approved source builds but was not detected in a standard Homebrew location. Install the source-build toolchain, then retry."
        case .sourceSandboxUnavailable:
            "The host could not apply QuilNode's deny-by-default source-build sandbox. The source update was refused rather than compiled with access to your account."
        case let .sourceArtifactUnsafe(name):
            "The source build produced an unsafe, linked, writable, oversized, or non-regular artifact named ‘\(name)’; it was not staged."
        case .seniorityDatasetUnavailable:
            "The official seniority build dataset could not be obtained with the exact SHA-256 and byte count committed by upstream."
        case .sourceCacheInvalid:
            "The reusable source-build cache does not point to the official Quilibrium repository."
        case .hashFailed: "The staged binary SHA-256 could not be calculated."
        case .downloadFailed: "An official release file could not be downloaded safely."
        case .downloadTimedOut: "The release download timed out."
        case .authorizationCancelled: "Administrator authorization was cancelled."
        case let .activationFailed(message): message.isEmpty ? "Update activation failed." : message
        case let .commandFailed(message): message
        case let .commandTimedOut(command, timeout):
            "\(URL(fileURLWithPath: command).lastPathComponent) exceeded its \(Int(timeout))-second safety limit."
        }
    }
}
