import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var updateCenterTitle: String {
        if let progress = releaseChecker.releaseCheckProgress {
            return progress.stage.title
        }
        switch releaseChecker.state {
        case .notChecked: return "No release check has run"
        case .checking: return "Checking signed, approved-dev, and raw development channels…"
        case let .available(snapshot):
            return "Signed \(snapshot.signed.version) · newest source \(snapshot.source.newestAnyBranch.name)"
        case .failed: return "Update check failed"
        }
    }

    var updateCenterDetail: String {
        if releaseChecker.operation != .idle { return updateOperationDescription }
        if let checkProgress = releaseChecker.releaseCheckProgress { return checkProgress.detail }
        switch releaseChecker.state {
        case .notChecked:
            return
                "Current node: \(monitor.snapshot.version ?? "unknown"). Manual mode makes no background update requests."
        case .checking:
            return "Resolving signed artifacts, the exact subpatch approval commit, and all official branch heads."
        case let .available(snapshot):
            let checked = snapshot.checkedAt.formatted(date: .abbreviated, time: .standard)
            return
                "Checked \(checked) · \(snapshot.source.branchCount) official branches · installed SHA-256 recorded locally."
        case let .failed(message):
            return message
        }
    }

    var updateCenterIcon: String {
        if releaseChecker.releaseCheckProgress != nil { return "arrow.triangle.2.circlepath" }
        switch releaseChecker.state {
        case .notChecked: return "network.slash"
        case .checking: return "arrow.clockwise"
        case .available: return "checkmark.shield.fill"
        case .failed: return "wifi.exclamationmark"
        }
    }

    var updateCenterTint: Color {
        if releaseChecker.releaseCheckProgress != nil { return theme.colors.info }
        switch releaseChecker.state {
        case .notChecked: return .secondary
        case .checking: return theme.colors.info
        case .available: return theme.colors.success
        case .failed: return theme.colors.danger
        }
    }

    var updateOperationDescription: String {
        switch releaseChecker.operation {
        case .idle: "Ready"
        case let .downloading(version): "Downloading and independently verifying signed release \(version)…"
        case let .building(branch, commit): "Building pinned source \(branch) at \(commit)…"
        case .awaitingAuthorization:
            "Candidate sealed · the secure service is preparing a rollback point before the brief runtime switch…"
        case .activating: "Switching atomically, restarting briefly, and checking process, version, and local metrics…"
        }
    }

    var updatePolicyFootnote: String {
        switch releaseChecker.policy {
        case .manual:
            "Manual installs. Opening Update Center reuses metadata for up to five minutes; protocol milestones keep their separate 30-minute monitor. No node artifact is built or installed automatically."
        case .signedStable:
            "Discovery, verification, guarded activation, rollback retention, and the health check run automatically while QuilNode is open. Only a strictly newer signed release can activate—never a downgrade. SHA3-256 and at least 7 valid Ed448 signatures are verified first."
        case .approvedDevelopment:
            "Discovery, local build, guarded activation, rollback retention, and the health check run automatically while QuilNode is open. The authorized local service can activate only the exact commit that changes the subpatch marker without another password; later unmarked commits are excluded."
        case .bleedingEdge:
            "Discovery, local build, guarded activation, rollback retention, and the health check run automatically while QuilNode is open. The newest raw official commit can activate without another password. This is intentionally high risk; identity and store operations remain outside this permission."
        }
    }

    var automaticScheduleDescription: String {
        if releaseChecker.policy != .manual {
            switch releaseChecker.automaticAuthorizationState {
            case .synchronizing:
                return "Preparing passwordless automatic activation"
            case .failed:
                return "Automatic install paused · secure service setup needs attention"
            case .inactive:
                return "Automatic install is not authorized"
            case .ready:
                break
            }
        }
        if releaseChecker.isChecking {
            return "Checking the selected channel now"
        }
        if releaseChecker.isInstalling {
            return "Building or installing the selected update"
        }
        let signal = releaseChecker.nextSignalCheck.map {
            "signal \($0.formatted(date: .omitted, time: .shortened))"
        }
        let reconciliation = releaseChecker.nextAutomaticCheck.map {
            "full reconciliation \($0.formatted(date: .omitted, time: .shortened))"
        }
        let schedule = [signal, reconciliation].compactMap { $0 }.joined(separator: " · ")
        guard !schedule.isEmpty else {
            return "Preparing the automatic schedule"
        }
        return "Automatic install ready · next \(schedule)"
    }

}
