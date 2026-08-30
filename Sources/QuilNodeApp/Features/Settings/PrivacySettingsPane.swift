import SwiftUI

struct PrivacySettingsPane: View {
    @EnvironmentObject private var privacyMode: PrivacyModeController
    @Environment(\.quilTheme) private var theme

    var body: some View {
        SettingsPaneContainer(
            title: "Privacy",
            subtitle: "Control which local and operational values QuilNode reveals on screen.",
            systemImage: "eye.slash.fill"
        ) {
            SettingsCard(tint: theme.colors.privacy) {
                Toggle(isOn: $privacyMode.isEnabled) {
                    HStack(alignment: .center, spacing: 13) {
                        Image(systemName: privacyMode.isEnabled ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.colors.privacy)
                            .frame(width: 36, height: 36)
                            .background(
                                theme.colors.privacy.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("Privacy Mode")
                                    .font(.headline)
                                SettingsStatusPill(
                                    title: privacyMode.isEnabled ? "Values masked" : "Values visible",
                                    tint: privacyMode.isEnabled ? theme.colors.privacy : theme.colors.secondaryText
                                )
                            }
                            Text(
                                privacyMode.isEnabled
                                    ? "Sensitive and correlatable values are masked throughout QuilNode."
                                    : "Sensitive and correlatable values are currently visible."
                            )
                            .font(.caption)
                            .foregroundStyle(theme.colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.large)
                .accessibilityHint(
                    privacyMode.isEnabled
                        ? "Shows sensitive local and operational values"
                        : "Masks sensitive local and operational values throughout QuilNode")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("VALUES PROTECTED ON SCREEN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(theme.colors.secondaryText)

                SettingsCard {
                    PrivacyScopeRow(
                        systemImage: "person.text.rectangle",
                        title: "Identity and wallet",
                        detail:
                            "Peer and prover identifiers, recovery metadata, seniority, addresses, and QUIL balance."
                    )
                    SettingsDivider()
                    PrivacyScopeRow(
                        systemImage: "cpu",
                        title: "Node and hardware",
                        detail: "Uptime, allocation and shard counts, hardware profile, and local activity history."
                    )
                    SettingsDivider()
                    PrivacyScopeRow(
                        systemImage: "network",
                        title: "Network and local context",
                        detail:
                            "Gateway and LAN identifiers, active ports, traffic details, usernames, and local timestamps."
                    )
                }
            }

            SettingsCallout(
                systemImage: "lock.shield.fill",
                title: "Presentation protection—not encryption or anonymity",
                detail:
                    "Labels and controls remain usable, while only classified values are masked. Node operation, files, network traffic, and clipboard actions do not change. Private-key bytes are never exposed to this interface.",
                tint: theme.colors.info
            )

            HStack(spacing: 6) {
                Image(systemName: "command")
                Text("Toggle Privacy Mode anywhere with Shift–Command–P.")
            }
            .font(.caption2)
            .foregroundStyle(theme.colors.secondaryText)
            .padding(.horizontal, 2)
        }
    }
}
