import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    @ViewBuilder
    func installedBuildCard(_ installed: InstalledReleaseInfo) -> some View {
        HStack(spacing: 12) {
            DashboardCircleIcon(systemImage: "internaldrive.fill", tint: theme.colors.accentSecondary, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Installed on this Mac")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(
                    "\(installed.build.version ?? monitor.snapshot.version ?? "Unknown") · \(installed.build.kind.rawValue.capitalized)"
                )
                .font(.subheadline.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let commit = installed.build.commit {
                    Text(commit).font(.caption.monospaced()).textSelection(.enabled)
                }
                Text(installed.sha256.map { "SHA-256 \($0.prefix(16))…" } ?? "SHA-256 unavailable")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let date = installed.installedFileModifiedAt {
                    Text("Built \(date.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                releaseChecker.requestRollback()
            } label: {
                Label("Roll back", systemImage: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!releaseChecker.canRollback || releaseChecker.isInstalling || releaseChecker.stagedUpdate != nil)
            .help("Restore the previously active binary and signature policy, then run the same startup health check")
        }
        .padding(14)
        .controlSurface(tint: theme.colors.accentSecondary)
    }

    @ViewBuilder
    func signedChannelCard(_ snapshot: UpdateCenterSnapshot) -> some View {
        let release = snapshot.signed
        let newer = signedIsNewer(release.version, than: snapshot.installed.build.version)
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                DashboardCircleIcon(systemImage: "checkmark.shield.fill", tint: theme.colors.success, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Signed Stable").font(.subheadline.weight(.semibold))
                    Text(release.version).font(.title3.bold().monospacedDigit())
                }
                Spacer()
                Text(newer ? "UPDATE" : stableStatus(snapshot))
                    .font(.caption2.bold())
                    .foregroundStyle(newer ? theme.colors.warning : theme.colors.success)
            }
            UpdateDetailRow(label: "Trust", value: "SHA3-256 + \(release.signatureIndices.count)/17 signatures")
            UpdateDetailRow(
                label: "Manifest",
                value: release.manifestModifiedAt?.formatted(date: .abbreviated, time: .standard) ?? "Unknown"
            )
            UpdateDetailRow(label: "Artifact", value: release.binaryFileName)
            HStack {
                Button("Official manifest") {
                    NSWorkspace.shared.open(URL(string: "https://releases.quilibrium.com/release")!)
                }
                .buttonStyle(.link)
                Spacer()
                Button {
                    releaseChecker.requestInstallSigned()
                } label: {
                    Label("Install", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!newer || releaseChecker.isInstalling || releaseChecker.stagedUpdate != nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 235, alignment: .topLeading)
        .controlSurface(tint: theme.colors.success)
    }

    @ViewBuilder
    func qclientChannelCard(_ snapshot: UpdateCenterSnapshot) -> some View {
        let update = snapshot.qclient
        let installed = update.installed
        let available = update.available
        let qclientIsCompatible =
            installed?.isReady == true
            && QClientCompatibility.isCompatible(
                qclientReleaseVersion: installed?.releaseVersion,
                nodeVersion: snapshot.installed.build.version
            )
        let newer: Bool = {
            guard let available, let availableVersion = NodeVersion(available.releaseVersion) else { return false }
            guard let installedVersion = installed?.releaseVersion.flatMap(NodeVersion.init) else { return true }
            return installedVersion < availableVersion
        }()
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                DashboardCircleIcon(systemImage: "terminal.fill", tint: theme.colors.accent, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Managed qclient").font(.subheadline.weight(.semibold))
                    // Lead with the tool that will actually be invoked. The
                    // release feed can legitimately trail a compatible
                    // source-built qclient, and presenting that older feed
                    // version here made a successful reuse look like a
                    // downgrade.
                    Text(installed?.releaseVersion ?? available?.releaseVersion ?? "Unavailable")
                        .font(.title3.bold().monospacedDigit())
                }
                Spacer()
                Text(
                    qclientIsCompatible
                        ? "COMPATIBLE · REUSED"
                        : (newer ? "UPDATE" : (installed?.isReady == true ? "VERIFIED" : "SETUP"))
                )
                .font(.caption2.bold())
                .foregroundStyle(
                    newer
                        ? theme.colors.warning
                        : (installed?.isReady == true ? theme.colors.success : theme.colors.danger))
            }
            UpdateDetailRow(
                label: "Installed",
                value: installed.map {
                    "\($0.releaseVersion ?? "Unknown") · runtime \($0.reportedVersion ?? "Unknown")"
                }
                    ?? "Not managed"
            )
            UpdateDetailRow(
                label: "Provenance",
                value: installed?.trust == .pinnedSource
                    ? "Pinned source · \(installed?.commit.map { String($0.prefix(12)) } ?? "unknown commit")"
                    : "Official signed release"
            )
            UpdateDetailRow(
                label: "Trust",
                value: available.map { "SHA3-256 + \($0.signatureIndices.count)/17 signatures" }
                    ?? (update.error ?? "Manifest unavailable")
            )
            UpdateDetailRow(label: "Artifact", value: available?.binaryFileName ?? installed?.binaryFileName ?? "—")
            Label(
                qclientIsCompatible
                    ? "Verified and reused until the node's required protocol version changes."
                    : "Installed separately from the app. Updates never restart the node.",
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Button("Official manifest") {
                    NSWorkspace.shared.open(URL(string: "https://releases.quilibrium.com/qclient-release")!)
                }
                .buttonStyle(.link)
                Spacer()
                Button {
                    releaseChecker.requestInstallQClient()
                } label: {
                    Label(
                        qclientIsCompatible ? "Compatible" : (installed?.isReady == true ? "Update" : "Install"),
                        systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(
                    qclientIsCompatible || available == nil || (!newer && installed?.isReady == true)
                        || releaseChecker.isInstalling || releaseChecker.stagedUpdate != nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 235, alignment: .topLeading)
        .controlSurface(tint: theme.colors.accent)
    }
}
