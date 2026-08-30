import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct CreateIdentitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager
    @State private var name = "My Quilibrium identity"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                DashboardCircleIcon(systemImage: "person.badge.key.fill", tint: theme.colors.accent, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Create node identity").font(.title2.bold())
                    Text("Generated and validated locally")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }

            Text(
                "The signed local service asks the separately managed, verified qclient to create configuration. The installed node generates and validates the complete keyset, then a recovery copy is made immediately."
            )
            .font(.subheadline)
            .foregroundStyle(theme.colors.secondaryText)

            VStack(alignment: .leading, spacing: 6) {
                OnboardingSectionLabel(text: "Local identity label")
                TextField("Identity name", text: $name).textFieldStyle(.roundedBorder)
            }

            if walletManager.isWorking {
                QuilLoadingIndicator(label: walletManager.operationTitle ?? "Creating identity")
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create & activate") {
                    Task { if await walletManager.create(named: name) { dismiss() } }
                }
                .buttonStyle(.borderedProminent)
                .disabled(walletManager.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}

struct ImportKeysetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager

    let importItem: PendingKeysetImport
    @State private var name: String
    @State private var activate = true

    init(importItem: PendingKeysetImport) {
        self.importItem = importItem
        _name = State(initialValue: importItem.suggestedName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 13) {
                DashboardCircleIcon(
                    systemImage: importItem.inspection.requiresMigration
                        ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill",
                    tint: importItem.inspection.requiresMigration ? theme.colors.warning : theme.colors.success,
                    size: 46
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Complete keyset recognized").font(.title2.bold())
                    HStack(spacing: 4) {
                        Text(importItem.inspection.format.label + " · fingerprint ")
                        PrivacyProtectedText(value: importItem.inspection.fingerprint, field: .recoveryMetadata)
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.colors.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                OnboardingSectionLabel(text: "Local identity label")
                TextField("Identity name", text: $name).textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                KeysetFact(
                    title: "KEY ENTRIES",
                    value: "\(importItem.inspection.keyCount)",
                    privacyField: .recoveryMetadata
                )
                KeysetFact(title: "FORMAT", value: importItem.inspection.format.label)
                KeysetFact(
                    title: "MIGRATION",
                    value: importItem.inspection.requiresMigration ? "Required" : "Not required"
                )
            }

            if importItem.inspection.requiresMigration {
                Label(
                    "The legacy Ed448 seniority root remains in the complete package. The official current node creates missing current keys only after a verified pre-migration backup.",
                    systemImage: "clock.badge.checkmark"
                )
                .font(.caption)
                .foregroundStyle(theme.colors.warning)
                .padding(11)
                .controlSurface(tint: theme.colors.warning)
            }

            ForEach(importItem.inspection.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(theme.colors.warning)
            }

            Toggle("Activate after import", isOn: $activate)
            Text(
                activate
                    ? "Activation preserves stores. It may restart the node; failed validation restores the previous identity automatically."
                    : "The validated keyset is added to Identity Recovery without changing the running node."
            )
            .font(.caption2)
            .foregroundStyle(theme.colors.secondaryText)

            if walletManager.isWorking {
                QuilLoadingIndicator(label: walletManager.operationTitle ?? "Importing identity")
            }

            HStack {
                Button("Cancel") {
                    walletManager.discardPendingImport()
                    dismiss()
                }
                Spacer()
                Button("Import\(activate ? " & activate" : "")") {
                    Task {
                        await walletManager.importPending(named: name, activateAfterImport: activate)
                        if walletManager.error == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(walletManager.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 650)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}

private struct KeysetFact: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    var privacyField: PrivacyField? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            OnboardingSectionLabel(text: title)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(theme.colors.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
    }
}
