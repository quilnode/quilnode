import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Custody workspace for complete node identity packages. The view receives
/// public inventory metadata only; file inspection and every key-changing
/// operation remain inside the code-signature-pinned local service.
struct IdentityRecoveryView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager

    @State private var showingCreate = false
    @State private var pendingActivation: ManagedKeyset?
    @State private var selectedKeysetID: UUID?

    private var presentation: RecoveryWorkspacePresentation {
        .make(inventory: walletManager.inventory)
    }

    private var selectedKeyset: ManagedKeyset? {
        if let selectedKeysetID,
            let selected = walletManager.inventory.keysets.first(where: { $0.id == selectedKeysetID })
        {
            return selected
        }
        return walletManager.inventory.activeKeyset ?? walletManager.inventory.keysets.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            notice

            if walletManager.isRefreshing && walletManager.inventory.keysets.isEmpty {
                RecoveryLoadingView()
            } else if let active = walletManager.inventory.activeKeyset {
                recoveryWorkspace(active: active)
            } else {
                RecoveryEmptyState(
                    create: { showingCreate = true },
                    importPackage: walletManager.chooseImportFolder
                )
            }
        }
        .onAppear(perform: synchronizeSelection)
        .onChange(of: walletManager.inventory.keysets.map(\.id)) { _, _ in
            synchronizeSelection()
        }
        .sheet(isPresented: $showingCreate) {
            CreateIdentitySheet()
                .environmentObject(walletManager)
                .quilThemed(theme)
        }
        .sheet(item: $walletManager.pendingImport, onDismiss: walletManager.discardPendingImport) { pending in
            ImportKeysetSheet(importItem: pending)
                .environmentObject(walletManager)
                .quilThemed(theme)
        }
        .alert(item: $pendingActivation) { keyset in
            Alert(
                title: Text("Switch to \(keyset.name)?"),
                message: Text(RecoveryOperationCopy.activationConfirmation),
                primaryButton: .default(Text("Switch & verify")) {
                    Task { await walletManager.activate(id: keyset.id, name: keyset.name) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SELF-CUSTODY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.accent)
                Text("Identity Recovery")
                    .font(
                        .system(
                            size: 28 * theme.typography.scale,
                            weight: .bold,
                            design: theme.typography.displayDesign
                        ))
                Text("Know which recovery layers exist before you back up, import, or switch an identity.")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
            }

            Spacer(minLength: 16)

            Button {
                Task { await walletManager.refresh() }
            } label: {
                if walletManager.isRefreshing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Checking…")
                    }
                } else {
                    Label("Check status", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(walletManager.isRefreshing || walletManager.isWorking)
            .accessibilityLabel("Check identity recovery status")

            Menu {
                Button("Create new identity", systemImage: "plus.circle") { showingCreate = true }
                Button("Import identity package", systemImage: "square.and.arrow.down") {
                    walletManager.chooseImportFolder()
                }
            } label: {
                Label("Add identity", systemImage: "plus")
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .disabled(walletManager.isWorking)
            .accessibilityLabel("Add node identity")
        }
    }

    @ViewBuilder
    private var notice: some View {
        if walletManager.isWorking {
            RecoveryOperationNotice(title: walletManager.operationTitle ?? "Working securely")
        } else if let error = walletManager.error {
            RecoveryServiceNotice(
                detail: error,
                requiresAuthorization: walletManager.requiresServiceAuthorization,
                action: {
                    if walletManager.requiresServiceAuthorization {
                        Task { await walletManager.authorizeWalletService() }
                    } else {
                        Task { await walletManager.refresh() }
                    }
                }
            )
        } else if let message = walletManager.message {
            RecoveryResultNotice(message: message)
        }
    }

    private func recoveryWorkspace(active: ManagedKeyset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RecoverySummaryBand(presentation: presentation, active: active)

            HStack(alignment: .top, spacing: 12) {
                RecoveryRunwayView(stages: presentation.stages)
                    .frame(width: 244)

                RecoveryIdentityInventory(
                    keysets: walletManager.inventory.keysets,
                    selectedKeysetID: Binding(
                        get: { selectedKeyset?.id },
                        set: { selectedKeysetID = $0 }
                    ),
                    create: { showingCreate = true },
                    importPackage: walletManager.chooseImportFolder
                )
                .frame(width: 232)

                if let selectedKeyset {
                    RecoveryIdentityDossier(
                        keyset: selectedKeyset,
                        export: { Task { await walletManager.exportRecovery(for: selectedKeyset) } },
                        protect: {
                            Task { await walletManager.adoptActive(named: selectedKeyset.name) }
                        },
                        activate: { pendingActivation = selectedKeyset }
                    )
                    .frame(maxWidth: .infinity)
                }
            }

            RecoveryActionBar(
                presentation: presentation,
                isWorking: walletManager.isWorking,
                export: { Task { await walletManager.exportRecovery(for: active) } },
                protect: { Task { await walletManager.adoptActive(named: active.name) } }
            )

            RecoveryOperationSequence()
        }
    }

    private func synchronizeSelection() {
        let validIDs = Set(walletManager.inventory.keysets.map(\.id))
        if let selectedKeysetID, validIDs.contains(selectedKeysetID) { return }
        self.selectedKeysetID =
            walletManager.inventory.activeKeyset?.id
            ?? walletManager.inventory.keysets.first?.id
    }
}
