import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var updateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(
                title: "QuilNode application",
                systemImage: "arrow.down.app.fill"
            )
            AppUpdateDashboardCard()

            DashboardSectionHeader(
                title: DashboardCopy.Updates.releaseChannels,
                systemImage: "arrow.triangle.2.circlepath"
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Automatic updates")
                        .font(.subheadline.weight(.semibold))
                    Picker(
                        "Automatic updates",
                        selection: Binding(
                            get: { releaseChecker.policy },
                            set: { selection in
                                if selection == .manual {
                                    releaseChecker.setPolicy(.manual)
                                } else {
                                    pendingUpdatePolicy = selection
                                }
                            }
                        )
                    ) {
                        Text("Off").tag(NodeUpdatePolicy.manual)
                        Text("Signed only").tag(NodeUpdatePolicy.signedStable)
                        Text("Approved Dev").tag(NodeUpdatePolicy.approvedDevelopment)
                        Text("Raw Dev").tag(NodeUpdatePolicy.bleedingEdge)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)
                }
                Text(
                    "Choose an automatic channel, then decide whether to update immediately or begin its six-hour schedule. One-time channel actions remain available below."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if releaseChecker.policy != .manual {
                    HStack(spacing: 8) {
                        Label(automaticScheduleDescription, systemImage: "clock.badge.checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            releaseChecker.requestAutomaticCheck()
                        } label: {
                            Label("Run now", systemImage: "play.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(releaseChecker.isWorking)
                        .help("Check now and install a newer release allowed by the selected automatic policy")
                    }
                }
            }

            updateProcessOverview

            HStack(spacing: 14) {
                DashboardCircleIcon(systemImage: updateCenterIcon, tint: updateCenterTint, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(updateCenterTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(updateCenterDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    if releaseChecker.isChecking {
                        releaseChecker.cancelCheck()
                    } else {
                        releaseChecker.requestCheck()
                    }
                } label: {
                    if releaseChecker.isChecking {
                        Label("Cancel", systemImage: "xmark")
                    } else if releaseChecker.lastError != nil {
                        Label("Retry", systemImage: "arrow.clockwise")
                    } else {
                        Label("Refresh releases", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(releaseChecker.isInstalling)
                .accessibilityHint(
                    releaseChecker.isChecking
                        ? "Stops this release check and keeps the previous results"
                        : "Refreshes release information without installing anything"
                )
            }
            .padding(16)
            .controlSurface(tint: updateCenterTint)

            if let checkProgress = releaseChecker.releaseCheckProgress {
                releaseCheckProgressCard(checkProgress)
            }

            if let progress = releaseChecker.progress {
                updateProgressCard(progress)
            }

            if case let .available(snapshot) = releaseChecker.state {
                DashboardSectionHeader(
                    title: "One-time installs",
                    systemImage: "shippingbox.and.arrow.backward"
                )
                installedBuildCard(snapshot.installed)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    signedChannelCard(snapshot)
                    qclientChannelCard(snapshot)
                    approvedDevelopmentCard(snapshot)
                    rawDevelopmentCard(snapshot)
                }
            }

            if let message = releaseChecker.lastMessage {
                Label(
                    PrivacySanitizer.display(message, enabled: privacyModeEnabled),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(theme.colors.success)
            }
            if let error = releaseChecker.lastError {
                Label(
                    PrivacySanitizer.display(error, enabled: privacyModeEnabled),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(theme.colors.danger)
                .textSelection(.enabled)
            }

            if let event = releaseChecker.history.first {
                HStack {
                    Label("Last update", systemImage: "clock.arrow.circlepath")
                    Text(
                        "\(event.result.capitalized) · \(event.version) · \(event.timestamp.formatted(date: .abbreviated, time: .standard))"
                    )
                    Spacer()
                    if let commit = event.commit { Text(String(commit.prefix(8))).monospaced() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }

            Text(updatePolicyFootnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .alert(
            "Enable \(pendingUpdatePolicy?.title ?? "") updates?",
            isPresented: Binding(
                get: { pendingUpdatePolicy != nil },
                set: { if !$0 { pendingUpdatePolicy = nil } }
            ),
            presenting: pendingUpdatePolicy
        ) { policy in
            Button("Enable & update now") {
                pendingUpdatePolicy = nil
                releaseChecker.setPolicy(policy, updateNow: true)
            }
            Button("Enable for later") {
                pendingUpdatePolicy = nil
                releaseChecker.setPolicy(policy, updateNow: false)
            }
            Button("Cancel", role: .cancel) {
                pendingUpdatePolicy = nil
            }
        } message: { policy in
            Text(updatePolicyConfirmationMessage(policy))
        }
    }
}
