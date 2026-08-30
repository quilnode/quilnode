import AppKit
import Darwin
import Foundation
import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

enum ThemeLoadBoundaryError: LocalizedError {
    case unsafeDocument

    var errorDescription: String? {
        "Theme documents must be regular, non-symbolic files within the size limit."
    }
}

/// Watches both root changes and edits inside pack directories. The two-second
/// fingerprint is intentionally low-frequency and only stats a handful of tiny files.
final class ThemeDirectoryWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.quilnode.app.theme-watcher", qos: .utility)
    private var descriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var fingerprint = ""

    func start(url: URL, onChange: @escaping @Sendable () -> Void) {
        stop()
        fingerprint = Self.fingerprint(at: url)
        descriptor = open(url.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: [.write, .extend, .attrib, .rename, .delete], queue: queue)
            source.setEventHandler(handler: onChange)
            source.setCancelHandler { [descriptor] in close(descriptor) }
            self.source = source
            source.resume()
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2, leeway: .milliseconds(300))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let next = Self.fingerprint(at: url)
            guard next != self.fingerprint else { return }
            self.fingerprint = next
            onChange()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        timer?.cancel()
        timer = nil
        descriptor = -1
    }

    private static func fingerprint(at root: URL) -> String {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles])
        else { return "missing" }
        var parts: [String] = []
        for case let url as URL in enumerator {
            guard ["json", "png", "md"].contains(url.pathExtension.lowercased()) else { continue }
            let values = try? url.resourceValues(forKeys: [
                .contentModificationDateKey, .fileSizeKey, .isRegularFileKey,
            ])
            guard values?.isRegularFile == true else { continue }
            parts.append(
                "\(url.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)")
        }
        return parts.sorted().joined(separator: "\n")
    }

    deinit { stop() }
}
