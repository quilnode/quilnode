import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct RecoveryIdentityDossier: View {
    @Environment(\.quilTheme) private var theme

    let keyset: ManagedKeyset
    let export: () -> Void
    let protect: () -> Void
    let activate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dossierHeader
            Divider().overlay(theme.colors.border.opacity(0.6))

            HStack(alignment: .top, spacing: 14) {
                packageDetails
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Divider().frame(height: 212)
                recoveryDetails
                    .frame(width: 190, alignment: .topLeading)
            }
            .padding(12)

            Divider().overlay(theme.colors.border.opacity(0.48))
            dossierFooter
        }
        .frame(maxWidth: .infinity, minHeight: 376, alignment: .topLeading)
        .controlSurface(tint: keyset.isActive ? theme.colors.success : theme.colors.accent)
        .accessibilityElement(children: .contain)
    }

    private var dossierHeader: some View {
        HStack(spacing: 11) {
            DashboardCircleIcon(
                systemImage: keyset.isActive ? "person.badge.key.fill" : "person.crop.circle",
                tint: keyset.isActive ? theme.colors.success : theme.colors.accent,
                size: 40
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    PrivacyProtectedText(
                        value: keyset.name,
                        field: .recoveryMetadata,
                        mask: .identifier
                    )
                    .font(.title3.bold())
                    if keyset.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.colors.success)
                    }
                }
                Text("Selected identity dossier · public recovery metadata")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 10)
            if keyset.isActive {
                Label("Installed", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.success)
            }
        }
        .padding(12)
    }

    private var packageDetails: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Package details")
            dossierRow("Format", keyset.format.label)
            dossierRow("Custody", keyset.isManaged ? "Managed locally" : "Protection required")
            dossierRow(
                "Last activated",
                keyset.lastActivatedAt.map {
                    $0.formatted(date: .abbreviated, time: .shortened)
                } ?? "Current node",
                privacyField: keyset.lastActivatedAt == nil ? nil : .localTimestamp
            )
            dossierRow(
                "Fingerprint",
                keyset.fingerprint,
                privacyField: .recoveryMetadata,
                mask: .identifier,
                monospaced: true
            )
            dossierRow(
                "Source",
                keyset.sourceLabel,
                privacyField: .recoveryMetadata
            )

            Divider().overlay(theme.colors.border.opacity(0.42))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .foregroundStyle(theme.colors.info)
                VStack(alignment: .leading, spacing: 2) {
                    Text("One complete recovery unit")
                        .font(.caption.weight(.semibold))
                    Text("config.yml + keys.yml")
                        .font(.caption2.monospaced())
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }

            if keyset.requiresMigration {
                Label("Official node migration required on activation", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.warning)
            } else {
                Label("Package format is current", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.success)
            }
        }
    }

    private var recoveryDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recovery copies")

            recoveryFact(
                title: "Automatic rollback",
                value: keyset.automaticRecoveryCopies > 0
                    ? "\(keyset.automaticRecoveryCopies) verified"
                    : "Not verified",
                detail: "On this Mac",
                symbol: keyset.automaticRecoveryCopies > 0
                    ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                tint: keyset.automaticRecoveryCopies > 0 ? theme.colors.success : theme.colors.warning,
                privacyField: keyset.automaticRecoveryCopies > 0 ? .recoveryMetadata : nil
            )

            recoveryFact(
                title: "Separate backup",
                value: keyset.lastExternalBackupAt.map {
                    $0.formatted(date: .abbreviated, time: .shortened)
                } ?? "None recorded",
                detail: "Operator-controlled storage",
                symbol: keyset.lastExternalBackupAt == nil
                    ? "externaldrive.badge.exclamationmark" : "externaldrive.badge.checkmark",
                tint: keyset.lastExternalBackupAt == nil ? theme.colors.warning : theme.colors.success,
                privacyField: keyset.lastExternalBackupAt == nil ? nil : .localTimestamp
            )

            if !keyset.warnings.isEmpty {
                Label(
                    "\(keyset.warnings.count) package warning\(keyset.warnings.count == 1 ? "" : "s")",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colors.warning)
            }
        }
    }

    @ViewBuilder
    private var dossierFooter: some View {
        HStack(spacing: 8) {
            Label(
                "Private key bytes never enter this interface",
                systemImage: "lock.shield.fill"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.colors.success)

            Spacer(minLength: 8)

            if keyset.isActive && !keyset.isManaged {
                Button("Protect identity", systemImage: "checkmark.shield", action: protect)
                    .buttonStyle(.borderedProminent)
            } else if !keyset.isActive {
                Button("Export copy", systemImage: "square.and.arrow.up", action: export)
                    .buttonStyle(.bordered)
                Button("Switch & verify", systemImage: "arrow.triangle.2.circlepath", action: activate)
                    .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.small)
        .padding(12)
    }

    private func sectionLabel(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.55)
            .foregroundStyle(theme.colors.secondaryText)
    }

    private func dossierRow(
        _ title: String,
        _ value: String,
        privacyField: PrivacyField? = nil,
        mask: PrivacyMaskStyle? = nil,
        monospaced: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer(minLength: 6)
            PrivacyProtectedText(value: value, field: privacyField, mask: mask)
                .font(monospaced ? .caption2.monospaced() : .caption2.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.7)
        }
    }

    private func recoveryFact(
        title: String,
        value: String,
        detail: String,
        symbol: String,
        tint: Color,
        privacyField: PrivacyField?
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
