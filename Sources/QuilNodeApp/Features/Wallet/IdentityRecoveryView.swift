import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Custody and recovery operations for complete node identity packages.
/// Live/public identity status belongs to `IdentityOverviewView`; keeping this
/// surface task-specific prevents a node keyset from being mistaken for a
/// spendable-token wallet.
struct IdentityRecoveryView: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager
    @State private var showingCreate = false
    @State private var pendingActivation: ManagedKeyset?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.panelGap * theme.metrics.spacingScale) {
            pageHeader
            if let error = walletManager.error {
                serviceNotice(error)
            } else if let message = walletManager.message {
                resultNotice(message)
            }
            if let active = walletManager.inventory.activeKeyset {
                ActiveRecoveryIdentityCard(keyset: active)
                recoveryStatus(active)
            } else if walletManager.isRefreshing {
                ProgressView("Checking the active identity package…")
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .controlSurface()
            } else {
                emptyState
            }
            storedIdentities
            recoveryPackageDetails
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
                message: Text(
                    "QuilNode will create a verified rollback snapshot, stop only the node, replace the complete identity pair, let the official .25 node migrate it if needed, and validate startup. The previous identity is restored automatically if validation fails. Stores are preserved."
                ),
                primaryButton: .default(Text("Switch & verify")) {
                    Task { await walletManager.activate(id: keyset.id, name: keyset.name) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SELF-CUSTODY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.accent)
                Text("Identity Recovery")
                    .font(
                        .system(
                            size: 28 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign))
                Text(
                    "Back up, import, and switch complete node identities without exposing private key bytes to the interface."
                )
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
            Button {
                Task { await walletManager.refresh() }
            } label: {
                if walletManager.isRefreshing {
                    ProgressView().controlSize(.small)
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
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(walletManager.isWorking)
            .accessibilityLabel("Add node identity")
        }
    }

    @ViewBuilder
    private func serviceNotice(_ detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            DashboardCircleIcon(
                systemImage: walletManager.requiresServiceAuthorization
                    ? "lock.rotation" : "exclamationmark.triangle.fill",
                tint: theme.colors.warning,
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    walletManager.requiresServiceAuthorization
                        ? "Secure service update required"
                        : "Recovery status unavailable"
                )
                .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            if walletManager.requiresServiceAuthorization {
                Button("Review & authorize") {
                    Task { await walletManager.authorizeWalletService() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Try again") { Task { await walletManager.refresh() } }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .controlSurface(tint: theme.colors.warning)
        .disabled(walletManager.isWorking)
        .accessibilityElement(children: .contain)
    }

    private func resultNotice(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.colors.success)
            Text(message).font(.caption).textSelection(.enabled)
            Spacer()
        }
        .padding(12)
        .controlSurface(tint: theme.colors.success)
        .accessibilityLabel("Identity Recovery status: \(message)")
    }

    private func recoveryStatus(_ active: ManagedKeyset) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recovery copies").font(.headline)
                    Text("A local rollback snapshot and a separate encrypted copy protect against different failures.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Button("Back up now") {
                    Task { await walletManager.exportRecovery(for: active) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(walletManager.isWorking)
                .accessibilityLabel("Back up active identity now")
            }

            HStack(spacing: 12) {
                RecoveryCopyState(
                    title: "On this Mac",
                    value: active.automaticRecoveryCopies > 0
                        ? "\(active.automaticRecoveryCopies) verified snapshot\(active.automaticRecoveryCopies == 1 ? "" : "s")"
                        : "No verified snapshot",
                    detail: "Used automatically for rollback",
                    systemImage: active.automaticRecoveryCopies > 0
                        ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                    tint: active.automaticRecoveryCopies > 0 ? theme.colors.success : theme.colors.warning,
                    privacyField: .recoveryMetadata
                )
                RecoveryCopyState(
                    title: "Separate storage",
                    value: active.lastExternalBackupAt.map {
                        "Verified \($0.formatted(date: .abbreviated, time: .shortened))"
                    } ?? "Backup recommended",
                    detail: "Use an encrypted drive or vault",
                    systemImage: active.lastExternalBackupAt == nil
                        ? "externaldrive.badge.exclamationmark"
                        : "externaldrive.badge.checkmark",
                    tint: active.lastExternalBackupAt == nil ? theme.colors.warning : theme.colors.success,
                    privacyField: active.lastExternalBackupAt != nil ? .localTimestamp : nil
                )
            }
        }
        .padding(16)
        .controlSurface(tint: active.lastExternalBackupAt == nil ? theme.colors.warning : theme.colors.success)
    }

    private var storedIdentities: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stored identities").font(.headline)
                    Text("Only one identity can be active on this node at a time.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                PrivacyProtectedText(
                    value: String(walletManager.inventory.keysets.count),
                    field: .recoveryMetadata,
                    mask: .compact
                )
                .font(.caption2.bold().monospacedDigit())
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(theme.colors.surfaceElevated, in: Capsule())
                Spacer()
            }
            ForEach(walletManager.inventory.keysets) { keyset in
                IdentityLibraryRow(
                    keyset: keyset,
                    onActivate: { pendingActivation = keyset },
                    onExport: { Task { await walletManager.exportRecovery(for: keyset) } }
                )
            }
        }
        .padding(16)
        .controlSurface()
    }

    private var recoveryPackageDetails: some View {
        VStack(alignment: .leading, spacing: 11) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    RecoveryExplanation(
                        title: "Seniority root",
                        text:
                            "The legacy Ed448 peer identity anchors seniority and remains part of the complete package after .25 migration."
                    )
                    RecoveryExplanation(
                        title: "Current identity keys",
                        text:
                            "Proving, consensus, account, device, and routing material remains encrypted in the node key store."
                    )
                    RecoveryExplanation(
                        title: "Always back up the pair",
                        text:
                            "config.yml and keys.yml form one recovery unit. A one-file copy is intentionally never offered."
                    )
                }
                .padding(.top, 10)
            } label: {
                Label("What a complete recovery package contains", systemImage: "key.viewfinder")
                    .font(.headline)
            }
        }
        .padding(16)
        .controlSurface(tint: theme.colors.info)
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 38))
                .foregroundStyle(theme.colors.accent)
            Text("No complete node identity found").font(.title3.bold())
            Text("Create a fresh identity or import the folder containing the complete config.yml and keys.yml pair.")
                .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
            HStack {
                Button("Create identity") { showingCreate = true }.buttonStyle(.borderedProminent)
                Button("Import package") { walletManager.chooseImportFolder() }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .controlSurface()
    }
}
