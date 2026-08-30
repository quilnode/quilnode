import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Read-only view of the identity that the running node currently presents to
/// the network. Custody operations intentionally live in `IdentityRecoveryView`
/// so public runtime status and private recovery work never look interchangeable.
struct IdentityOverviewView: View {
    @Environment(\.quilTheme) private var theme

    let snapshot: NodeSnapshot
    let seniorityTrend: SeniorityTrend
    let onManageRecovery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.panelGap * theme.metrics.spacingScale) {
            pageHeader
            participationCard
            publicIdentifiers
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Node Identity")
                    .font(
                        .system(
                            size: 28 * theme.typography.scale,
                            weight: .bold,
                            design: theme.typography.displayDesign
                        ))
                Text("Public identifiers and participation state used by the node that is running now.")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 20)
            Button(action: onManageRecovery) {
                Label("Manage recovery", systemImage: "externaldrive.badge.checkmark")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help("Back up, import, or switch the complete node identity")
            .accessibilityLabel("Manage identity recovery")
            .accessibilityHint("Opens Identity Recovery")
        }
    }

    private var participationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Participation", systemImage: "checkmark.seal.text.page")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                LocalIdentitySourceBadge(title: "LOCAL CHAIN STATE")
            }

            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 14) {
                    DashboardCircleIcon(
                        systemImage: participationIcon,
                        tint: participationTint,
                        size: 46
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        participationTitle
                            .font(.title3.bold())
                        Text(participationDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            IdentityStatusPill(
                                title: snapshot.seniority > 0 ? "Chain value read" : "Chain value pending",
                                systemImage: snapshot.seniority > 0 ? "checkmark.shield" : "clock",
                                tint: snapshot.seniority > 0 ? theme.colors.success : theme.colors.warning
                            )
                            IdentityStatusPill(
                                title: snapshot.peers > 0 ? "Mesh connected" : "Waiting for peers",
                                systemImage: "antenna.radiowaves.left.and.right",
                                tint: snapshot.peers > 0 ? theme.colors.info : theme.colors.warning
                            )
                        }
                    }
                    Spacer(minLength: 12)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
                .controlSurface(tint: participationTint)

                VStack(spacing: 12) {
                    ChainSeniorityFact(
                        snapshot: snapshot,
                        trend: seniorityTrend
                    )
                    Divider()
                    IdentityAllocationFact(snapshot: snapshot)
                }
                .padding(16)
                .frame(width: 330)
                .frame(minHeight: 138)
                .controlSurface()
            }

            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                Text(DashboardCopy.Identity.registryEvidence)
                    .fontWeight(.semibold)
                Text("·")
                Text(DashboardCopy.Identity.evidenceExplanation)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }

    private var publicIdentifiers: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Public identifiers", systemImage: "person.text.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("READ ONLY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                PublicIdentityRow(
                    label: "Network peer",
                    detail: "Current mesh identity",
                    value: snapshot.peerID,
                    systemImage: "network",
                    externalURL: IdentityExplorerLink.peer(snapshot.peerID)
                )
                rowDivider
                PublicIdentityRow(
                    label: "Seniority identity",
                    detail: "Legacy Ed448 root used for merges",
                    value: snapshot.legacyPeerID,
                    systemImage: "clock.arrow.circlepath",
                    externalURL: IdentityExplorerLink.peer(snapshot.legacyPeerID)
                )
                rowDivider
                PublicIdentityRow(
                    label: "Prover address",
                    detail: "Proof and allocation identity",
                    value: snapshot.proverAddress,
                    systemImage: "checkmark.seal",
                    externalURL: IdentityExplorerLink.prover(snapshot.proverAddress)
                )
                rowDivider
                PublicIdentityRow(
                    label: "QUIL account",
                    detail: "Spendable token account",
                    value: snapshot.quilAccount,
                    systemImage: "wallet.bifold"
                )

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(theme.colors.success)
                    Text(DashboardCopy.Identity.custodyBoundary)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(
                    theme.colors.success.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .padding(12)
            }
            .controlSurface()
        }
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 58)
    }

    @ViewBuilder
    private var participationTitle: some View {
        if !snapshot.isRunning {
            Text("Node offline")
        } else if snapshot.activeShards > 0 {
            HStack(spacing: 0) {
                Text("Active on ")
                PrivacyProtectedText(
                    value: String(snapshot.activeShards),
                    field: .activeShardCount
                )
                Text(" shards")
            }
        } else if snapshot.pendingJoins > 0 {
            Text("Registered · joining")
        } else if snapshot.totalAllocations > 0 {
            Text("Allocated · waiting")
        } else {
            Text("Online · awaiting allocation")
        }
    }

    private var participationDetail: String {
        if !snapshot.isRunning {
            return "Start the node to resume synchronization and prover participation."
        }
        if snapshot.activeShards > 0 {
            return
                "Serving assigned shard work. Rewards are separate and appear only after validated reward-bearing frames are credited."
        }
        if snapshot.pendingJoins > 0 {
            return
                "The active identity is recognized and joining allocations. Reward eligibility begins only after activation."
        }
        return "Connected to the network, but the consensus registry has not assigned active shard work."
    }

    private var participationIcon: String {
        if !snapshot.isRunning { return "power" }
        return snapshot.activeShards > 0 ? "bolt.fill" : "hourglass"
    }

    private var participationTint: Color {
        if !snapshot.isRunning { return theme.colors.danger }
        return snapshot.activeShards > 0 ? theme.colors.success : theme.colors.warning
    }

}
