import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Read-only map of the public identities presented by the running node.
/// Custody operations remain isolated in `IdentityRecoveryView` so inspecting
/// public state can never be mistaken for reading or modifying private keys.
struct IdentityOverviewView: View {
    @Environment(\.quilTheme) private var theme

    let snapshot: NodeSnapshot
    let seniorityTrend: SeniorityTrend
    let onManageRecovery: () -> Void

    @State private var selectedRole: IdentityRole = .seniority

    private var presentation: IdentityWorkspacePresentation {
        .make(snapshot: snapshot, seniorityTrend: seniorityTrend)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack(alignment: .top, spacing: 12) {
                workspace
                    .frame(maxWidth: .infinity)

                IdentityRoleInspector(
                    role: presentation.role(selectedRole),
                    seniority: presentation.seniority,
                    seniorityTrend: presentation.seniorityTrend,
                    onCopy: IdentityActions.copy,
                    onOpen: IdentityActions.open
                )
                .frame(width: 300)
            }
        }
        .onChange(of: presentation.roles.map(\.kind)) { _, roles in
            if !roles.contains(selectedRole) {
                selectedRole = .seniority
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Node Identity")
                    .font(
                        .system(
                            size: 28 * theme.typography.scale,
                            weight: .bold,
                            design: theme.typography.displayDesign
                        ))
                Text("Understand the public roles your node presents without exposing its private keys.")
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

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            IdentitySummaryBand(presentation: presentation)

            IdentityRelationshipPath(
                roles: presentation.roles,
                selectedRole: $selectedRole
            )

            IdentityEvidenceLedger(
                roles: presentation.roles,
                selectedRole: $selectedRole,
                onCopy: IdentityActions.copy,
                onOpen: IdentityActions.open
            )

            IdentityCustodyBoundary()
        }
    }
}
