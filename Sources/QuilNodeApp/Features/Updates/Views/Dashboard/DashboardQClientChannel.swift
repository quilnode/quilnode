import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    func managedQClientStrip(_ snapshot: UpdateCenterSnapshot) -> some View {
        let compatible = snapshot.qclientIsCurrent
        return Group {
            if !dashboardLayoutClass.isWide {
                VStack(alignment: .leading, spacing: 12) {
                    qclientIdentity
                    HStack(alignment: .bottom, spacing: 16) {
                        UpdateDetailRow(label: "Installed", value: snapshot.qclientInstallationLabel)
                        UpdateDetailRow(label: "Target", value: snapshot.qclientTargetLabel)
                        Spacer(minLength: 4)
                        qclientAction(snapshot: snapshot, compatible: compatible)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    qclientIdentity
                    Spacer()
                    UpdateDetailRow(label: "Installed", value: snapshot.qclientInstallationLabel)
                    UpdateDetailRow(label: "Target", value: snapshot.qclientTargetLabel)
                    Label(
                        snapshot.qclientUpdateStatusLabel,
                        systemImage: compatible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(compatible ? theme.colors.success : theme.colors.warning)
                    qclientAction(snapshot: snapshot, compatible: compatible)
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
                Text("Wallet and prover reads · updated independently")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func qclientAction(
        snapshot: UpdateCenterSnapshot,
        compatible: Bool
    ) -> some View {
        Group {
            if snapshot.qclient.installed == nil {
                Button("Recheck") { releaseChecker.requestCheck() }
                    .disabled(releaseChecker.isWorking)
                    .help("The local service could not confirm qclient. Recheck before installing anything.")
            } else {
                Button(
                    compatible
                        ? "Current"
                        : (snapshot.qclient.installed?.state == .missing ? "Install qclient" : "Update qclient")
                ) {
                    releaseChecker.requestInstallQClient()
                }
                .disabled(
                    compatible || (snapshot.installed.build.kind != .source && snapshot.qclient.available == nil)
                        || releaseChecker.isWorking
                        || releaseChecker.stagedUpdate != nil
                )
            }
        }.buttonStyle(.bordered)
    }
}
