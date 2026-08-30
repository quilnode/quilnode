import Foundation

/// The narrow privileged capability granted to QuilNode's authenticated local
/// service. This is intentionally separate from scheduling: the unprivileged
/// app decides when to look for updates, while the root-owned service decides
/// which trust channels may activate without another password prompt.
public enum AutomaticNodeUpdatePolicy: String, Codable, CaseIterable, Sendable {
    case signedStable
    case approvedDevelopment
    case bleedingEdge

    public func permitsPasswordlessActivation(channel: String) -> Bool {
        switch self {
        case .signedStable:
            channel == "signed"
        case .approvedDevelopment:
            channel == "signed" || channel == "approved-dev"
        case .bleedingEdge:
            channel == "signed" || channel == "approved-dev" || channel == "raw-dev"
        }
    }
}
