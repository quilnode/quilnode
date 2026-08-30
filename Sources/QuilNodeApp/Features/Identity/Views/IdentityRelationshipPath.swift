import SwiftUI

struct IdentityRelationshipPath: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    let roles: [IdentityRolePresentation]
    @Binding var selectedRole: IdentityRole

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("Identity relationships")
                    .font(.headline)
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .help(
                        "One node can expose distinct public identifiers for transport, history, proving, and its spendable account."
                    )
                    .accessibilityLabel("About identity relationships")
                Spacer()
                Text("SELECT A ROLE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(theme.colors.secondaryText)
            }

            HStack(spacing: 0) {
                ForEach(Array(roles.enumerated()), id: \.element.id) { index, role in
                    IdentityRoleButton(
                        role: role,
                        selected: selectedRole == role.kind
                    ) {
                        selectedRole = role.kind
                    }

                    if index < roles.count - 1 {
                        IdentityRoleConnector()
                            .frame(width: 24)
                    }
                }
            }
            .animation(motion.selection, value: selectedRole)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct IdentityRoleButton: View {
    @Environment(\.quilTheme) private var theme

    let role: IdentityRolePresentation
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                DashboardCircleIcon(
                    systemImage: role.kind.symbol,
                    tint: selected ? theme.colors.success : theme.colors.accent,
                    size: 34
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(role.kind.layer)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background(
                (selected ? theme.colors.surfaceElevated : theme.colors.surface)
                    .opacity(selected ? 0.95 : 0.64),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        selected ? theme.colors.success.opacity(0.92) : theme.colors.border.opacity(0.66),
                        lineWidth: selected ? 1.4 : max(theme.metrics.borderWidth, 0.5)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: theme.colors.accent, cornerRadius: 11)
        .accessibilityLabel("\(role.kind.title), \(role.kind.layer)")
        .accessibilityHint("Shows details for this public identity")
    }
}

private struct IdentityRoleConnector: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        ZStack {
            Capsule()
                .fill(theme.colors.border.opacity(0.72))
                .frame(height: 1)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(theme.colors.secondaryText)
                .padding(3)
                .background(theme.colors.canvas, in: Circle())
        }
        .accessibilityHidden(true)
    }
}
