import Foundation

/// Public identity of the project-owned certificate used to sign QuilNode.
///
/// This certificate is an application identity, not a web PKI trust anchor. It
/// is embedded in the sealed app and pinned by the privileged service. The
/// private key remains in a dedicated release keychain outside the repository.
public enum AppReleaseIdentity {
    public static let certificateResourceName = "QuilNodeReleaseSigning"
    public static let certificateResourceExtension = "cer"
    public static let certificateFileName = "\(certificateResourceName).\(certificateResourceExtension)"
    public static let subjectSummary = "QuilNode Project Release Signing"
    public static let bundleIdentifier = "com.quilnode.app"
}
