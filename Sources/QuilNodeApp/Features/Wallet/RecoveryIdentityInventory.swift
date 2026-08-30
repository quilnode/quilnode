import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct RecoveryIdentityInventory: View {
    @Environment(\.quilTheme) private var theme

    let keysets: [ManagedKeyset]
    @Binding var selectedKeysetID: UUID?
    let create: () -> Void
    let importPackage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Identity inventory")
                        .font(.headline)
                    Text("One identity can be active.")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                PrivacyProtectedText(
                    value: String(keysets.count),
                    field: .recoveryMetadata,
                    mask: .compact
                )
                .font(.caption2.bold().monospacedDigit())
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(theme.colors.surfaceElevated, in: Capsule())
            }
            .padding(12)

            Divider().overlay(theme.colors.border.opacity(0.58))

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(keysets) { keyset in
                        RecoveryIdentityInventoryRow(
                            keyset: keyset,
                            selected: selectedKeysetID == keyset.id
                        ) {
                            selectedKeysetID = keyset.id
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 245)

            Spacer(minLength: 6)
            Divider().overlay(theme.colors.border.opacity(0.48))

            HStack(spacing: 7) {
                Button("Create", systemImage: "plus.circle", action: create)
                    .buttonStyle(.bordered)
                Button("Import", systemImage: "square.and.arrow.down", action: importPackage)
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
            .padding(10)
        }
        .frame(maxWidth: .infinity, minHeight: 376, alignment: .topLeading)
        .controlSurface()
        .accessibilityElement(children: .contain)
    }
}

private struct RecoveryIdentityInventoryRow: View {
    @Environment(\.quilTheme) private var theme

    let keyset: ManagedKeyset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                DashboardCircleIcon(
                    systemImage: keyset.isActive ? "person.badge.key.fill" : "person.crop.circle",
                    tint: keyset.isActive ? theme.colors.success : theme.colors.accent,
                    size: 34
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        PrivacyProtectedText(
                            value: keyset.name,
                            field: .recoveryMetadata,
                            mask: .identifier
                        )
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        if keyset.isActive {
                            Text("ACTIVE")
                                .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.colors.success)
                        }
                    }
                    Text("\(keyset.format.label) · \(keyset.isManaged ? "Managed" : "Unmanaged")")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if keyset.requiresMigration {
                        Text("Migrates on activation")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(theme.colors.warning)
                    }
                }

                Spacer(minLength: 2)

                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(selected ? theme.colors.success : theme.colors.secondaryText)
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                (selected ? theme.colors.success : theme.colors.surfaceElevated)
                    .opacity(selected ? 0.07 : 0.62),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        selected ? theme.colors.success.opacity(0.9) : theme.colors.border.opacity(0.54),
                        lineWidth: selected ? 1.3 : 0.6
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: theme.colors.success, cornerRadius: 9)
        .accessibilityLabel("\(keyset.name), \(keyset.isActive ? "active" : "stored")")
        .accessibilityHint("Shows recovery details for this identity")
    }
}
