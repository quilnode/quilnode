import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    func managedQClientStrip(_ snapshot: UpdateCenterSnapshot) -> some View {
        let installed = snapshot.qclient.installed
        let available = snapshot.qclient.available
        let compatible =
            installed?.isReady == true
            && QClientCompatibility.isCompatible(
                qclientReleaseVersion: installed?.releaseVersion,
                nodeVersion: snapshot.installed.build.version
            )
        return Group {
            if !dashboardLayoutClass.isWide {
                VStack(alignment: .leading, spacing: 12) {
                    qclientIdentity
                    HStack(alignment: .bottom, spacing: 16) {
                        UpdateDetailRow(label: "Installed", value: installed?.releaseVersion ?? "Not managed")
                        UpdateDetailRow(label: "Available", value: available?.releaseVersion ?? "Unavailable")
                        Spacer(minLength: 4)
                        qclientAction(installed: installed, available: available, compatible: compatible)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    qclientIdentity
                    Spacer()
                    UpdateDetailRow(label: "Installed", value: installed?.releaseVersion ?? "Not managed")
                    UpdateDetailRow(label: "Available", value: available?.releaseVersion ?? "Unavailable")
                    Label(
                        compatible ? "Compatible · reused" : "Needs attention",
                        systemImage: compatible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(compatible ? theme.colors.success : theme.colors.warning)
                    qclientAction(installed: installed, available: available, compatible: compatible)
                }
            }
        }
        .padding(12)
        .controlSurface(tint: theme.colors.accent)
    }

    private var qclientIdentity: some View {
        HStack(spacing: 10) {
            DashboardCircleIcon(systemImage: "terminal.fill", tint: theme.colors.accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("Managed qclient dependency")
                    .font(.subheadline.weight(.semibold))
                Text("Not a node channel · reused while protocol-compatible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func qclientAction(
        installed: ManagedQClientStatus?,
        available: OfficialQClientRelease?,
        compatible: Bool
    ) -> some View {
        Button(compatible ? "Compatible" : (installed == nil ? "Install qclient" : "Update qclient")) {
            releaseChecker.requestInstallQClient()
        }
        .buttonStyle(.bordered)
        .disabled(
            compatible || available == nil || releaseChecker.isInstalling
                || releaseChecker.stagedUpdate != nil
        )
    }
}
