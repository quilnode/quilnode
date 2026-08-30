import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    func updateChannelMatrix(_ snapshot: UpdateCenterSnapshot) -> some View {
        let channels = UpdateChannelPresentation.make(
            snapshot: snapshot,
            isInstalling: releaseChecker.isInstalling,
            hasStagedUpdate: releaseChecker.stagedUpdate != nil
        )
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Node channels")
                    .font(.headline)
                Text("One runtime, three assurance levels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Checked \(snapshot.checkedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            updateChannelColumnHeaders

            ForEach(channels) { channel in
                updateChannelRow(channel)
                if channel.id != channels.last?.id {
                    Divider().opacity(0.45)
                }
            }
        }
        .controlSurface(tint: theme.colors.info)
    }

    private var updateChannelColumnHeaders: some View {
        HStack(spacing: 12) {
            Text("CHANNEL").frame(width: 220, alignment: .leading)
            Text("ASSURANCE").frame(width: 132, alignment: .leading)
            Text("VERSION / EVIDENCE").frame(maxWidth: .infinity, alignment: .leading)
            Text("STATE").frame(width: 112, alignment: .leading)
            Text("ACTION").frame(width: 176, alignment: .leading)
        }
        .font(.system(size: 9, weight: .bold))
        .tracking(0.7)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.025))
    }

    private func updateChannelRow(_ channel: UpdateChannelPresentation) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                DashboardCircleIcon(
                    systemImage: channel.kind.systemImage,
                    tint: channelTint(channel.kind),
                    size: 34
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.kind.title)
                        .font(.subheadline.weight(.semibold))
                    Text(channel.kind.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 220, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Label(channel.assurance.title, systemImage: "shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(assuranceTint(channel.assurance))
                Text(channel.assurance.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 132, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(channel.version)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                    if let commit = channel.commit {
                        Text(shortCommit(commit))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Text(channel.evidence)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(channel.evidence)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Label(channel.state.title, systemImage: stateIcon(channel.state))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stateTint(channel.state))
                if let timestamp = channel.timestamp {
                    Text("\(timestamp.kind.label) \(timestamp.date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(
                            "\(timestamp.kind.label) \(timestamp.date.formatted(date: .complete, time: .complete))"
                        )
                }
            }
            .frame(width: 112, alignment: .leading)

            channelActionButton(channel)
                .frame(width: 176)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            channel.kind == selectedChannel
                ? channelTint(channel.kind).opacity(0.055)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if channel.kind == selectedChannel {
                Capsule()
                    .fill(channelTint(channel.kind))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
    }

    func managedQClientStrip(_ snapshot: UpdateCenterSnapshot) -> some View {
        let installed = snapshot.qclient.installed
        let available = snapshot.qclient.available
        let compatible =
            installed?.isReady == true
            && QClientCompatibility.isCompatible(
                qclientReleaseVersion: installed?.releaseVersion,
                nodeVersion: snapshot.installed.build.version
            )
        return HStack(spacing: 14) {
            DashboardCircleIcon(systemImage: "terminal.fill", tint: theme.colors.accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("Managed qclient dependency")
                    .font(.subheadline.weight(.semibold))
                Text("Not a node channel · reused while protocol-compatible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            UpdateDetailRow(
                label: "Installed",
                value: installed?.releaseVersion ?? "Not managed"
            )
            UpdateDetailRow(
                label: "Available",
                value: available?.releaseVersion ?? "Unavailable"
            )
            Label(
                compatible ? "Compatible · reused" : "Needs attention",
                systemImage: compatible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(compatible ? theme.colors.success : theme.colors.warning)
            Button(compatible ? "Compatible" : (installed == nil ? "Install qclient" : "Update qclient")) {
                releaseChecker.requestInstallQClient()
            }
            .buttonStyle(.bordered)
            .disabled(
                compatible || available == nil || releaseChecker.isInstalling
                    || releaseChecker.stagedUpdate != nil
            )
        }
        .padding(12)
        .controlSurface(tint: theme.colors.accent)
    }

    private var selectedChannel: UpdateChannelKind? {
        switch releaseChecker.policy {
        case .manual: nil
        case .signedStable: .signed
        case .approvedDevelopment: .approved
        case .bleedingEdge: .raw
        }
    }

    private func performChannelAction(_ kind: UpdateChannelKind) {
        switch kind {
        case .signed: releaseChecker.requestInstallSigned()
        case .approved: releaseChecker.requestInstallApprovedDevelopment()
        case .raw: releaseChecker.requestInstallBleedingEdge()
        }
    }

    @ViewBuilder
    private func channelActionButton(_ channel: UpdateChannelPresentation) -> some View {
        let title = channel.action.state == .current ? "Installed" : channel.actionTitle
        if channel.kind == .approved {
            Button(title) { performChannelAction(channel.kind) }
                .buttonStyle(.borderedProminent)
                .tint(channelTint(channel.kind))
                .disabled(!channel.action.isEnabled)
                .help(channel.action.message)
        } else {
            Button(title) { performChannelAction(channel.kind) }
                .buttonStyle(.bordered)
                .tint(channelTint(channel.kind))
                .disabled(!channel.action.isEnabled)
                .help(channel.action.message)
        }
    }

    private func channelTint(_ kind: UpdateChannelKind) -> Color {
        switch kind {
        case .signed: theme.colors.success
        case .approved: theme.colors.info
        case .raw: theme.colors.warning
        }
    }

    private func assuranceTint(_ assurance: UpdateChannelAssurance) -> Color {
        switch assurance {
        case .highest: theme.colors.success
        case .approved: theme.colors.info
        case .experimental: theme.colors.warning
        }
    }

    private func stateTint(_ state: UpdateChannelState) -> Color {
        switch state {
        case .current: theme.colors.success
        case .ready, .commitsBehind, .newerSource: theme.colors.info
        case .installedAhead: theme.colors.success
        case .unavailable: theme.colors.warning
        }
    }

    private func stateIcon(_ state: UpdateChannelState) -> String {
        switch state {
        case .current: "checkmark.circle.fill"
        case .ready: "arrow.down.circle.fill"
        case .commitsBehind: "arrow.up.circle.fill"
        case .newerSource: "arrow.triangle.branch"
        case .installedAhead: "arrow.up.right.circle.fill"
        case .unavailable: "clock.badge.exclamationmark"
        }
    }
}
