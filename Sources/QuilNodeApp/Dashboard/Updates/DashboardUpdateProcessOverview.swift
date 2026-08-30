import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var updateProcessOverview: some View {
        DisclosureGroup(isExpanded: $updateProcessExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    updateProcessPhase(
                        title: NodeUpdatePlanSection.preparation.title,
                        detail: NodeUpdatePlanSection.preparation.detail,
                        systemImage: "checkmark.shield.fill",
                        tint: theme.colors.success
                    )
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    updateProcessPhase(
                        title: NodeUpdatePlanSection.activation.title,
                        detail: NodeUpdatePlanSection.activation.detail,
                        systemImage: "arrow.triangle.swap",
                        tint: theme.colors.warning
                    )
                }

                HStack(spacing: 14) {
                    Label("Immutable candidate", systemImage: "scope")
                    Label("Cryptographic checks", systemImage: "checkmark.seal")
                    Label("Automatic rollback", systemImage: "arrow.uturn.backward.circle")
                    Label("Local health gate", systemImage: "waveform.path.ecg")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

                Text(
                    "Signed releases are downloaded and signature-checked. Approved and raw development updates are built from a pinned official commit in an isolated workspace. A compatible qclient is reused; it is rebuilt or replaced only when required."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                DashboardCircleIcon(
                    systemImage: "shield.lefthalf.filled.badge.checkmark",
                    tint: theme.colors.info,
                    size: 36
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("How QuilNode installs an update")
                        .font(.subheadline.weight(.semibold))
                    Text("Preparation has no node downtime; activation is rollback-protected and health-gated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Label("Node-first safety", systemImage: "bolt.horizontal.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.colors.success)
            }
            .contentShape(Rectangle())
        }
        .padding(14)
        .controlSurface(tint: theme.colors.info)
        .accessibilityHint(
            updateProcessExpanded ? "Collapses the update process" : "Shows the update process and safeguards")
    }

    func updateProcessPhase(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func releaseCheckProgressCard(_ progress: ReleaseCheckProgress) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = max(timeline.date.timeIntervalSince(progress.startedAt), 0)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress.stage.title)
                            .font(.subheadline.weight(.semibold))
                        Text(progress.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Text("\(compactDuration(elapsed)) elapsed")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress.fraction, total: 1)
                    .progressViewStyle(.linear)
                    .accessibilityLabel("Release check progress")
                    .accessibilityValue("Step \(progress.stage.stepNumber) of 4, \(progress.stage.title)")

                HStack {
                    Text("Step \(progress.stage.stepNumber) of 4")
                    Spacer()
                    if let previous = releaseChecker.lastCheckDuration {
                        Text("Previous check \(compactDuration(previous))")
                    } else {
                        Text("Cached results stay available")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .controlSurface(tint: theme.colors.info)
        }
    }

    func compactDuration(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded()), 0)
        if value < 60 { return "\(value)s" }
        let minutes = value / 60
        let remainder = value % 60
        return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
    }
}
