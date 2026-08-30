import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A single semantic presentation for CPU telemetry across the menu bar and
/// dashboard. `NodeSnapshot.cpuPercent` is the bounded share of this Mac;
/// core-equivalent usage remains visible as supporting context.
struct CPUUsagePresentation {
    let percent: Double?
    let coreEquivalent: Double?
    let logicalCoreCount: Int

    init(snapshot: NodeSnapshot) {
        percent = snapshot.cpuPercent
        coreEquivalent = snapshot.cpuCoreEquivalent
        logicalCoreCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
    }

    var valueText: String {
        percent.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    var compactValueText: String {
        percent.map { String(format: "%.0f%%", $0) } ?? "—"
    }

    var fraction: Double {
        min(max((percent ?? 0) / 100, 0), 1)
    }

    var detailText: String {
        guard coreEquivalent != nil else { return "CPU sample pending" }
        let cores = coreEquivalentText ?? "—"
        return "\(cores) of \(logicalCoreCount) cores"
    }

    var coreEquivalentText: String? {
        coreEquivalent.map { String(format: "%.1f", $0) }
    }

    func accessibilityDescription(hidingHardware: Bool) -> String {
        guard let percent else { return "Node CPU unavailable." }
        if hidingHardware {
            return "Node CPU \(String(format: "%.1f", percent)) percent of total Mac capacity."
        }
        return "Node CPU \(String(format: "%.1f", percent)) percent of total Mac capacity. \(detailText)."
    }
}
