import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct WalletOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager

    @State private var selection: IdentityOnboardingChoice?
    @State private var createName = "My Quilibrium identity"

    private var activeIdentity: ManagedKeyset? {
        walletManager.inventory.activeKeyset
    }

    var body: some View {
        OnboardingShell(
            stage: .identity,
            secondaryActionTitle: activeIdentity == nil ? nil : "Do this later",
            secondaryAction: deferOnboarding
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    choiceCards
                    operationState
                    OnboardingTrustStrip(items: trustItems)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
        } footer: {
            HStack(spacing: 16) {
                Text(footerGuidance)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                primaryAction
            }
        }
        .sheet(item: $walletManager.pendingImport, onDismiss: walletManager.discardPendingImport) { pending in
            ImportKeysetSheet(importItem: pending)
                .environmentObject(walletManager)
                .quilThemed(theme)
        }
        .onAppear(perform: chooseSafeDefaultIfNeeded)
        .onChange(of: activeIdentity?.id) { _, _ in chooseSafeDefaultIfNeeded() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            OnboardingSectionLabel(text: "Identity decision")
            Text("How should this Mac use a node identity?")
                .font(
                    .system(
                        size: 24 * theme.typography.scale,
                        weight: .bold,
                        design: theme.typography.displayDesign
                    ))
            Text(
                activeIdentity == nil
                    ? "No active identity was detected. Import a complete keyset or create a new local identity."
                    : "An active identity was detected. Keep and protect it, import another complete keyset, or create a new identity."
            )
            .font(.subheadline)
            .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private var choiceCards: some View {
        VStack(spacing: 8) {
            if let activeIdentity {
                OnboardingChoiceCard(
                    title: IdentityOnboardingChoice.keep.title,
                    detail: IdentityOnboardingChoice.keep.detail,
                    systemImage: IdentityOnboardingChoice.keep.systemImage,
                    isSelected: selection == .keep,
                    badge: "Recommended",
                    select: { selection = .keep }
                ) {
                    KeepIdentityDetails(identity: activeIdentity)
                }
            }

            OnboardingChoiceCard(
                title: IdentityOnboardingChoice.importKeyset.title,
                detail: IdentityOnboardingChoice.importKeyset.detail,
                systemImage: IdentityOnboardingChoice.importKeyset.systemImage,
                isSelected: selection == .importKeyset,
                select: { selection = .importKeyset }
            ) {
                ImportIdentityDetails()
            }

            OnboardingChoiceCard(
                title: IdentityOnboardingChoice.create.title,
                detail: IdentityOnboardingChoice.create.detail,
                systemImage: IdentityOnboardingChoice.create.systemImage,
                isSelected: selection == .create,
                select: { selection = .create }
            ) {
                CreateIdentityDetails(name: $createName)
            }
        }
    }

    @ViewBuilder
    private var operationState: some View {
        if walletManager.isWorking {
            QuilLoadingIndicator(
                label: walletManager.operationTitle ?? "Securing identity",
                detail: "The local service is validating the requested transaction."
            )
            .padding(13)
            .controlSurface(tint: theme.colors.accent)
        }
        if let error = walletManager.error {
            VStack(alignment: .leading, spacing: 10) {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colors.danger)
                    .textSelection(.enabled)
                if walletManager.requiresServiceAuthorization {
                    Button("Review identity authorization") {
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
            .padding(13)
            .controlSurface(tint: theme.colors.danger)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let selection {
            Button {
                perform(selection)
            } label: {
                Label(selection.primaryActionTitle, systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(primaryActionDisabled)
        } else {
            Button("Choose an option") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(true)
        }
    }

    private var primaryActionDisabled: Bool {
        walletManager.isWorking
            || (selection == .create && createName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || (selection == .keep && activeIdentity == nil)
    }

    private var footerGuidance: String {
        switch selection {
        case .keep: "A verified recovery copy is created before QuilNode begins managing this identity."
        case .importKeyset: "You will choose a folder next; the GUI never opens its key files."
        case .create: "The verified local client generates the identity on this Mac."
        case nil: "Choose one path to continue. Nothing changes until you confirm it."
        }
    }

    private var trustItems: [OnboardingTrustStrip.Item] {
        [
            .init(
                systemImage: "eye.slash.fill",
                title: "GUI never reads key bytes",
                detail: "Only your intent and selected folder cross the interface boundary."
            ),
            .init(
                systemImage: "icloud.slash.fill",
                title: "Local-only workflow",
                detail: "No cloud service or explorer is required for identity management."
            ),
            .init(
                systemImage: "externaldrive.fill.badge.checkmark",
                title: "Stores are preserved",
                detail: "Identity transactions never delete or replace node stores."
            ),
        ]
    }

    private func chooseSafeDefaultIfNeeded() {
        guard selection == nil else { return }
        selection = IdentityOnboardingChoice.initialChoice(hasActiveIdentity: activeIdentity != nil)
    }

    private func deferOnboarding() {
        walletManager.dismissOnboarding()
        dismiss()
    }

    private func perform(_ choice: IdentityOnboardingChoice) {
        switch choice {
        case .keep:
            Task {
                if await walletManager.adoptActive() { dismiss() }
            }
        case .importKeyset:
            walletManager.chooseImportFolder()
        case .create:
            Task {
                if await walletManager.create(named: createName) { dismiss() }
            }
        }
    }
}
