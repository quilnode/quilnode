import Darwin
import Foundation

/// Only port/state evidence from one process. Peer addresses, socket handles,
/// and other applications' connections never cross the service boundary.
public struct ProcessSocketInspection: Codable, Equatable, Sendable {
    public var processID: Int32
    public var observedAt: Date
    public var tcpListeners: Set<UInt16>
    public var udpBindings: Set<UInt16>

    public init(
        processID: Int32, observedAt: Date = Date(),
        tcpListeners: Set<UInt16> = [], udpBindings: Set<UInt16> = []
    ) {
        self.processID = processID
        self.observedAt = observedAt
        self.tcpListeners = tcpListeners
        self.udpBindings = udpBindings
    }
}

/// Uses the supported per-process descriptor API instead of a system-wide
/// network table. The privileged caller must select its own managed node PID;
/// the wire protocol never accepts an arbitrary PID from the interface.
public enum ProcessSocketInspector {
    public static func inspect(processID: Int32) -> ProcessSocketInspection? {
        guard processID > 0 else { return nil }
        let stride = MemoryLayout<proc_fdinfo>.stride
        let needed = proc_pidinfo(processID, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0, needed <= 2_000_000 else { return nil }
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 64)
        let capacity = descriptors.count * stride
        let read = descriptors.withUnsafeMutableBytes {
            proc_pidinfo(processID, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
        }
        guard read > 0, read < capacity, Int(read) % stride == 0 else { return nil }
        var result = ProcessSocketInspection(processID: processID)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        for descriptor in descriptors.prefix(Int(read) / stride) where descriptor.proc_fdtype == PROX_FDTYPE_SOCKET {
            guard ContinuousClock.now < deadline else { return nil }
            var info = socket_fdinfo()
            let size = MemoryLayout<socket_fdinfo>.stride
            let count = proc_pidfdinfo(processID, descriptor.proc_fd, PROC_PIDFDSOCKETINFO, &info, Int32(size))
            if count != size {
                // A socket may close between enumeration and inspection. All
                // other failures make negative listener claims unreliable.
                if count <= 0, errno == EBADF || errno == ENOENT { continue }
                return nil
            }
            let socket = info.psi
            guard socket.soi_family == AF_INET || socket.soi_family == AF_INET6 else { continue }
            if socket.soi_kind == SOCKINFO_TCP, socket.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN {
                let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: socket.soi_proto.pri_tcp.tcpsi_ini.insi_lport))
                if port != 0 { result.tcpListeners.insert(port) }
            } else if socket.soi_kind == SOCKINFO_IN, socket.soi_protocol == IPPROTO_UDP {
                let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: socket.soi_proto.pri_in.insi_lport))
                if port != 0 { result.udpBindings.insert(port) }
            }
        }
        result.observedAt = Date()
        return result
    }
}
