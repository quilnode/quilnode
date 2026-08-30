import AppKit
import Combine
import CryptoKit
import Foundation
import UserNotifications

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
@MainActor
final class NodeServices: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var notificationsAuthorized = false

    private var observation: AnyCancellable?
    private var historyStore: NodeHistoryStore?
    private var started = false
    private var previousSnapshot: NodeSnapshot?
    private var lastFrame: UInt64?
    private var lastFrameAdvanceAt = Date()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func start(monitor: NodeMonitor, history: NodeHistoryStore) async {
        guard !started else { return }
        started = true
        historyStore = history

        notificationsAuthorized = await requestNotificationAuthorization()
        if notificationsAuthorized {
            scheduleAlert(
                id: "alerts-enabled",
                title: "QuilNode alerts enabled",
                body:
                    "You will be notified about node health, protocol milestones, and automatic update results.",
                cooldown: 365 * 24 * 60 * 60
            )
        }
        observation = monitor.$snapshot
            .combineLatest(monitor.$observationPhase)
            .filter { _, phase in phase.hasLiveTelemetry }
            .map(\.0)
            .sink { [weak self] snapshot in
                self?.consume(snapshot)
            }

        if monitor.observationPhase.hasLiveTelemetry {
            consume(monitor.snapshot)
        }
    }

    func enableNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .denied {
            openNotificationSettings()
            return
        }

        notificationsAuthorized = await requestNotificationAuthorization()
        if !notificationsAuthorized {
            openNotificationSettings()
        }
    }

    func announceProtocolMilestone(_ milestone: ProtocolMilestone, currentFrame: UInt64) {
        guard milestone.targetFrame > currentFrame else { return }
        let remaining = milestone.targetFrame - currentFrame
        let readiness =
            switch milestone.installedSupport {
            case .included: "This node includes the executable gate."
            case .missing: "Update required: this node does not include the gate."
            case .unknown: "Installed support could not be proven yet."
            }
        scheduleAlert(
            id: "protocol-\(milestone.symbol)-\(milestone.targetFrame)",
            title: "Upcoming: \(milestone.title)",
            body:
                "Target frame \(milestone.targetFrame.formatted()) · \(remaining.formatted()) frames away. \(readiness)",
            cooldown: 365 * 24 * 60 * 60
        )
    }

    func announceAutomaticUpdateDetected(
        candidateID: String,
        channel: String,
        version: String
    ) {
        scheduleAlert(
            id: "update-detected-\(notificationDigest(candidateID))",
            title: "QuilNode update detected",
            body:
                "\(channel) \(version) is eligible under your automatic policy. Preparation is starting while the current node remains online.",
            cooldown: 365 * 24 * 60 * 60
        )
    }

    func announceAutomaticUpdateSucceeded(
        candidateID: String,
        version: String
    ) {
        scheduleAlert(
            id: "update-succeeded-\(notificationDigest(candidateID))",
            title: "Quilibrium node updated",
            body: "\(version) was installed and passed the local runtime health gate.",
            cooldown: 365 * 24 * 60 * 60
        )
    }

    func announceAutomaticUpdateFailed(
        candidateID: String,
        version: String
    ) {
        scheduleAlert(
            id: "update-failed-\(notificationDigest(candidateID))",
            title: "Automatic node update stopped",
            body:
                "\(version) did not complete. Open Update Center to review the retained evidence and verified runtime outcome.",
            cooldown: 6 * 60 * 60
        )
    }

    private func openNotificationSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.quilnode.app"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func consume(_ snapshot: NodeSnapshot) {
        let now = Date()
        historyStore?.record(snapshot)

        evaluateAlerts(snapshot, now: now)
        previousSnapshot = snapshot
    }

    private func evaluateAlerts(_ snapshot: NodeSnapshot, now: Date) {
        guard let previousSnapshot else {
            lastFrame = snapshot.frame
            lastFrameAdvanceAt = now
            return
        }

        if snapshot.frame != lastFrame {
            lastFrame = snapshot.frame
            lastFrameAdvanceAt = now
        }

        if previousSnapshot.isRunning && !snapshot.isRunning {
            scheduleAlert(
                id: "node-stopped",
                title: "Quilibrium node stopped",
                body: "The local node process is no longer running.",
                cooldown: 15 * 60
            )
        }

        if previousSnapshot.activeShards == 0 && snapshot.activeShards > 0 {
            scheduleAlert(
                id: "shards-active",
                title: "Quilibrium allocations are active",
                body: "The node is now serving active shard work.",
                cooldown: 60 * 60
            )
        }

        if previousSnapshot.pendingJoins == 0 && snapshot.pendingJoins > 0 {
            scheduleAlert(
                id: "joining-started",
                title: "Quilibrium allocations are joining",
                body: "The node is joining its assigned allocations.",
                cooldown: 60 * 60
            )
        }

        if previousSnapshot.pendingJoins > 0
            && snapshot.pendingJoins == 0
            && snapshot.activeShards == 0
        {
            scheduleAlert(
                id: "joining-ended",
                title: "Quilibrium joining state changed",
                body: "Pending joins reached zero. Open QuilNode to review the current state.",
                cooldown: 60 * 60
            )
        }

        if snapshot.isRunning
            && now.timeIntervalSince(lastFrameAdvanceAt) >= 10 * 60
        {
            let progress = ChainProgressEvaluator.evaluate(snapshot, now: now)
            if progress.state == .archiveRecovery {
                scheduleAlert(
                    id: "archive-recovery-waiting",
                    title: "Quilibrium network recovery in progress",
                    body:
                        "Archives are reachable at frame \(snapshot.frame), but shared state is still converging. Keep the node running; no restart is recommended.",
                    cooldown: 2 * 60 * 60
                )
            } else if progress.state == .localLag || progress.state == .localStall {
                scheduleAlert(
                    id: "frame-stalled",
                    title: "Quilibrium node needs a progress check",
                    body: "This node has not advanced while local evidence does not show a shared archive recovery.",
                    cooldown: 30 * 60
                )
            }
        }

    }

    private func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            let settings = await center.notificationSettings()
            UserDefaults.standard.set(
                settings.authorizationStatus.rawValue,
                forKey: "notification-authorization-status"
            )
            return granted
                && (settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional)
        } catch {
            UserDefaults.standard.set(
                error.localizedDescription,
                forKey: "notification-authorization-error"
            )
            return false
        }
    }

    private func notificationDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func scheduleAlert(
        id: String,
        title: String,
        body: String,
        cooldown: TimeInterval
    ) {
        guard notificationsAuthorized else { return }

        let defaultsKey = "local-alert-last-sent.\(id)"
        let lastSent = UserDefaults.standard.object(forKey: defaultsKey) as? Date
        if let lastSent, Date().timeIntervalSince(lastSent) < cooldown { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "quilnode.\(id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                UserDefaults.standard.set(Date(), forKey: defaultsKey)
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
