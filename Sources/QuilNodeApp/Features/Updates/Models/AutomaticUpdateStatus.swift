import Foundation

@MainActor
extension ReleaseChecker {
    func automaticDiscoveryStatus(now: Date = Date()) -> String {
        guard policy != .manual else { return "Automatic node updates are off" }
        switch automaticAuthorizationState {
        case .synchronizing: return "Preparing passwordless automatic activation"
        case .failed: return "Automatic install paused · secure service setup needs attention"
        case .inactive: return "Automatic install is not authorized"
        case .ready: break
        }
        if isInstalling { return "Building or installing the selected update" }
        if isChecking { return "Checking the selected channel now" }
        if signalCheckTask != nil { return "Checking the upstream update signal" }
        let signal = nextSignalCheck.map { "signal \($0.formatted(date: .omitted, time: .shortened))" }
        let reconciliation = nextAutomaticCheck.map {
            "full reconciliation \($0.formatted(date: .omitted, time: .shortened))"
        }
        let schedule = [signal, reconciliation].compactMap { $0 }.joined(separator: " · ")
        if signalCheckError != nil || automaticReconciliationPending {
            return schedule.isEmpty
                ? "Update check needs a retry"
                : "Update check will retry · next \(schedule)"
        }
        if [nextSignalCheck, nextAutomaticCheck].compactMap({ $0 }).contains(where: {
            now.timeIntervalSince($0) > 60
        }) {
            return "Update check is overdue · run Check & update now to retry"
        }
        guard !schedule.isEmpty else { return "Preparing the automatic schedule" }
        return "Automatic install ready · next \(schedule)"
    }
}
