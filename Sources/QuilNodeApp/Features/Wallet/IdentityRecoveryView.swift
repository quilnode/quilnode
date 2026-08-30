import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Custody workspace for complete node identity packages. The view receives
/// public inventory metadata only; file inspection and every key-changing
/// operation remain inside the code-signature-pinned local service.
struct IdentityRecoveryView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass
    @EnvironmentObject private var walletManager: WalletManager

    @State private var pendingTransaction: IdentityTransactionContext?
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
                    create: { pendingTransaction = .create(suggestedName: "My Quilibrium identity") },
                    importPackage: walletManager.chooseImportFolder
                )
            }
        }
        .onAppear(perform: synchronizeSelection)
        .onChange(of: walletManager.inventory.keysets.map(\.id)) { _, _ in
            synchronizeSelection()
        }
        .sheet(item: $pendingTransaction) { transaction in
            IdentityTransactionAssistantView(context: transaction)
                .environmentObject(walletManager)
                .quilThemed(theme)
        }
        .sheet(item: $walletManager.pendingImport, onDismiss: walletManager.discardPendingImport) { pending in
            IdentityTransactionAssistantView(context: .importKeyset(pending))
                .environmentObject(walletManager)
                .quilThemed(theme)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                recoveryHeaderCopy
                Spacer(minLength: 16)
                recoveryHeaderActions
            }
            VStack(alignment: .leading, spacing: 12) {
                recoveryHeaderCopy
                recoveryHeaderActions
            }
        }
    }

    private var recoveryHeaderCopy: some View {
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
    }

    private var recoveryHeaderActions: some View {
        HStack(spacing: 8) {
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
                Button("Create new identity", systemImage: "plus.circle") {
                    pendingTransaction = .create(suggestedName: "My Quilibrium identity")
                }
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

            if !dashboardLayoutClass.isWide {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        runway
                        inventory
                    }
                    dossier
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    runway.frame(width: 244)
                    inventory.frame(width: 232)
                    dossier
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

    private var runway: some View {
        RecoveryRunwayView(stages: presentation.stages)
            .frame(maxWidth: .infinity)
    }

    private var inventory: some View {
        RecoveryIdentityInventory(
            keysets: walletManager.inventory.keysets,
            selectedKeysetID: Binding(
                get: { selectedKeyset?.id },
                set: { selectedKeysetID = $0 }
            ),
            create: { pendingTransaction = .create(suggestedName: "My Quilibrium identity") },
            importPackage: walletManager.chooseImportFolder
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var dossier: some View {
        if let selectedKeyset {
            RecoveryIdentityDossier(
                keyset: selectedKeyset,
                export: { Task { await walletManager.exportRecovery(for: selectedKeyset) } },
                protect: {
                    Task { await walletManager.adoptActive(named: selectedKeyset.name) }
                },
                activate: { pendingTransaction = .activate(selectedKeyset) }
            )
            .frame(maxWidth: .infinity)
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
