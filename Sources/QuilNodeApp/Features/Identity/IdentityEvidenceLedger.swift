import SwiftUI

struct IdentityEvidenceLedger: View {
    @Environment(\.quilTheme) private var theme

    let roles: [IdentityRolePresentation]
    @Binding var selectedRole: IdentityRole
    let onCopy: (String?) -> Void
    let onOpen: (URL?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ledgerHeader
            Divider().overlay(theme.colors.border.opacity(0.62))

            ForEach(roles) { role in
                IdentityLedgerRow(
                    role: role,
                    selected: selectedRole == role.kind,
                    onSelect: { selectedRole = role.kind },
                    onCopy: { onCopy(role.value) },
                    onOpen: { onOpen(role.externalURL) }
                )

                if role.id != roles.last?.id {
                    Divider()
                        .overlay(theme.colors.border.opacity(0.44))
                        .padding(.leading, 12)
                }
            }
        }
        .controlSurface()
        .accessibilityElement(children: .contain)
    }

    private var ledgerHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Public identifiers")
                    .font(.headline)
                Text("Public · read only")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .frame(width: 160, alignment: .leading)

            Text("PUBLIC IDENTIFIER")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("SOURCE")
                .frame(width: 90, alignment: .leading)
            Text("KIND")
                .frame(width: 102, alignment: .leading)
            Text("VERIFIED")
                .frame(width: 58, alignment: .trailing)
            Text("ACTIONS")
                .frame(width: 62, alignment: .trailing)
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .tracking(0.55)
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
    }
}

private struct IdentityLedgerRow: View {
    @Environment(\.quilTheme) private var theme

    let role: IdentityRolePresentation
    let selected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                roleLabel
                    .frame(width: 160, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onSelect) {
                PrivacyProtectedText(
                    value: role.displayedValue,
                    field: role.privacyField
                )
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(role.isAvailable ? theme.colors.primaryText : theme.colors.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            evidenceCell(role.evidenceSource)
                .frame(width: 90, alignment: .leading)
            evidenceCell(role.evidenceKind)
                .frame(width: 102, alignment: .leading)

            PrivacyProtectedText(
                value: role.observedAt.map(IdentityFreshnessFormatter.string) ?? "Pending",
                field: role.observedAt == nil ? nil : .localTimestamp,
                mask: .compact
            )
            .font(.caption2.monospacedDigit())
            .foregroundStyle(theme.colors.secondaryText)
            .lineLimit(1)
            .frame(width: 58, alignment: .trailing)

            HStack(spacing: 2) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .disabled(!role.isAvailable)
                .help("Copy \(role.kind.title.lowercased())")
                .accessibilityLabel("Copy \(role.kind.title.lowercased())")

                if role.externalURL != nil {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.right.square")
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!role.isAvailable)
                    .help("Open \(role.kind.title.lowercased()) on Quilscan")
                    .accessibilityLabel("Open \(role.kind.title.lowercased()) on Quilscan")
                } else {
                    Color.clear.frame(width: 26, height: 26)
                }
            }
            .frame(width: 62, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 50)
        .background(selected ? theme.colors.success.opacity(0.055) : Color.clear)
        .overlay(alignment: .leading) {
            if selected {
                Capsule()
                    .fill(theme.colors.success)
                    .frame(width: 2, height: 30)
                    .padding(.leading, 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var roleLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: role.kind.symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(selected ? theme.colors.success : theme.colors.secondaryText)
                .frame(width: 22, height: 22)
                .background(
                    (selected ? theme.colors.success : theme.colors.accent).opacity(0.09),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(role.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.primaryText)
                    .lineLimit(1)
                Text(role.kind.detail)
                    .font(.system(size: 8.5))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }

    private func evidenceCell(_ value: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(theme.colors.success)
                .frame(width: 5, height: 5)
            Text(value)
                .font(.system(size: 9))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }
}

struct IdentityCustodyBoundary: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(theme.colors.success)
            Text(
                "Only public identifiers and balances reach this dashboard. Private key bytes remain inside the isolated node and custody service."
            )
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(
            theme.colors.success.opacity(0.075),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(theme.colors.success.opacity(0.13), lineWidth: 0.6)
        }
    }
}
