import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension UpdateCenterSnapshot {
    var qclientInstallationLabel: String {
        guard let client = qclient.installed else { return "Unavailable" }
        switch client.state {
        case .missing: return "Not installed"
        case .invalid: return "Needs repair"
        case .verified: return client.releaseVersion ?? client.reportedVersion ?? "Installed"
        }
    }

    var qclientUpdateStatusLabel: String {
        guard let client = qclient.installed else { return "Check unavailable" }
        switch client.state {
        case .missing: return "Not installed"
        case .invalid: return "Needs repair"
        case .verified: return qclientIsCurrent ? "Current" : "Update available"
        }
    }

    /// Only the installed protocol's version branch is eligible for a
    /// client-only update. Never silently cross protocols or arbitrary branches.
    var qclientSourceHead: GitBranchHead? {
        guard installed.build.kind == .source,
            let head = source.highestVersionBranch,
            QClientCompatibility.isCompatible(
                qclientReleaseVersion: head.version, nodeVersion: installed.build.version
            )
        else { return nil }
        return head
    }

    var qclientIsCurrent: Bool {
        QClientCompatibility.isCurrent(
            qclient.installed,
            nodeVersion: installed.build.version,
            nodeCommit: qclientSourceHead?.commit ?? installed.build.commit
        )
    }

    var qclientTargetLabel: String {
        if let head = qclientSourceHead { return "Source \(head.commit.prefix(8))" }
        if installed.build.kind == .source { return installed.build.version ?? "Matching source" }
        return qclient.available?.releaseVersion ?? "Unavailable"
    }
}
