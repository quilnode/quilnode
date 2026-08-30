import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func serve() throws {
        // Builds 90–92 form the one-way bridge from the early local bundle identifier
        // to the permanent public identifier. The bridge keeps the same pinned
        // certificate and UID; it never broadens authorization to another
        // signer. A later authenticated app update collapses it to the permanent
        // requirement automatically.
        let configuration = try migrateLegacyControllerRequirementIfNeeded(
            try loadServiceConfiguration()
        )
        guard FileManager.default.fileExists(atPath: operatorBinary),
            getuid() == 0
        else { throw HelperFailure.service("the service is not installed securely") }

        signal(SIGPIPE, SIG_IGN)
        unlink(operatorSocket)
        let server = socket(AF_UNIX, SOCK_STREAM, 0)
        guard server >= 0 else { throw HelperFailure.service("socket creation failed") }
        defer {
            close(server)
            unlink(operatorSocket)
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let socketPathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard operatorSocket.utf8.count < socketPathCapacity else {
            throw HelperFailure.service("socket path is too long")
        }
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: socketPathCapacity) {
                _ = strlcpy($0, operatorSocket, socketPathCapacity)
            }
        }
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0,
            chown(operatorSocket, uid_t(configuration.controllerUID), gid_t(20)) == 0,
            chmod(operatorSocket, 0o600) == 0,
            listen(server, 8) == 0
        else { throw HelperFailure.service("unable to secure or listen on the local socket") }

        while true {
            let client = accept(server, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                throw HelperFailure.service("accept failed")
            }
            // Bound both concurrency and per-client I/O time. Even an
            // authenticated but wedged interface must not accumulate an
            // unbounded number of root-service threads.
            serviceClientSlots.wait()
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    configureServiceClientTimeouts(client)
                    handleServiceClient(client, configuration: configuration)
                }
                close(client)
                serviceClientSlots.signal()
            }
        }
    }

    static func configureServiceClientTimeouts(_ client: Int32) {
        var receiveTimeout = timeval(tv_sec: 5, tv_usec: 0)
        var sendTimeout = timeval(tv_sec: 15, tv_usec: 0)
        withUnsafePointer(to: &receiveTimeout) {
            _ = setsockopt(
                client, SOL_SOCKET, SO_RCVTIMEO, $0,
                socklen_t(MemoryLayout<timeval>.size)
            )
        }
        withUnsafePointer(to: &sendTimeout) {
            _ = setsockopt(
                client, SOL_SOCKET, SO_SNDTIMEO, $0,
                socklen_t(MemoryLayout<timeval>.size)
            )
        }
    }

    static func handleServiceClient(_ client: Int32, configuration: ServiceConfiguration) {
        let response: PrivilegedServiceResponse
        do {
            try authenticateClient(client, configuration: configuration)
            let request = try readServiceRequest(client)
            guard request.protocolVersion == PrivilegedServiceProtocol.version else {
                throw HelperFailure.service("unsupported protocol version")
            }
            switch request.action {
            case .capabilities:
                let verifierReady =
                    (try? validateRootOwnedExecutable(
                        URL(fileURLWithPath: operatorVerifier), maximumBytes: 40_000_000
                    )) != nil
                response = PrivilegedServiceResponse(
                    success: verifierReady,
                    message: verifierReady
                        ? "capability-wallet-v2; signed-first-install-v3; durable-operations-v1; self-upgrade-v1; root-release-verification-v1; application-firewall-v1; managed-qclient-v1; permanent-app-identity-v1"
                        : "The root-owned release verifier is missing; service repair is required.",
                    nodePID: currentNodePID(),
                    serviceBuild: verifierReady ? PrivilegedServiceProtocol.currentServiceBuild : nil
                )
            case .upgradeService:
                let message = try upgradeOperatorService(configuration: configuration)
                response = PrivilegedServiceResponse(success: true, message: message, nodePID: currentNodePID())
            case .status:
                response = PrivilegedServiceResponse(
                    success: true,
                    message: "Passwordless service is ready; node runtime is isolated as _quilnode.",
                    nodePID: currentNodePID()
                )
            case .nodeInfo:
                guard !serviceOperations.isRunning else {
                    throw HelperFailure.service("node inspection is paused while an update is activating")
                }
                try validateLaunchDaemonPlist()
                let nodeInfo = try runNodeTool(["--node-info"], timeout: 15)
                let peerInfo = try runNodeTool(["--peer-info"], timeout: 10)
                response = PrivilegedServiceResponse(
                    success: true,
                    message: "Local node identity read completed.",
                    nodePID: currentNodePID(),
                    nodeInfoOutput: nodeInfo,
                    peerInfoOutput: peerInfo
                )
            case .metrics:
                guard !serviceOperations.isRunning else {
                    throw HelperFailure.service("metrics are paused while an update is activating")
                }
                try validateLaunchDaemonPlist()
                let metrics = try runNodeTool(
                    ["--signature-check=\(currentSignatureCheck())", "--metrics"],
                    timeout: 8
                )
                response = PrivilegedServiceResponse(
                    success: true,
                    message: "Local node metrics read completed.",
                    nodePID: currentNodePID(),
                    metricsOutput: metrics
                )
            case .balance:
                guard !serviceOperations.isRunning else {
                    throw HelperFailure.service("balance checks are paused while an update is activating")
                }
                try validateLaunchDaemonPlist()
                let balance = try runQClientBalance(timeout: 45)
                response = PrivilegedServiceResponse(
                    success: true,
                    message: "Local QUIL wallet balance read completed.",
                    nodePID: currentNodePID(),
                    balanceOutput: balance
                )
            case .qclientStatus:
                let status = inspectManagedQClient()
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                response = PrivilegedServiceResponse(
                    success: true,
                    message: status.detail,
                    nodePID: currentNodePID(),
                    qclientOutput: String(decoding: try encoder.encode(status), as: UTF8.self)
                )
            case .qclientInstall:
                guard let path = request.manifestPath else { throw HelperFailure.usage }
                if try qclientInstallRequiresAuthorization(manifestPath: path) {
                    throw HelperFailure.authorizationRequired(
                        "Installing a source-built qclient requires explicit macOS administrator approval because the candidate is not covered by the official release-signing quorum."
                    )
                }
                let operation = try serviceOperations.begin(
                    action: PrivilegedServiceAction.qclientInstall.rawValue,
                    idempotencyKey: URL(fileURLWithPath: path).standardizedFileURL.path
                ) {
                    try withMutationLock { try installQClient(manifestPath: path) }
                    return "Matching qclient installed and independently re-verified."
                }
                response = PrivilegedServiceResponse(
                    success: operation.state != .failed,
                    message: operation.message,
                    nodePID: currentNodePID(),
                    operationID: operation.id,
                    operationState: operation.state.rawValue
                )
            case .walletInventory:
                guard !serviceOperations.isRunning else {
                    throw HelperFailure.service(
                        "wallet inspection is paused while another privileged operation is running")
                }
                let inventory = try walletInventory()
                response = PrivilegedServiceResponse(
                    success: true,
                    message: "Local identity packages inspected without exposing private key material.",
                    nodePID: currentNodePID(),
                    walletOutput: try encodeWalletPayload(inventory)
                )
            case .walletInspect:
                guard !serviceOperations.isRunning else {
                    throw HelperFailure.service(
                        "keyset inspection is paused while another privileged operation is running")
                }
                guard let path = request.manifestPath else { throw HelperFailure.usage }
                let manifest = try readWalletManifest(path, configuration: configuration)
                guard let selected = manifest.selectedDirectory else {
                    throw HelperFailure.invalidManifest("the selected keyset directory is missing")
                }
                let directory = try validateOperatorSelectedDirectory(
                    selected,
                    configuration: configuration,
                    purpose: .keysetSource
                )
                let inspection = try inspectKeyset(directory)
                response = PrivilegedServiceResponse(
                    success: true,
                    message: "Selected keyset inspected locally.",
                    walletOutput: try encodeWalletPayload(inspection)
                )
            case .walletTransact:
                guard request.manifestPath != nil else { throw HelperFailure.usage }
                throw HelperFailure.authorizationRequired(
                    "Identity creation, import, activation, and recovery export require explicit macOS administrator approval so a compromised interface cannot silently copy or replace key material."
                )
            case .firewallStatus:
                let status = try inspectFirewall()
                response = PrivilegedServiceResponse(
                    success: true,
                    message: firewallSummary(status),
                    nodePID: currentNodePID(),
                    firewallOutput: try encodeFirewallPayload(status)
                )
            case .firewallConfigure:
                let status = try withMutationLock { try configureFirewall() }
                response = PrivilegedServiceResponse(
                    success: true,
                    message: firewallSummary(status),
                    nodePID: currentNodePID(),
                    firewallOutput: try encodeFirewallPayload(status)
                )
            case .start:
                try validateLaunchDaemonPlist()
                try withMutationLock { try performLifecycle(.start) }
                response = PrivilegedServiceResponse(
                    success: true, message: "Quilibrium node start request completed.", nodePID: currentNodePID())
            case .stop:
                try validateLaunchDaemonPlist()
                try withMutationLock { try performLifecycle(.stop) }
                response = PrivilegedServiceResponse(success: true, message: "Quilibrium node stop request completed.")
            case .restart:
                try validateLaunchDaemonPlist()
                try withMutationLock { try performLifecycle(.restart) }
                response = PrivilegedServiceResponse(
                    success: true, message: "Quilibrium node restart request completed.", nodePID: currentNodePID())
            case .activate:
                guard let path = request.manifestPath else { throw HelperFailure.usage }
                try validateLaunchDaemonPlist()
                if try nodeActivationRequiresAuthorization(manifestPath: path) {
                    throw HelperFailure.authorizationRequired(
                        "Installing a source-built node requires explicit macOS administrator approval because it is not covered by the official release-signing quorum."
                    )
                }
                let operation = try serviceOperations.begin(
                    action: PrivilegedServiceAction.activate.rawValue,
                    idempotencyKey: URL(fileURLWithPath: path).standardizedFileURL.path
                ) {
                    try withMutationLock { try activate(manifestPath: path) }
                    return "Update installed; startup and local health checks passed."
                }
                response = PrivilegedServiceResponse(
                    success: operation.state != .failed,
                    message: operation.message,
                    nodePID: currentNodePID(),
                    operationID: operation.id,
                    operationState: operation.state.rawValue
                )
            case .install:
                guard let path = request.manifestPath else { throw HelperFailure.usage }
                let operation = try serviceOperations.begin(
                    action: PrivilegedServiceAction.install.rawValue,
                    idempotencyKey: URL(fileURLWithPath: path).standardizedFileURL.path
                ) {
                    try withMutationLock { try freshInstall(manifestPath: path) }
                    return "Signed Quilibrium node installed; launchd startup and local health checks passed."
                }
                response = PrivilegedServiceResponse(
                    success: operation.state != .failed,
                    message: operation.message,
                    nodePID: currentNodePID(),
                    operationID: operation.id,
                    operationState: operation.state.rawValue
                )
            case .rollback:
                try validateLaunchDaemonPlist()
                let operation = try serviceOperations.begin(
                    action: PrivilegedServiceAction.rollback.rawValue,
                    idempotencyKey: nil
                ) {
                    try withMutationLock { try rollback() }
                    return "Rollback completed; startup checks passed."
                }
                response = PrivilegedServiceResponse(
                    success: true,
                    message: operation.message,
                    nodePID: currentNodePID(),
                    operationID: operation.id,
                    operationState: operation.state.rawValue
                )
            case .operationStatus:
                guard let operationID = request.operationID else { throw HelperFailure.usage }
                let operation = try serviceOperations.record(id: operationID)
                response = PrivilegedServiceResponse(
                    success: operation.state != .failed,
                    message: operation.message,
                    nodePID: currentNodePID(),
                    operationID: operation.id,
                    operationState: operation.state.rawValue
                )
            }
        } catch HelperFailure.unauthorized {
            // Authentication failures are intentionally indistinguishable and
            // disclose no process, service-account, capability, or build state.
            response = PrivilegedServiceResponse(
                success: false,
                message: "The local service rejected an unauthenticated request.",
                serviceUser: nil,
                nodePID: nil,
                serviceBuild: nil
            )
        } catch HelperFailure.authorizationRequired(let message) {
            response = PrivilegedServiceResponse(
                success: false,
                message: message,
                nodePID: currentNodePID(),
                authorizationRequired: true
            )
        } catch {
            response = PrivilegedServiceResponse(success: false, message: "\(error)", nodePID: currentNodePID())
        }
        if var data = try? JSONEncoder().encode(response) {
            data.append(0x0a)
            data.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                var written = 0
                while written < bytes.count {
                    let count = Darwin.write(
                        client,
                        baseAddress.advanced(by: written),
                        bytes.count - written
                    )
                    if count <= 0 { break }
                    written += count
                }
            }
        }
    }
}
