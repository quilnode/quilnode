import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension PrivilegedServiceClient {
    public static func request(
        _ action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        timeout: TimeInterval = 110
    ) -> (output: String, exitCode: Int32) {
        let result = response(action, manifestPath: manifestPath, timeout: timeout)
        return (result.response?.message ?? result.error, result.exitCode)
    }

    /// Synchronizes the narrow root-owned authorization used by unattended
    /// node updates. An existing service upgrades itself from the same signed
    /// app certificate before accepting the new policy.
    public static func configureAutomaticNodeUpdatePolicy(
        _ policy: AutomaticNodeUpdatePolicy,
        timeout: TimeInterval = 20
    ) -> (policy: AutomaticNodeUpdatePolicy?, error: String?) {
        let requiredBuild = PrivilegedServiceProtocol.currentServiceBuild
        if (installedServiceBuild(timeout: 5) ?? 0) < requiredBuild {
            let upgrade = request(.upgradeService, timeout: 60)
            guard upgrade.exitCode == 0 else {
                return (nil, upgrade.output)
            }

            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if (installedServiceBuild(timeout: 2) ?? 0) >= requiredBuild {
                    break
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }

        guard (installedServiceBuild(timeout: 5) ?? 0) >= requiredBuild else {
            return (nil, "The secure local service did not finish its passwordless upgrade.")
        }
        let result = response(
            .nodeUpdatePolicyConfigure,
            nodeUpdatePolicy: policy,
            timeout: timeout
        )
        guard result.exitCode == 0, result.response?.nodeUpdatePolicy == policy else {
            return (nil, result.response?.message ?? result.error)
        }
        return (policy, nil)
    }

    public static func readAutomaticNodeUpdatePolicy(
        timeout: TimeInterval = 8
    ) -> (policy: AutomaticNodeUpdatePolicy?, error: String?) {
        let result = response(.nodeUpdatePolicyStatus, timeout: timeout)
        guard result.exitCode == 0 else {
            return (nil, result.response?.message ?? result.error)
        }
        return (result.response?.nodeUpdatePolicy, nil)
    }

    /// Starts a daemon-owned privileged operation and follows its durable
    /// status. Older synchronous service versions remain compatible because
    /// they return a final response without an operation identifier.
    public static func requestOperation(
        _ action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        timeout: TimeInterval = 420
    ) -> (output: String, exitCode: Int32) {
        let initial = response(action, manifestPath: manifestPath, timeout: timeout)
        guard initial.exitCode == 0, let accepted = initial.response else {
            return (initial.response?.message ?? initial.error, initial.exitCode)
        }
        guard let operationID = accepted.operationID else {
            return (accepted.message, 0)
        }

        let deadline = Date().addingTimeInterval(timeout)
        var lastMessage = accepted.message
        while Date() < deadline {
            switch OperationState(rawValue: accepted.operationState ?? "") {
            case .succeeded:
                return (accepted.message, 0)
            case .failed:
                return (accepted.message, 1)
            case .running, nil:
                break
            }

            Thread.sleep(forTimeInterval: 1)
            let polled = response(
                .operationStatus,
                operationID: operationID,
                timeout: min(20, max(2, deadline.timeIntervalSinceNow))
            )
            if let status = polled.response {
                lastMessage = status.message
                switch OperationState(rawValue: status.operationState ?? "") {
                case .succeeded: return (status.message, 0)
                case .failed: return (status.message, 1)
                case .running, nil: continue
                }
            }
        }
        return (
            "\(lastMessage) The privileged operation is still owned by the service and can be checked again safely.", 76
        )
    }

    private enum OperationState: String {
        case running, succeeded, failed
    }
}
