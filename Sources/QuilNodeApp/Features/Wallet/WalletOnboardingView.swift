import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct WalletOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager
    @State private var createName = "My Quilibrium identity"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 9) {
                    ZStack {
                        ThemeAccentShape(shape: RoundedRectangle(cornerRadius: 9))
                        Text("Q").font(.headline.weight(.black)).foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)
                    Text("QuilNode setup").font(.headline)
                }
                Spacer()
                if walletManager.inventory.activeKeyset != nil {
                    Button("Do this later") {
                        walletManager.dismissOnboarding()
                        dismiss()
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(18)
            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your node identity, safely managed")
                        .font(
                            .system(
                                size: 31 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign
                            ))
                    Text(
                        "QuilNode can create a new identity or import an older keyset, detect its format, preserve the Ed448 seniority root, let the official .25 node perform migration, and roll back automatically if validation fails."
                    )
                    .font(.subheadline).foregroundStyle(theme.colors.secondaryText).fixedSize(
                        horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 10) {
                        OnboardingPromise(
                            icon: "eye.slash", title: "Interface cannot read secrets",
                            text:
                                "The GUI passes only your intent and selected folder; the signed local service validates keysets without returning private bytes."
                        )
                        OnboardingPromise(
                            icon: "checkmark.shield", title: "Backup before mutation",
                            text: "Every activation starts with a root-protected, hash-verified recovery copy.")
                        OnboardingPromise(
                            icon: "arrow.uturn.backward", title: "Atomic recovery",
                            text: "A failed migration or startup restores the previous pair and restarts it.")
                    }
                    Spacer()
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Divider()

                VStack(alignment: .leading, spacing: 13) {
                    if let active = walletManager.inventory.activeKeyset {
                        Text("Existing identity detected").font(.title3.bold())
                        Text("\(active.format.label) · \(active.keyCount) key entries")
                            .font(.caption.monospaced()).foregroundStyle(theme.colors.secondaryText)
                        Button {
                            Task { if await walletManager.adoptActive() { dismiss() } }
                        } label: {
                            Label("Keep & protect this identity", systemImage: "checkmark.shield.fill").frame(
                                maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    } else {
                        Text("Choose your starting point").font(.title3.bold())
                    }

                    Button {
                        walletManager.chooseImportFolder()
                    } label: {
                        OnboardingChoice(
                            icon: "square.and.arrow.down", title: "Import a keyset",
                            detail: "Auto-detect legacy and .25 formats")
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("NEW IDENTITY NAME")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(theme.colors.secondaryText)
                        TextField("Identity name", text: $createName).textFieldStyle(.roundedBorder)
                        Button {
                            Task { if await walletManager.create(named: createName) { dismiss() } }
                        } label: {
                            OnboardingChoice(
                                icon: "plus.circle", title: "Create a new identity",
                                detail: "Generated locally by the verified official client")
                        }
                        .buttonStyle(.plain)
                        .disabled(createName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if walletManager.isWorking {
                        HStack {
                            ProgressView()
                            Text(walletManager.operationTitle ?? "Working…").font(.caption)
                        }
                    }
                    if let error = walletManager.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(
                            theme.colors.danger
                        ).textSelection(.enabled)
                        if walletManager.requiresServiceAuthorization {
                            Button("Review & authorize Identity Recovery") {
                                Task { await walletManager.authorizeWalletService() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(walletManager.isWorking)
                        } else {
                            Button("Retry inspection") { Task { await walletManager.refresh() } }
                                .buttonStyle(.bordered)
                                .disabled(walletManager.isRefreshing)
                        }
                    }
                    Spacer()
                    Text(
                        "QuilNode never deletes stores during identity onboarding. Stores are preserved and can resynchronize independently of this keyset flow."
                    )
                    .font(.caption2).foregroundStyle(theme.colors.secondaryText)
                }
                .padding(24)
                .frame(width: 340)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(theme.colors.surface.opacity(0.65))
            }
        }
        .frame(width: 820, height: 560)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .sheet(item: $walletManager.pendingImport, onDismiss: walletManager.discardPendingImport) { pending in
            ImportKeysetSheet(importItem: pending).environmentObject(walletManager).quilThemed(theme)
        }
    }
}

private struct OnboardingPromise: View {
    let icon: String, title: String, text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct OnboardingChoice: View {
    @Environment(\.quilTheme) private var theme
    let icon: String, title: String, detail: String
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.title3).foregroundStyle(theme.colors.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.colors.secondaryText)
        }
        .padding(12).background(
            theme.colors.surfaceElevated, in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius).strokeBorder(
                theme.colors.border.opacity(0.5), lineWidth: 0.5))
    }
}

struct CreateIdentitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @State private var name = "My Quilibrium identity"
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Create node identity", systemImage: "person.badge.key.fill").font(.title2.bold())
            Text(
                "The signed local service asks the separately managed, verified official qclient to create the configuration, then the installed .25 node generates and validates the full keyset. The interface never opens the files, and a recovery copy is made immediately."
            ).foregroundStyle(.secondary)
            TextField("Identity name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create & activate") { Task { if await walletManager.create(named: name) { dismiss() } } }
                    .buttonStyle(.borderedProminent).disabled(
                        walletManager.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if walletManager.isWorking { ProgressView(walletManager.operationTitle ?? "Creating…") }
        }.padding(24).frame(width: 500)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DashboardCircleIcon(
                    systemImage: importItem.inspection.requiresMigration
                        ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill",
                    tint: importItem.inspection.requiresMigration ? theme.colors.warning : theme.colors.success,
                    size: 44)
                VStack(alignment: .leading) {
                    Text("Keyset recognized").font(.title2.bold())
                    Text(importItem.inspection.format.label + " · fingerprint " + importItem.inspection.fingerprint)
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            TextField("Identity name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                KeysetFact(title: "KEY ENTRIES", value: "\(importItem.inspection.keyCount)")
                KeysetFact(title: "FORMAT", value: importItem.inspection.format.label)
                KeysetFact(title: "MIGRATION", value: importItem.inspection.requiresMigration ? "Required" : "No")
            }
            if importItem.inspection.requiresMigration {
                Label(
                    "The old Ed448 peer key remains the seniority root. The official .25 node will preserve legacy entries and create missing Falcon/wallet keys only after a verified pre-migration backup.",
                    systemImage: "clock.badge.checkmark"
                )
                .font(.caption).foregroundStyle(theme.colors.warning).padding(10).background(
                    theme.colors.warning.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            }
            ForEach(importItem.inspection.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(
                    theme.colors.warning)
            }
            Toggle("Activate after import", isOn: $activate)
            Text(
                "Activation stops only the Quilibrium node. Stores are preserved. A failed migration restores the prior identity automatically."
            ).font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") {
                    walletManager.discardPendingImport()
                    dismiss()
                }
                Button("Import\(activate ? " & activate" : "")") {
                    Task {
                        await walletManager.importPending(named: name, activateAfterImport: activate)
                        if walletManager.error == nil { dismiss() }
                    }
                }.buttonStyle(.borderedProminent).disabled(
                    walletManager.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if walletManager.isWorking { ProgressView(walletManager.operationTitle ?? "Importing…") }
        }.padding(24).frame(width: 620)
    }
}

private struct KeysetFact: View {
    let title: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(
            .quaternary, in: RoundedRectangle(cornerRadius: 9))
    }
}
