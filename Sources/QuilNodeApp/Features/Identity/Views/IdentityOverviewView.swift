import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Read-only map of the public identities presented by the running node.
/// Custody operations remain isolated in `IdentityRecoveryView` so inspecting
/// public state can never be mistaken for reading or modifying private keys.
struct IdentityOverviewView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass

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

            if dashboardLayoutClass.isWide {
                HStack(alignment: .top, spacing: 12) {
                    workspace
                        .frame(maxWidth: .infinity)
                    inspector
                        .frame(width: 300)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    workspace
                    inspector
                }
            }
        }
        .onChange(of: presentation.roles.map(\.kind)) { _, roles in
            if !roles.contains(selectedRole) {
                selectedRole = .seniority
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                headerCopy
                Spacer(minLength: 20)
                recoveryButton
            }
            VStack(alignment: .leading, spacing: 12) {
                headerCopy
                recoveryButton
            }
        }
    }

    private var headerCopy: some View {
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
    }

    private var recoveryButton: some View {
        Button(action: onManageRecovery) {
            Label("Manage recovery", systemImage: "externaldrive.badge.checkmark")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .help("Back up, import, or switch the complete node identity")
        .accessibilityLabel("Manage identity recovery")
        .accessibilityHint("Opens Identity Recovery")
    }

    private var inspector: some View {
        IdentityRoleInspector(
            role: presentation.role(selectedRole),
            seniority: presentation.seniority,
            seniorityIsObserved: presentation.seniorityIsObserved,
            seniorityTrend: presentation.seniorityTrend,
            chainEvidenceSource: presentation.chainEvidenceSource,
            chainEvidenceKind: presentation.chainEvidenceKind,
            chainEvidenceAt: presentation.chainEvidenceAt,
            onCopy: IdentityActions.copy,
            onOpen: IdentityActions.open
        )
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
