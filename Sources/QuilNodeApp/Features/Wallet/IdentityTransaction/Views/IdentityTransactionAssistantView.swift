import SwiftUI

struct IdentityTransactionAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager

    let context: IdentityTransactionContext
    var onCompleted: (() -> Void)?

    @State private var name: String
    @State private var disposition: IdentityImportDisposition = .activate
    @State private var didSubmit = false
    @State private var pendingImportedKeysetID: UUID?

    private let presentation: IdentityTransactionPresentation

    init(
        context: IdentityTransactionContext,
        initialDisposition: IdentityImportDisposition = .activate,
        onCompleted: (() -> Void)? = nil
    ) {
        self.context = context
        self.onCompleted = onCompleted
        presentation = .make(for: context)
        _name = State(initialValue: context.initialName)
        _disposition = State(initialValue: initialDisposition)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.62)

            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    IdentityTransactionPlanRail(stages: presentation.stages(for: disposition))
                        .padding(.horizontal, 12)

                    HStack(alignment: .top, spacing: 11) {
                        IdentityTransactionDossier(
                            presentation: presentation,
                            name: $name
                        )
                        .frame(maxWidth: .infinity)

                        IdentityTransactionBoundary(
                            changes: presentation.changes,
                            untouched: presentation.untouched
                        )
                        .frame(width: 286)
                    }

                    IdentityTransactionTimeline(moments: presentation.moments)

                    if presentation.supportsDisposition {
                        if pendingImportedKeysetID == nil {
                            IdentityDispositionPicker(selection: $disposition)
                        } else {
                            Label(
                                "The package and recovery copy are safe. The previous identity was restored; retry only the protected activation.",
                                systemImage: "checkmark.shield.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.success)
                            .padding(12)
                            .controlSurface(tint: theme.colors.success)
                        }
                    }

                    operationState
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }

            Divider().opacity(0.62)
            footer
        }
        .frame(width: 980, height: 730)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .foregroundStyle(theme.colors.primaryText)
        .interactiveDismissDisabled(walletManager.isWorking)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ApplicationBrandMark(size: 26, theme: theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.eyebrow.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.accent)
                Text("Identity transaction")
                    .font(.subheadline.bold())
            }
            Spacer()
            Label("Local only", systemImage: "lock.shield.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colors.success)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(theme.colors.surface.opacity(0.32))
    }

    @ViewBuilder
    private var operationState: some View {
        if walletManager.isWorking {
            if let startedAt = walletManager.operationStartedAt {
                OnboardingWaitPanel(
                    title: walletManager.operationTitle ?? "Protecting identity",
                    detail: OnboardingWaitPresentation.identityTransactionGuidance,
                    startedAt: startedAt
                )
            }
        } else if didSubmit, let error = walletManager.error {
            VStack(alignment: .leading, spacing: 8) {
                Label("Transaction did not complete", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.danger)
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .textSelection(.enabled)
                Text("The previous identity and node stores remain protected.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.success)
            }
            .padding(12)
            .controlSurface(tint: theme.colors.danger)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Cancel") { cancel() }
                .buttonStyle(.bordered)
                .disabled(walletManager.isWorking)

            Text(footerGuidance)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(2)

            Spacer(minLength: 12)

            Button {
                Task { await performTransaction() }
            } label: {
                if walletManager.isWorking {
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text("Working…")
                    }
                } else {
                    Label(primaryTitle, systemImage: presentation.primarySymbol)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(theme.colors.accent)
            .disabled(primaryDisabled)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 64)
    }

    private var primaryTitle: String {
        if pendingImportedKeysetID != nil { return "Retry protected activation" }
        guard presentation.kind == .importKeyset else { return presentation.primaryTitle }
        return disposition == .activate ? presentation.primaryTitle : "Add protected identity"
    }

    private var footerGuidance: String {
        switch presentation.kind {
        case .adopt:
            "No restart or identity switch is planned."
        case .create:
            "The node pauses only for activation and local health validation."
        case .importKeyset:
            if pendingImportedKeysetID != nil {
                "The import is complete; retrying cannot duplicate the managed package."
            } else {
                disposition == .activate
                    ? "Import creates recovery evidence before the protected switch."
                    : "The running identity remains unchanged."
            }
        case .activate:
            "Failure restores the previous complete pair automatically."
        }
    }

    private var primaryDisabled: Bool {
        walletManager.isWorking
            || (presentation.requiresEditableName
                && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func cancel() {
        if case .importKeyset = context {
            walletManager.discardPendingImport()
        }
        dismiss()
    }

    @MainActor
    private func performTransaction() async {
        didSubmit = true
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let succeeded: Bool

        switch context {
        case .adopt:
            succeeded = await walletManager.adoptActive(named: normalizedName)
        case .create:
            succeeded = await walletManager.create(named: normalizedName)
        case .importKeyset:
            if let pendingImportedKeysetID {
                succeeded = await walletManager.activate(id: pendingImportedKeysetID, name: normalizedName)
            } else {
                let result = await walletManager.importPending(
                    named: normalizedName,
                    activateAfterImport: disposition == .activate
                )
                switch result {
                case .failed:
                    succeeded = false
                case .imported, .importedAndActivated:
                    succeeded = true
                case .importedActivationFailed(let keysetID):
                    self.pendingImportedKeysetID = keysetID
                    succeeded = false
                }
            }
        case .activate(let keyset):
            succeeded = await walletManager.activate(id: keyset.id, name: keyset.name)
        }

        guard succeeded else { return }
        dismiss()
        DispatchQueue.main.async { onCompleted?() }
    }
}
