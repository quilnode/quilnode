import Combine
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
final class WalletManager: ObservableObject {
    @Published private(set) var inventory = WalletInventory()
    @Published private(set) var isRefreshing = false
    @Published private(set) var isWorking = false
    @Published private(set) var operationTitle: String?
    @Published private(set) var operationStartedAt: Date?
    @Published private(set) var message: String?
    @Published private(set) var error: String?
    @Published private(set) var requiresServiceAuthorization = false
    @Published var pendingImport: PendingKeysetImport?
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: "walletOnboardingCompleted") }
    }

    private let defaults: UserDefaults
    private let transactionStaging: WalletTransactionStaging
    private var started = false
    private var serviceRetryTask: Task<Void, Never>?
    private var automaticServiceRetryCount = 0

    init(
        defaults: UserDefaults = .standard,
        transactionStaging: WalletTransactionStaging = .init()
    ) {
        self.defaults = defaults
        self.transactionStaging = transactionStaging
        onboardingCompleted = defaults.bool(forKey: "walletOnboardingCompleted")
    }

    #if DEBUG
        /// Deterministic visual-QA fixture. Release builds cannot inject wallet
        /// state, and this path never starts the privileged service client.
        init(previewInventory: WalletInventory, defaults: UserDefaults) {
            self.defaults = defaults
            transactionStaging = .init()
            inventory = previewInventory
            onboardingCompleted = false
        }
    #endif

    func start() {
        guard !started else { return }
        started = true
        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await Task.detached(priority: .utility) {
            PrivilegedServiceClient.readWalletInventory()
        }.value
        if let inventory = result.inventory {
            self.inventory = inventory
            let boundaryReady = await Task.detached(priority: .utility) {
                return PrivilegedServiceClient.supportsCurrentSecurityBoundary(
                    timeout: 60
                )
            }.value
            requiresServiceAuthorization = !boundaryReady
            error =
                boundaryReady
                ? nil
                : "Identity Recovery needs a one-time secure service upgrade. The running node, identity, and stores will be preserved."
            if boundaryReady {
                automaticServiceRetryCount = 0
                serviceRetryTask?.cancel()
                serviceRetryTask = nil
            } else {
                scheduleServiceRecheck()
            }
        } else {
            let serviceError = result.error ?? "The secure identity service is unavailable."
            requiresServiceAuthorization = WalletServiceCompatibility.requiresUpgrade(for: serviceError)
            error =
                requiresServiceAuthorization
                ? "Identity Recovery needs a one-time secure service upgrade. Your node and keys will not be changed by the authorization itself."
                : serviceError
            if requiresServiceAuthorization { scheduleServiceRecheck() }
        }
    }

    /// Installs the code-signature-pinned service once. Read-only inventory and
    /// inspection then remain passwordless. Key-changing and key-exporting
    /// operations deliberately request fresh macOS user presence.
    func authorizeWalletService() async {
        guard !isWorking else { return }
        isWorking = true
        operationTitle = "Authorizing Identity Recovery"
        operationStartedAt = Date()
        error = nil
        defer {
            isWorking = false
            operationTitle = nil
            operationStartedAt = nil
        }
        let result = await Task.detached(priority: .userInitiated) {
            ReleaseChecker.authorizeServiceMigration(controllerUID: getuid())
        }.value
        if result.exitCode == 0 {
            requiresServiceAuthorization = false
            message = result.output.isEmpty ? "Secure Identity Recovery service authorized." : result.output
            try? await Task.sleep(for: .seconds(1))
            await refresh()
        } else if result.exitCode == -128 {
            message = "Administrator authorization was cancelled. The active node and keys were not changed."
        } else {
            error = result.output.isEmpty ? "Identity Recovery authorization failed." : result.output
        }
    }

    func chooseImportFolder() {
        guard let selected = WalletDirectoryPicker.chooseKeysetDirectory() else { return }

        do {
            let stage = try transactionStaging.makeDirectory()
            defer { transactionStaging.remove(stage) }
            let manifestURL = try transactionStaging.write(
                .init(
                    kind: .importKeyset,
                    displayName: selected.lastPathComponent,
                    selectedDirectory: selected.path,
                    confirmedBackupResponsibility: true
                ), in: stage)
            let serviceInspection = PrivilegedServiceClient.inspectKeyset(manifestPath: manifestURL.path)
            guard let inspection = serviceInspection.inspection else {
                let serviceError = serviceInspection.error ?? "The secure service could not inspect this keyset."
                requiresServiceAuthorization = WalletServiceCompatibility.requiresUpgrade(for: serviceError)
                throw WalletOperationError(
                    requiresServiceAuthorization
                        ? "Authorize Identity Recovery once before importing a keyset."
                        : serviceError)
            }
            pendingImport = PendingKeysetImport(
                selectedDirectory: selected,
                inspection: inspection,
                suggestedName: readableName(selected.lastPathComponent)
            )
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func importPending(named name: String, activateAfterImport: Bool) async -> PendingKeysetImportResult {
        guard let pendingImport else { return .failed }
        let keysetID = pendingImport.keysetID
        let success = await perform(
            title: "Importing identity",
            manifest: .init(
                kind: .importKeyset,
                keysetID: keysetID,
                displayName: name,
                selectedDirectory: pendingImport.selectedDirectory.path,
                confirmedBackupResponsibility: true
            )
        )
        guard success else { return .failed }

        self.pendingImport = nil
        onboardingCompleted = true
        guard activateAfterImport else { return .imported }
        return await activate(id: keysetID, name: name)
            ? .importedAndActivated
            : .importedActivationFailed(keysetID: keysetID)
    }

    @discardableResult
    func adoptActive(named name: String = "My seniority identity") async -> Bool {
        let success = await perform(
            title: "Protecting existing identity",
            manifest: .init(
                kind: .adoptActive,
                displayName: name,
                confirmedBackupResponsibility: true
            )
        )
        if success { onboardingCompleted = true }
        return success
    }

    @discardableResult
    func create(named name: String) async -> Bool {
        let success = await perform(
            title: "Creating identity",
            manifest: .init(
                kind: .create,
                keysetID: UUID(),
                displayName: name,
                confirmedBackupResponsibility: true
            )
        )
        if success { onboardingCompleted = true }
        return success
    }

    @discardableResult
    func activate(id: UUID, name: String) async -> Bool {
        await perform(
            title: "Switching identity",
            manifest: .init(
                kind: .activate,
                keysetID: id,
                displayName: name,
                confirmedBackupResponsibility: true
            )
        )
    }

    func exportRecovery(for keyset: ManagedKeyset) async {
        guard let parent = WalletDirectoryPicker.chooseRecoveryDirectory() else {
            message = "Recovery export cancelled. No key material was copied."
            return
        }

        let success = await perform(
            title: "Preparing recovery export",
            manifest: .init(
                kind: .exportRecovery,
                keysetID: keyset.id,
                displayName: keyset.name,
                exportParentDirectory: parent.path,
                confirmedBackupResponsibility: true
            )
        )
        if success { WalletDirectoryPicker.reveal(parent) }
    }

    func dismissOnboarding() {
        onboardingCompleted = true
    }

    func discardPendingImport() {
        pendingImport = nil
    }

    private func perform(
        title: String,
        manifest: WalletTransactionManifest,
        stage suppliedStage: URL? = nil
    ) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        operationTitle = title
        operationStartedAt = Date()
        error = nil
        message = nil
        defer {
            isWorking = false
            operationTitle = nil
            operationStartedAt = nil
        }
        let ownsStage = suppliedStage == nil
        var ownedStage: URL?
        do {
            let stage = try suppliedStage ?? transactionStaging.makeDirectory()
            if ownsStage { ownedStage = stage }
            defer {
                if let ownedStage { transactionStaging.remove(ownedStage) }
            }
            let manifestURL = try transactionStaging.write(manifest, in: stage)
            let result = await Task.detached(priority: .userInitiated) {
                ReleaseChecker.runAuthorizedHelper(
                    arguments: ["wallet-transact", manifestURL.path],
                    durableOperation: true
                )
            }.value
            guard result.exitCode == 0 else {
                requiresServiceAuthorization = WalletServiceCompatibility.requiresUpgrade(for: result.output)
                throw WalletOperationError(
                    result.exitCode == -128
                        ? "Administrator authorization was cancelled. No identity material was changed."
                        : (requiresServiceAuthorization
                            ? "Authorize Identity Recovery once, then retry this operation."
                            : result.output))
            }
            message = result.output
            await refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func readableName(_ source: String) -> String {
        let value = source.replacingOccurrences(of: #"[_-]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Imported identity" : String(value.prefix(48))
    }

    /// App and service updates are coordinated independently, so the first
    /// inventory read can race a passwordless service self-update. A bounded
    /// recheck clears that transient state without prompting or busy polling.
    private func scheduleServiceRecheck() {
        guard serviceRetryTask == nil, automaticServiceRetryCount < 4 else { return }
        automaticServiceRetryCount += 1
        let delay = min(12, 2 * automaticServiceRetryCount)
        serviceRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.serviceRetryTask = nil
            await self.refresh()
        }
    }
}
