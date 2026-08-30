import Combine
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
final class NetworkReadinessCoordinator: ObservableObject {
    @Published private(set) var inspection = NetworkLocalInspection.empty
    @Published private(set) var gatewayRoute = GatewayRouteClassifier.assess(.empty)
    @Published private(set) var routerAccess = RouterAccessDiscovery.notChecked
    @Published private(set) var assessment = NetworkReadinessAssessment(
        state: .inspecting,
        title: "Inspecting this Mac",
        detail: "QuilNode is checking local network evidence."
    )
    @Published private(set) var isRefreshing = false
    @Published private(set) var firewall = ManagedFirewallStatus.unavailable
    @Published private(set) var firewallError: String?
    @Published private(set) var isConfiguringFirewall = false
    @Published private(set) var initialGuideCompleted: Bool
    @Published private(set) var initialGuideDeferredUntil: Date?
    @Published private(set) var activePortProfile: NetworkPortProfile
    @Published private(set) var portProfileError: String?

    private static let completionKey = "networkSetup.initialGuideCompleted.v1"
    private static let reminderKey = "networkSetup.remindLaterAt.v1"
    private static let portProfileKey = "networkSetup.activePortProfile.v1"
    private let defaults: UserDefaults
    private let inspector = NetworkLocalInspector()
    private let routerDiscoverer = RouterAccessDiscoverer()
    private var observation: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private var latestNode = NodeSnapshot.empty

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        initialGuideCompleted = defaults.bool(forKey: Self.completionKey)
        initialGuideDeferredUntil = defaults.object(forKey: Self.reminderKey) as? Date
        if let data = defaults.data(forKey: Self.portProfileKey),
            let profile = try? JSONDecoder().decode(NetworkPortProfile.self, from: data),
            profile.peerTransport != .tcpAndUDP
        {
            activePortProfile = profile
        } else {
            activePortProfile = .recommendedResidential
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var portPlan: NetworkPortPlan {
        .plan(for: activePortProfile, localWorkerCount: latestNode.localWorkerCount)
    }

    var routerURL: URL? {
        routerAccess.browserURL
    }

    var shouldPresentInitialGuide: Bool {
        guard !initialGuideCompleted else { return false }
        guard let deferredUntil = initialGuideDeferredUntil else { return true }
        return deferredUntil <= Date()
    }

    func start(monitor: NodeMonitor) {
        guard observation == nil else { return }
        observation = monitor.$snapshot
            .combineLatest(monitor.$observationPhase)
            .filter { _, phase in phase.hasDeterminedProcessState }
            .map(\.0)
            .sink { [weak self] snapshot in
                guard let self else { return }
                latestNode = snapshot
                assessment = NetworkReadinessEvaluator.evaluate(
                    node: snapshot,
                    inspection: inspection,
                    portPlan: portPlan
                )
            }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await refresh()
            }
        }
    }

    func refresh(forceRouterProbe: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let pid = latestNode.processID
        let expectedPlan = portPlan
        async let localInspection = Task.detached(priority: .utility) { [inspector] in
            inspector.inspect(processID: pid, portPlan: expectedPlan)
        }.value
        async let firewallInspection = Task.detached(priority: .utility) {
            PrivilegedServiceClient.readFirewallStatus()
        }.value
        let result = await localInspection
        let route = GatewayRouteClassifier.assess(result)
        if routerAccess.routeSignature != route.signature || forceRouterProbe {
            routerAccess = .checking(route: route)
        }
        let access = await routerDiscoverer.discover(route: route, force: forceRouterProbe)
        inspection = result
        gatewayRoute = route
        routerAccess = access
        assessment = NetworkReadinessEvaluator.evaluate(
            node: latestNode,
            inspection: result,
            portPlan: portPlan
        )
        let firewallResult = await firewallInspection
        if let status = firewallResult.status {
            firewall = status
            firewallError = nil
        } else {
            firewallError = firewallResult.error
        }
        isRefreshing = false
    }

    func validation(for profile: NetworkPortProfile) -> NetworkPortProfileValidation {
        NetworkPortPlan.plan(
            for: profile,
            localWorkerCount: latestNode.localWorkerCount
        ).validation(in: inspection)
    }

    @discardableResult
    func activatePortProfile(_ profile: NetworkPortProfile) -> Bool {
        let result = validation(for: profile)
        guard result.isReadyToActivate else {
            if let issue = result.issues.first {
                portProfileError = issue
            } else if let inactive = result.inactiveRequirements.first {
                portProfileError =
                    "\(inactive.title) is not listening with the selected \(inactive.transport.rawValue) profile. The active router plan was not changed."
            } else {
                portProfileError = "The custom listener profile could not be verified."
            }
            return false
        }

        activePortProfile = profile
        portProfileError = nil
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.portProfileKey)
        }
        assessment = NetworkReadinessEvaluator.evaluate(
            node: latestNode,
            inspection: inspection,
            portPlan: portPlan
        )
        return true
    }

    func clearPortProfileError() {
        portProfileError = nil
    }

    func configureFirewall() async {
        guard !isConfiguringFirewall else { return }
        isConfiguringFirewall = true
        firewallError = nil
        let result = await Task.detached(priority: .userInitiated) {
            PrivilegedServiceClient.configureFirewall()
        }.value
        if let status = result.status {
            firewall = status
        } else {
            firewallError = result.error ?? "macOS did not confirm the firewall change."
        }
        isConfiguringFirewall = false
        await refresh()
    }

    func markInitialGuideCompleted() {
        initialGuideCompleted = true
        initialGuideDeferredUntil = nil
        defaults.set(true, forKey: Self.completionKey)
        defaults.removeObject(forKey: Self.reminderKey)
    }

    func remindLater() {
        let deferredUntil = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        initialGuideDeferredUntil = deferredUntil
        defaults.set(deferredUntil, forKey: Self.reminderKey)
    }
}
