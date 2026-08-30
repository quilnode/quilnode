import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

public enum PrivilegedServiceClient {
    public static let socketPath = "/var/run/quilnode-operator.sock"
    /// Helper protocol compatibility is independent from the GUI build number.
    /// Pure presentation releases must not request a privileged-service upgrade.
    public static let minimumSupportedServiceBuild =
        PrivilegedServiceProtocol.minimumSupportedServiceBuild

    public static func request(
        _ action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        timeout: TimeInterval = 110
    ) -> (output: String, exitCode: Int32) {
        let result = response(action, manifestPath: manifestPath, timeout: timeout)
        return (result.response?.message ?? result.error, result.exitCode)
    }

    /// Starts a daemon-owned privileged operation and follows its durable
    /// status. The service acknowledges immediately, so a slow node startup
    /// never depends on keeping one socket (or the dashboard window) alive.
    /// Older synchronous service versions remain compatible because they
    /// return a final response without an operation identifier.
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
            switch acceptedStateOrNil(accepted.operationState) {
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
                switch acceptedStateOrNil(status.operationState) {
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

    private static func acceptedStateOrNil(_ value: String?) -> OperationState? {
        value.flatMap(OperationState.init(rawValue:))
    }

    public static func readNodeInfo(timeout: TimeInterval = 30) -> NodeInfo? {
        let result = response(.nodeInfo, timeout: timeout)
        guard result.exitCode == 0, let response = result.response else { return nil }
        var info = NodeInfoParser.parse(response.nodeInfoOutput ?? "")
        let peerInfo = NodeInfoParser.parse(response.peerInfoOutput ?? "")
        info.legacyPeerID = peerInfo.legacyPeerID
        return info.version == nil && info.peerID == nil && info.proverAddress == nil ? nil : info
    }

    public static func readMetrics(timeout: TimeInterval = 10) -> String? {
        let result = response(.metrics, timeout: timeout)
        guard result.exitCode == 0 else { return nil }
        return result.response?.metricsOutput
    }

    public static func readBalance(timeout: TimeInterval = 45) -> (balance: QuilBalance?, error: String?) {
        let result = response(.balance, timeout: timeout)
        guard result.exitCode == 0, let response = result.response else {
            return (nil, result.error)
        }
        guard let balance = QuilBalanceParser.parse(response.balanceOutput ?? "") else {
            return (nil, "The local wallet returned an unreadable balance response.")
        }
        return (balance, nil)
    }

    public static func readQClientStatus(
        timeout: TimeInterval = 8
    ) -> (status: ManagedQClientStatus?, error: String?) {
        let result = response(.qclientStatus, timeout: timeout)
        guard result.exitCode == 0,
            let output = result.response?.qclientOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return (try decoder.decode(ManagedQClientStatus.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable qclient provenance.")
        }
    }

    public static func readFirewallStatus(
        timeout: TimeInterval = 8
    ) -> (status: ManagedFirewallStatus?, error: String?) {
        decodeFirewallResponse(response(.firewallStatus, timeout: timeout))
    }

    public static func configureFirewall(
        timeout: TimeInterval = 20
    ) -> (status: ManagedFirewallStatus?, error: String?) {
        decodeFirewallResponse(response(.firewallConfigure, timeout: timeout))
    }

    private static func decodeFirewallResponse(
        _ result: (response: PrivilegedServiceResponse?, error: String, exitCode: Int32)
    ) -> (status: ManagedFirewallStatus?, error: String?) {
        guard result.exitCode == 0,
            let output = result.response?.firewallOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return (try decoder.decode(ManagedFirewallStatus.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable firewall state.")
        }
    }

    public static func readWalletInventory(timeout: TimeInterval = 60) -> (inventory: WalletInventory?, error: String?)
    {
        let result = response(.walletInventory, timeout: timeout)
        guard result.exitCode == 0, let output = result.response?.walletOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return (try decoder.decode(WalletInventory.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable wallet metadata.")
        }
    }

    public static func inspectKeyset(
        manifestPath: String,
        timeout: TimeInterval = 20
    ) -> (inspection: KeysetInspection?, error: String?) {
        let result = response(.walletInspect, manifestPath: manifestPath, timeout: timeout)
        guard result.exitCode == 0, let output = result.response?.walletOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        do {
            return (try JSONDecoder().decode(KeysetInspection.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable keyset metadata.")
        }
    }

    private static func response(
        _ action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        operationID: String? = nil,
        timeout: TimeInterval
    ) -> (response: PrivilegedServiceResponse?, error: String, exitCode: Int32) {
        var socketInfo = stat()
        guard lstat(socketPath, &socketInfo) == 0,
            (socketInfo.st_mode & S_IFMT) == S_IFSOCK,
            socketInfo.st_uid == getuid(),
            socketInfo.st_mode & 0o077 == 0
        else {
            return (nil, "The local service socket ownership or permissions are unsafe.", 69)
        }
        let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return (nil, "Unable to create the local service connection.", 1) }
        defer { close(socketFD) }

        var receiveTimeout = timeval(
            tv_sec: Int(timeout.rounded(.up)),
            tv_usec: 0
        )
        withUnsafePointer(to: &receiveTimeout) {
            _ = setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, $0, socklen_t(MemoryLayout<timeval>.size))
        }
        withUnsafePointer(to: &receiveTimeout) {
            _ = setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, $0, socklen_t(MemoryLayout<timeval>.size))
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let socketPathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard socketPath.utf8.count < socketPathCapacity else {
            return (nil, "The local service socket path is invalid.", 1)
        }
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: socketPathCapacity) {
                _ = strlcpy($0, socketPath, socketPathCapacity)
            }
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return (nil, "Passwordless service is not available.", 69) }

        do {
            var payload = try JSONEncoder().encode(
                PrivilegedServiceRequest(
                    action: action,
                    manifestPath: manifestPath,
                    operationID: operationID
                )
            )
            payload.append(0x0a)
            let sent = payload.withUnsafeBytes { bytes -> Int in
                guard let baseAddress = bytes.baseAddress else { return 0 }
                var offset = 0
                while offset < bytes.count {
                    let count = Darwin.write(
                        socketFD,
                        baseAddress.advanced(by: offset),
                        bytes.count - offset
                    )
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { return offset }
                    offset += count
                }
                return offset
            }
            guard sent == payload.count else {
                return (nil, "Unable to send the complete service request.", 1)
            }

            var responseData = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while responseData.count <= PrivilegedServiceProtocol.maximumResponseBytes {
                let count = Darwin.read(socketFD, &buffer, buffer.count)
                if count <= 0 { break }
                responseData.append(buffer, count: count)
                guard responseData.count <= PrivilegedServiceProtocol.maximumResponseBytes else {
                    return (nil, "The local service response exceeded its safety limit.", 1)
                }
                if responseData.last == 0x0a { break }
            }
            guard !responseData.isEmpty else { return (nil, "The passwordless service did not respond.", 1) }
            let response = try JSONDecoder().decode(
                PrivilegedServiceResponse.self,
                from: responseData.prefix { $0 != 0x0a }
            )
            guard response.protocolVersion == PrivilegedServiceProtocol.version else {
                return (nil, "The passwordless service protocol is incompatible.", 1)
            }
            let exitCode: Int32 =
                response.success
                ? 0
                : (response.authorizationRequired == true ? 77 : 1)
            return (response, response.message, exitCode)
        } catch {
            return (nil, "Invalid passwordless service response: \(error.localizedDescription)", 1)
        }
    }

    public static func isAvailable(timeout: TimeInterval = 35) -> Bool {
        // The service deliberately serializes privileged operations. A status
        // request can therefore sit behind the initial node-info collection
        // (up to 25 seconds) without meaning that the service is unavailable.
        // Keeping this timeout above that bound prevents the dashboard from
        // briefly and incorrectly advertising an administrator prompt.
        request(.status, timeout: timeout).exitCode == 0
    }

    /// Unlike a generic status probe, this proves the installed service
    /// understands the current capability-based wallet and first-install
    /// protocol. Older services fail closed and trigger the explained one-time
    /// upgrade flow.
    public static func installedServiceBuild(timeout: TimeInterval = 5) -> Int? {
        let result = response(.capabilities, timeout: timeout)
        guard result.exitCode == 0 else { return nil }
        return result.response?.serviceBuild
    }

    public static func supportsCurrentSecurityBoundary(
        minimumBuild: Int = minimumSupportedServiceBuild,
        timeout: TimeInterval = 60
    ) -> Bool {
        guard let build = installedServiceBuild(timeout: timeout) else { return false }
        return build >= minimumBuild
    }
}
