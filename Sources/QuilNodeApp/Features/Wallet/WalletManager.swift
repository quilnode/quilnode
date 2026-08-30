import AppKit
import Darwin
import Foundation
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct PendingKeysetImport: Identifiable {
    let id = UUID()
    /// A capability chosen by the operator. The GUI retains the URL only; it
    /// never opens, parses, hashes, copies, or displays either key file.
    let selectedDirectory: URL
    let inspection: KeysetInspection
    var suggestedName: String
}

@MainActor
final class WalletManager: ObservableObject {
    @Published private(set) var inventory = WalletInventory()
    @Published private(set) var isRefreshing = false
    @Published private(set) var isWorking = false
    @Published private(set) var operationTitle: String?
    @Published private(set) var message: String?
    @Published private(set) var error: String?
    @Published private(set) var requiresServiceAuthorization = false
    @Published var pendingImport: PendingKeysetImport?
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: "walletOnboardingCompleted") }
    }

    private let fileManager = FileManager.default
    private let defaults: UserDefaults
    private var started = false
    private var serviceRetryTask: Task<Void, Never>?
    private var automaticServiceRetryCount = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingCompleted = defaults.bool(forKey: "walletOnboardingCompleted")
    }

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
            requiresServiceAuthorization = Self.isCompatibilityError(serviceError)
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
        error = nil
        defer {
            isWorking = false
            operationTitle = nil
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
        let panel = NSOpenPanel()
        panel.title = "Choose a Quilibrium keyset"
        panel.message =
            "Select the folder containing config.yml and keys.yml. The QuilNode interface never opens key files; the signed local service validates this selected folder on your Mac."
        panel.prompt = "Inspect Keyset"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        guard panel.runModal() == .OK, let selected = panel.url else { return }

        do {
            let stage = try makeStageDirectory()
            defer { try? fileManager.removeItem(at: stage) }
            let manifestURL = try writeManifest(
                .init(
                    kind: .importKeyset,
                    displayName: selected.lastPathComponent,
                    selectedDirectory: selected.path,
                    confirmedBackupResponsibility: true
                ), in: stage)
            let serviceInspection = PrivilegedServiceClient.inspectKeyset(manifestPath: manifestURL.path)
            guard let inspection = serviceInspection.inspection else {
                let serviceError = serviceInspection.error ?? "The secure service could not inspect this keyset."
                requiresServiceAuthorization = Self.isCompatibilityError(serviceError)
                throw WalletUIError(
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

    func importPending(named name: String, activateAfterImport: Bool) async {
        guard let pendingImport else { return }
        let keysetID = UUID()
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
        if success {
            self.pendingImport = nil
            onboardingCompleted = true
            if activateAfterImport {
                _ = await activate(id: keysetID, name: name)
            }
        }
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
        let panel = NSOpenPanel()
        panel.title = "Choose encrypted backup storage"
        panel.message =
            "Choose an encrypted external drive, encrypted disk image, or password-protected vault. The signed local service writes and verifies the recovery package; the QuilNode interface never opens key files."
        panel.prompt = "Save Verified Recovery Copy"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let parent = panel.url else {
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
        if success { NSWorkspace.shared.open(parent) }
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
        error = nil
        message = nil
        defer {
            isWorking = false
            operationTitle = nil
        }
        let ownsStage = suppliedStage == nil
        var ownedStage: URL?
        do {
            let stage = try suppliedStage ?? makeStageDirectory()
            if ownsStage { ownedStage = stage }
            defer {
                if let ownedStage { try? fileManager.removeItem(at: ownedStage) }
            }
            let manifestURL = try writeManifest(manifest, in: stage)
            let result = await Task.detached(priority: .userInitiated) {
                ReleaseChecker.runAuthorizedHelper(
                    arguments: ["wallet-transact", manifestURL.path],
                    durableOperation: true
                )
            }.value
            guard result.exitCode == 0 else {
                requiresServiceAuthorization = Self.isCompatibilityError(result.output)
                throw WalletUIError(
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

    private func makeStageDirectory() throws -> URL {
        let support = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/QuilNode", isDirectory: true)
        try PrivateLocalFileSystem.ensureDirectory(at: support)
        let root = support.appendingPathComponent("WalletStaging", isDirectory: true)
        try PrivateLocalFileSystem.ensureDirectory(at: root)
        let stage = root.appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        try PrivateLocalFileSystem.createExclusiveDirectory(at: stage)
        return stage
    }

    private func writeManifest(_ manifest: WalletTransactionManifest, in stage: URL) throws -> URL {
        let url = stage.appendingPathComponent("wallet-transaction.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try PrivateLocalFileSystem.write(try encoder.encode(manifest), atomicallyTo: url)
        return url
    }

    private func readableName(_ source: String) -> String {
        let value = source.replacingOccurrences(of: #"[_-]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Imported identity" : String(value.prefix(48))
    }

    private static func isCompatibilityError(_ value: String) -> Bool {
        let text = value.lowercased()
        return text.contains("invalid passwordless service response")
            || text.contains("serviceaction")
            || text.contains("protocol is incompatible")
            || text.contains("passwordless service is not available")
            || text.contains("walletinventory")
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

private struct WalletUIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
