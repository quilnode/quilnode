import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

/// Maps the complete privileged wire contract to narrow helper capabilities.
/// Socket transport and authentication stay in `PrivilegedServiceServer`;
/// this centralized switch makes every authorized action easy to audit.
extension QuilNodeHelper {
    static func routeServiceRequest(
        _ request: PrivilegedServiceRequest,
        configuration: ServiceConfiguration
    ) throws -> PrivilegedServiceResponse {
        switch request.action {
        case .capabilities:
            let verifierReady =
                (try? validateRootOwnedExecutable(
                    URL(fileURLWithPath: operatorVerifier), maximumBytes: 40_000_000
                )) != nil
            return PrivilegedServiceResponse(
                success: verifierReady,
                message: verifierReady
                    ? "capability-wallet-v2; signed-first-install-v3; durable-operations-v1; self-upgrade-v1; root-release-verification-v1; application-firewall-v1; managed-qclient-v1; local-prover-telemetry-v1; permanent-app-identity-v1; automatic-node-update-policy-v1"
                    : "The root-owned release verifier is missing; service repair is required.",
                nodePID: currentNodePID(),
                serviceBuild: verifierReady ? PrivilegedServiceProtocol.currentServiceBuild : nil
            )
        case .upgradeService:
            let message = try upgradeOperatorService(configuration: configuration)
            return PrivilegedServiceResponse(success: true, message: message, nodePID: currentNodePID())
        case .status:
            return PrivilegedServiceResponse(
                success: true,
                message: "Passwordless service is ready; node runtime is isolated as _quilnode.",
                nodePID: currentNodePID()
            )
        case .nodeInfo:
            try requireIdleOperation("node inspection is paused while an update is activating")
            try validateLaunchDaemonPlist()
            return PrivilegedServiceResponse(
                success: true,
                message: "Local node identity read completed.",
                nodePID: currentNodePID(),
                nodeInfoOutput: try runNodeTool(["--node-info"], timeout: 15),
                peerInfoOutput: try runNodeTool(["--peer-info"], timeout: 10)
            )
        case .metrics:
            try requireIdleOperation("metrics are paused while an update is activating")
            try validateLaunchDaemonPlist()
            let metrics = try runNodeTool(
                ["--signature-check=\(currentSignatureCheck())", "--metrics"],
                timeout: 8
            )
            return PrivilegedServiceResponse(
                success: true,
                message: "Local node metrics read completed.",
                nodePID: currentNodePID(),
                metricsOutput: metrics
            )
        case .balance:
            try requireIdleOperation("balance checks are paused while an update is activating")
            try validateLaunchDaemonPlist()
            return PrivilegedServiceResponse(
                success: true,
                message: "Local QUIL wallet balance read completed.",
                nodePID: currentNodePID(),
                balanceOutput: try runQClientBalance(timeout: 45)
            )
        case .proverTelemetry:
            try requireIdleOperation("prover telemetry is paused while an update is activating")
            try validateLaunchDaemonPlist()
            return PrivilegedServiceResponse(
                success: true,
                message: "Local prover and shard telemetry read completed.",
                nodePID: currentNodePID(),
                qclientOutput: try runQClientProverTelemetry(timeout: 15)
            )
        case .qclientStatus:
            let status = inspectManagedQClient()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return PrivilegedServiceResponse(
                success: true,
                message: status.detail,
                nodePID: currentNodePID(),
                qclientOutput: String(decoding: try encoder.encode(status), as: UTF8.self)
            )
        case .qclientInstall:
            let path = try requiredManifestPath(from: request)
            if try qclientInstallRequiresAuthorization(manifestPath: path) {
                throw HelperFailure.authorizationRequired(
                    "Installing a source-built qclient requires explicit macOS administrator approval because the candidate is not covered by the official release-signing quorum."
                )
            }
            return operationResponse(
                try serviceOperations.begin(
                    action: PrivilegedServiceAction.qclientInstall.rawValue,
                    idempotencyKey: try qclientInstallOperationKey(manifestPath: path)
                ) { report in
                    report(.waitingForExclusiveAccess, "Waiting for exclusive installer access.")
                    try withMutationLock {
                        try installQClient(manifestPath: path, progress: report)
                    }
                    return "Matching qclient installed and independently re-verified."
                }
            )
        case .nodeUpdatePolicyStatus:
            let policy = try loadAutomaticNodeUpdatePolicy()
            return PrivilegedServiceResponse(
                success: true,
                message: "Automatic node-update authorization is \(policy.rawValue).",
                nodePID: currentNodePID(),
                nodeUpdatePolicy: policy
            )
        case .nodeUpdatePolicyConfigure:
            guard let policy = request.nodeUpdatePolicy else { throw HelperFailure.usage }
            try withMutationLock { try configureAutomaticNodeUpdatePolicy(policy) }
            return PrivilegedServiceResponse(
                success: true,
                message: "Automatic node-update authorization is \(policy.rawValue).",
                nodePID: currentNodePID(),
                nodeUpdatePolicy: policy
            )
        case .walletInventory:
            try requireIdleOperation(
                "wallet inspection is paused while another privileged operation is running"
            )
            return PrivilegedServiceResponse(
                success: true,
                message: "Local identity packages inspected without exposing private key material.",
                nodePID: currentNodePID(),
                walletOutput: try encodeWalletPayload(walletInventory())
            )
        case .walletInspect:
            try requireIdleOperation(
                "keyset inspection is paused while another privileged operation is running"
            )
            let manifest = try readWalletManifest(
                requiredManifestPath(from: request),
                configuration: configuration
            )
            guard let selected = manifest.selectedDirectory else {
                throw HelperFailure.invalidManifest("the selected keyset directory is missing")
            }
            let directory = try validateOperatorSelectedDirectory(
                selected,
                configuration: configuration,
                purpose: .keysetSource
            )
            return PrivilegedServiceResponse(
                success: true,
                message: "Selected keyset inspected locally.",
                walletOutput: try encodeWalletPayload(inspectKeyset(directory))
            )
        case .walletTransact:
            _ = try requiredManifestPath(from: request)
            throw HelperFailure.authorizationRequired(
                "Identity creation, import, activation, and recovery export require explicit macOS administrator approval so a compromised interface cannot silently copy or replace key material."
            )
        case .firewallStatus:
            let status = try inspectFirewall()
            return try firewallResponse(status)
        case .firewallConfigure:
            let status = try withMutationLock { try configureFirewall() }
            return try firewallResponse(status)
        case .start:
            return try lifecycleResponse(.start)
        case .stop:
            return try lifecycleResponse(.stop)
        case .restart:
            return try lifecycleResponse(.restart)
        case .activate:
            let path = try requiredManifestPath(from: request)
            try validateLaunchDaemonPlist()
            if try nodeActivationRequiresAuthorization(manifestPath: path) {
                throw HelperFailure.authorizationRequired(
                    "Installing a source-built node requires explicit macOS administrator approval because it is not covered by the official release-signing quorum."
                )
            }
            return operationResponse(
                try serviceOperations.begin(
                    action: PrivilegedServiceAction.activate.rawValue,
                    idempotencyKey: URL(fileURLWithPath: path).standardizedFileURL.path
                ) { report in
                    report(.waitingForExclusiveAccess, "Waiting for exclusive installer access.")
                    try withMutationLock { try activate(manifestPath: path, progress: report) }
                    return "Update installed; startup and local health checks passed."
                }
            )
        case .install:
            let path = try requiredManifestPath(from: request)
            return operationResponse(
                try serviceOperations.begin(
                    action: PrivilegedServiceAction.install.rawValue,
                    idempotencyKey: URL(fileURLWithPath: path).standardizedFileURL.path
                ) { report in
                    report(.waitingForExclusiveAccess, "Waiting for exclusive installer access.")
                    try withMutationLock { try freshInstall(manifestPath: path, progress: report) }
                    return "Signed Quilibrium node installed; launchd startup and local health checks passed."
                }
            )
        case .rollback:
            try validateLaunchDaemonPlist()
            return operationResponse(
                try serviceOperations.begin(
                    action: PrivilegedServiceAction.rollback.rawValue,
                    idempotencyKey: nil
                ) { _ in
                    try withMutationLock { try rollback() }
                    return "Rollback completed; startup checks passed."
                }
            )
        case .operationStatus:
            guard let operationID = request.operationID else { throw HelperFailure.usage }
            return operationResponse(try serviceOperations.record(id: operationID))
        }
    }

    private static func requiredManifestPath(from request: PrivilegedServiceRequest) throws -> String {
        guard let path = request.manifestPath else { throw HelperFailure.usage }
        return path
    }

    private static func requireIdleOperation(_ message: String) throws {
        guard !serviceOperations.isRunning else {
            throw HelperFailure.service(message)
        }
    }

    private static func operationResponse(_ operation: ServiceOperationRecord) -> PrivilegedServiceResponse {
        PrivilegedServiceResponse(
            success: operation.state != .failed,
            message: operation.message,
            nodePID: currentNodePID(),
            operationID: operation.id,
            operationState: operation.state.rawValue,
            operationStage: operation.stage
        )
    }

    private static func firewallResponse(_ status: FirewallStatusPayload) throws -> PrivilegedServiceResponse {
        PrivilegedServiceResponse(
            success: true,
            message: firewallSummary(status),
            nodePID: currentNodePID(),
            firewallOutput: try encodeFirewallPayload(status)
        )
    }

    private static func lifecycleResponse(_ action: HelperAction) throws -> PrivilegedServiceResponse {
        let label: String
        switch action {
        case .start: label = "start"
        case .stop: label = "stop"
        case .restart: label = "restart"
        default: throw HelperFailure.usage
        }
        try validateLaunchDaemonPlist()
        try withMutationLock { try performLifecycle(action) }
        return PrivilegedServiceResponse(
            success: true,
            message: "Quilibrium node \(label) request completed.",
            nodePID: action == .stop ? nil : currentNodePID()
        )
    }
}
