import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    @ViewBuilder
    func approvedDevelopmentCard(_ snapshot: UpdateCenterSnapshot) -> some View {
        let approved = snapshot.source.approvedDevelopment
        let installedMatches =
            approved.map { release in
                snapshot.installed.build.commit.map {
                    release.commit.hasPrefix($0) || $0.hasPrefix(release.commit)
                } ?? false
            } ?? false
        let approvedIsNewer =
            approved.map {
                guard let available = NodeVersion($0.version) else { return false }
                guard let installedVersion = snapshot.installed.build.version.flatMap(NodeVersion.init) else {
                    return true
                }
                return installedVersion < available
            } ?? false
        let action = approvedDevelopmentActionAvailability(
            hasApproval: approved != nil,
            installedMatches: installedMatches,
            approvedIsNewer: approvedIsNewer
        )

        VStack(alignment: .leading, spacing: 11) {
            HStack {
                DashboardCircleIcon(systemImage: "checkmark.seal.fill", tint: theme.colors.info, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Approved Development").font(.subheadline.weight(.semibold))
                    Text(approved?.version ?? "Waiting for marker")
                        .font(.title3.bold().monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                Text(installedMatches ? "CURRENT" : (approved == nil ? "NO MARKER" : "APPROVED"))
                    .font(.caption2.bold())
                    .foregroundStyle(installedMatches ? theme.colors.success : theme.colors.info)
            }

            if let approved {
                UpdateDetailRow(label: "Marker", value: "subpatch \(approved.subpatch) · \(approved.branch)")
                UpdateDetailRow(label: "Approved commit", value: approved.commit)
                UpdateDetailRow(
                    label: "After marker",
                    value: approved.unapprovedCommitsAhead == 0
                        ? "Branch head is approved"
                        : "\(approved.unapprovedCommitsAhead) newer unapproved commit\(approved.unapprovedCommitsAhead == 1 ? "" : "s") excluded"
                )
                UpdateDetailRow(
                    label: "Approved", value: approved.committedAt.formatted(date: .abbreviated, time: .standard))
                HStack {
                    Button("View approval commit") {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/QuilibriumNetwork/monorepo/commit/\(approved.commit)")!)
                    }
                    .buttonStyle(.link)
                    Spacer()
                    Button {
                        releaseChecker.requestInstallApprovedDevelopment()
                    } label: {
                        Label("Build & install approved", systemImage: "checkmark.seal.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!action.isEnabled)
                    .help(action.message)
                }
                Label(action.message, systemImage: action.systemImage)
                    .font(.caption2)
                    .foregroundStyle(action.state == .ready ? theme.colors.success : Color.secondary)
            } else {
                UpdateDetailRow(
                    label: "Branch", value: snapshot.source.highestVersionBranch?.name ?? "No version branch")
                UpdateDetailRow(label: "Required", value: "Root file ‘subpatch’ with a positive release number")
                Text(
                    snapshot.source.approvalIssue
                        ?? "No commit will be auto-built until the official version branch publishes its first marker."
                )
                .font(.caption)
                .foregroundStyle(snapshot.source.approvalIssue == nil ? Color.secondary : theme.colors.danger)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 292, alignment: .topLeading)
        .controlSurface(tint: theme.colors.info)
    }

    func approvedDevelopmentActionAvailability(
        hasApproval: Bool,
        installedMatches: Bool,
        approvedIsNewer: Bool
    ) -> UpdateActionAvailability {
        guard hasApproval else {
            return .blocked("Waiting for an official subpatch approval marker.")
        }
        if installedMatches {
            return .current("This exact approved commit is already installed.")
        }
        guard approvedIsNewer else {
            return .blocked("The approved version is not newer than the installed build.")
        }
        if releaseChecker.isInstalling {
            return .blocked("Another node update is still running. Wait for it to finish or dismiss its result.")
        }
        if releaseChecker.stagedUpdate != nil {
            return .blocked("Install or resolve the already staged update before starting another build.")
        }
        return .ready("One-time action: build the exact approved commit locally, verify it, then install it.")
    }

    @ViewBuilder
    func rawDevelopmentCard(_ snapshot: UpdateCenterSnapshot) -> some View {
        let head = snapshot.source.newestAnyBranch
        let installedMatches =
            snapshot.installed.build.commit.map {
                head.commit.hasPrefix($0) || $0.hasPrefix(head.commit)
            } ?? false
        let sourceStatus = sourceCommitStatus(snapshot.source, installedMatches: installedMatches)
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                DashboardCircleIcon(systemImage: "hammer.fill", tint: theme.colors.warning, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Raw Development").font(.subheadline.weight(.semibold))
                    Text(head.name).font(.title3.bold()).lineLimit(1)
                }
                Spacer()
                Text(sourceStatus)
                    .font(.caption2.bold())
                    .foregroundStyle(installedMatches ? theme.colors.success : theme.colors.warning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            UpdateDetailRow(label: "Commit", value: head.commit)
            if let commitsBehind = snapshot.source.commitsBehind, commitsBehind > 0 {
                UpdateDetailRow(
                    label: "Position",
                    value: "Installed build is \(commitsBehind) commit\(commitsBehind == 1 ? "" : "s") behind"
                )
            }
            UpdateDetailRow(label: "Committed", value: head.committedAt.formatted(date: .abbreviated, time: .standard))
            UpdateDetailRow(label: "Change", value: head.subject)
            Label(
                "Newest commit across every branch; it may be unfinished or unapproved.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption2)
            .foregroundStyle(theme.colors.warning)
            HStack {
                Button("View commit") {
                    NSWorkspace.shared.open(
                        URL(string: "https://github.com/QuilibriumNetwork/monorepo/commit/\(head.commit)")!)
                }
                .buttonStyle(.link)
                Spacer()
                Button {
                    releaseChecker.requestInstallBleedingEdge()
                } label: {
                    Label("Build & install", systemImage: "hammer.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.warning)
                .disabled(installedMatches || releaseChecker.isInstalling || releaseChecker.stagedUpdate != nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
        .controlSurface(tint: theme.colors.warning)
    }

    func sourceCommitStatus(
        _ source: SourceReleaseInfo,
        installedMatches: Bool
    ) -> String {
        if installedMatches { return "CURRENT" }
        guard let count = source.commitsBehind, count > 0 else { return "UPDATE AVAILABLE" }
        return "\(count) COMMIT\(count == 1 ? "" : "S") BEHIND"
    }

    func signedIsNewer(_ available: String, than installed: String?) -> Bool {
        guard let availableVersion = NodeVersion(available) else { return false }
        guard let installed, let installedVersion = NodeVersion(installed) else { return true }
        return installedVersion < availableVersion
    }

    func stableStatus(_ snapshot: UpdateCenterSnapshot) -> String {
        guard let installedString = snapshot.installed.build.version,
            let installed = NodeVersion(installedString),
            let signed = NodeVersion(snapshot.signed.version)
        else { return "CHECKED" }
        if signed < installed { return "AHEAD" }
        return "CURRENT"
    }
}
