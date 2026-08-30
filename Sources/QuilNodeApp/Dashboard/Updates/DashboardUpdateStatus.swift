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
            "Manual installs. Release-channel metadata refreshes every 30 minutes; no artifact is downloaded, built, installed, or restarted automatically."
        case .signedStable:
            "Checks every six hours. Only a strictly newer signed release can activate—never an automatic downgrade. SHA3-256 and at least 7 valid Ed448 signatures are verified first."
        case .approvedDevelopment:
            "Checks every six hours. Only the exact commit that changes the subpatch marker on the highest version branch can activate; later unmarked commits are excluded."
        case .bleedingEdge:
            "Checks every six hours and follows the newest raw commit across every official branch. This is intentionally high risk. Keys, config, and stores remain excluded from every update operation."
        }
    }

    var automaticScheduleDescription: String {
        if releaseChecker.isChecking {
            return "Checking the selected channel now"
        }
        if releaseChecker.isInstalling {
            return "Building or installing the selected update"
        }
        guard let nextCheck = releaseChecker.nextAutomaticCheck else {
            return "Preparing the automatic schedule"
        }
        return "Next check \(nextCheck.formatted(date: .abbreviated, time: .shortened))"
    }

}
