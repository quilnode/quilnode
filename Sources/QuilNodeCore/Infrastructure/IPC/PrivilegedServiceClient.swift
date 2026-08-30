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

    static func response(
        _ action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        operationID: String? = nil,
        nodeUpdatePolicy: AutomaticNodeUpdatePolicy? = nil,
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
                    operationID: operationID,
                    nodeUpdatePolicy: nodeUpdatePolicy
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
