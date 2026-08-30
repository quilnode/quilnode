import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
final class ReleaseChecker: ObservableObject {
    enum State: Equatable {
        case notChecked
        case checking
        case available(UpdateCenterSnapshot)
        case failed(String)
    }

    enum Operation: Equatable {
        case idle
        case downloading(String)
        case building(branch: String, commit: String)
        case awaitingAuthorization
        case activating
    }

    enum CheckOrigin: Equatable {
        case user
        case automatic
    }

    enum AutomaticCandidate {
        case signed(SignedReleaseInfo)
        case approvedDevelopment(ApprovedDevelopmentReleaseInfo)
        case rawDevelopment(GitBranchHead)
    }

    @Published var state: State = .notChecked
    @Published var operation: Operation = .idle
    @Published var releaseCheckProgress: ReleaseCheckProgress?
    @Published var lastCheckDuration: TimeInterval?
    @Published var lastError: String?
    @Published var lastMessage: String?
    @Published var progress: NodeUpdateProgress?
    @Published var history: [NodeUpdateEvent] = []
    @Published var nextAutomaticCheck: Date?
    @Published var nextSignalCheck: Date?
    @Published var lastSignalCheck: Date?
    @Published var signalCheckError: String?
    @Published var protocolMilestones: [ProtocolMilestone] = []
    @Published var protocolMilestoneError: String?
    @Published var nextProtocolCheck: Date?
    @Published var policy: NodeUpdatePolicy
    @Published var stagedUpdate: StagedNodeUpdate?

    let defaults = UserDefaults.standard
    let checkInterval = UpdateDiscoveryPolicy.fullReconciliationInterval
    let protocolCheckInterval: TimeInterval = 30 * 60
    let phaseTimingKey = "node-update-phase-timings-v1"
    let checkDurationKey = "node-update-check-duration-v1"
    let automaticAttemptKey = "node-update-last-automatic-attempt-v1"
    var automationTask: Task<Void, Never>?
    var signalTask: Task<Void, Never>?
    var signalCheckTask: Task<Void, Never>?
    var signalGeneration = UUID()
    var protocolTask: Task<Void, Never>?
    var protocolRefreshTask: Task<Void, Never>?
    var checkTask: Task<Void, Never>?
    var checkGeneration = UUID()
    var operationTask: Task<Void, Never>?
    var operationJournal: UpdateOperationJournal?
    var shouldCheckAfterOperation = false
    var automaticCheckPending = false
    var signalFailureCount = 0
    var automaticReconciliationPending = false
    var activeAutomaticCandidateID: String?
    var started = false
    weak var monitor: NodeMonitor?
    weak var services: NodeServices?

    let releaseEndpoint = URL(string: "https://releases.quilibrium.com/release")!
    let qclientReleaseEndpoint = URL(string: "https://releases.quilibrium.com/qclient-release")!
    let releaseBase = URL(string: "https://releases.quilibrium.com/")!
    let repositoryURL = "https://github.com/QuilibriumNetwork/monorepo.git"

    init() {
        policy =
            defaults.string(forKey: "node-update-policy")
            .flatMap(NodeUpdatePolicy.init(rawValue:)) ?? .manual
        loadHistory()
        loadProtocolMilestones()
        recoverOperationJournal()
        let savedCheckDuration = defaults.double(forKey: checkDurationKey)
        lastCheckDuration = savedCheckDuration > 0 ? savedCheckDuration : nil
    }

    deinit {
        automationTask?.cancel()
        signalTask?.cancel()
        signalCheckTask?.cancel()
        protocolTask?.cancel()
        protocolRefreshTask?.cancel()
        checkTask?.cancel()
        operationTask?.cancel()
    }

    var isChecking: Bool { checkTask != nil || state == .checking }
    var isInstalling: Bool { operationTask != nil || operation != .idle }
    var isWorking: Bool { isChecking || isInstalling }
    var canRollback: Bool {
        FileManager.default.fileExists(atPath: "/opt/quilibrium/node/.quilnode-rollback.json")
    }

    func start(monitor: NodeMonitor, services: NodeServices? = nil) {
        guard !started else { return }
        started = true
        self.monitor = monitor
        self.services = services
        let lastCheck = defaults.object(forKey: automaticAttemptKey) as? Date
        let automaticCheckIsDue =
            policy != .manual
            && UpdateDiscoveryPolicy.shouldRefresh(
                lastCheckedAt: lastCheck,
                freshnessInterval: checkInterval
            )
        rescheduleAutomaticChecks(runImmediately: automaticCheckIsDue)
        scheduleProtocolChecks()
    }

    func setPolicy(_ newPolicy: NodeUpdatePolicy, updateNow: Bool = false) {
        policy = newPolicy
        defaults.set(newPolicy.rawValue, forKey: "node-update-policy")
        if newPolicy == .manual {
            rescheduleAutomaticChecks(runImmediately: false)
            return
        }

        // "For later" establishes the six-hour schedule from this decision.
        // "Update now" is explicit permission to check and install immediately.
        // Keeping this timestamp separate from read-only release refreshes means
        // opening Update Center can never postpone or trigger automation.
        defaults.set(Date(), forKey: automaticAttemptKey)
        rescheduleAutomaticChecks(runImmediately: updateNow)
    }

    func dismissOperationResult() {
        guard progress?.status != .running, stagedUpdate == nil else { return }
        progress = nil
        lastError = nil
        lastMessage = nil
        removeTerminalOperationJournal()
    }

    /// Public requests own their tasks here, at app scope. Views only express
    /// intent, so navigation and window destruction cannot cancel an update.
    func requestCheck() {
        beginCheck(origin: .user)
    }

    /// Runs the selected automatic policy immediately. Unlike a read-only
    /// refresh, a newer eligible candidate continues into build and install.
    func requestAutomaticCheck() {
        guard policy != .manual else { return }
        beginCheck(origin: .automatic)
    }

    /// Navigation uses cached release data when it is still fresh. Explicit
    /// button presses continue to call `requestCheck()` and always refresh.
    func requestCheckIfStale(now: Date = Date()) {
        let checkedAt: Date? =
            if case let .available(snapshot) = state {
                snapshot.checkedAt
            } else {
                nil
            }
        guard UpdateDiscoveryPolicy.shouldRefresh(lastCheckedAt: checkedAt, now: now) else { return }
        beginCheck(origin: .user)
    }

    func cancelCheck() {
        guard checkTask != nil else { return }
        checkTask?.cancel()
    }

    func requestInstallSigned() {
        guard stagedUpdate == nil, case let .available(snapshot) = state else { return }
        clearAutomaticFailureSuppression()
        beginOperation { [weak self] in
            await self?.installSigned(snapshot.signed)
        }
    }

    func requestInstallQClient() {
        guard stagedUpdate == nil,
            case let .available(snapshot) = state,
            snapshot.installed.build.kind == .signed,
            let release = snapshot.qclient.available
        else { return }
        beginOperation { [weak self] in
            await self?.installQClient(release)
        }
    }

    func requestInstallApprovedDevelopment() {
        guard stagedUpdate == nil,
            case let .available(snapshot) = state,
            let approved = snapshot.source.approvedDevelopment
        else { return }
        clearAutomaticFailureSuppression()
        beginOperation { [weak self] in
            await self?.installSource(
                approved.head,
                channel: "approved-dev",
                displayVersion: approved.version
            )
        }
    }

    func requestInstallBleedingEdge() {
        guard stagedUpdate == nil, case let .available(snapshot) = state else { return }
        clearAutomaticFailureSuppression()
        beginOperation { [weak self] in
            await self?.installSource(
                snapshot.source.newestAnyBranch,
                channel: "raw-dev",
                displayVersion: nil
            )
        }
    }

    func requestResumeStagedUpdate() {
        guard let stagedUpdate else { return }
        beginOperation { [weak self] in
            do { try await self?.activate(manifestURL: stagedUpdate.manifestURL) } catch {
                self?.handleOperationFailure(error, channel: stagedUpdate.channel, version: stagedUpdate.version)
            }
        }
    }

    func requestRollback() {
        guard stagedUpdate == nil else { return }
        beginOperation { [weak self] in await self?.rollback() }
    }

}
