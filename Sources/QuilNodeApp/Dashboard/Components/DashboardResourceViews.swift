import SwiftUI

struct ResourceMeter: View {
    let title: String
    let value: String
    let fraction: Double
    let systemImage: String
    let tint: Color
    var detail: String? = nil
    var cpuDetail: CPUUsagePresentation? = nil

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 17)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                if let cpuDetail {
                    CPUUsageDetailView(usage: cpuDetail)
                } else if let detail {
                    Text(detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            // Keep every resource row on the same compact grid. The previous
            // CPU-only width reserved space for the removed sampling text and
            // pushed its progress bar far away from the label.
            .frame(width: 96, alignment: .leading)
            ProgressView(value: fraction)
                .tint(tint)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
                .quilLiveValueTransition(value: value)
        }
    }
}

struct CPUUsageDetailView: View {
    @Environment(\.redactionReasons) private var redactionReasons
    let usage: CPUUsagePresentation

    var body: some View {
        HStack(spacing: 0) {
            if let coreEquivalent = usage.coreEquivalentText {
                PrivacyProtectedText(value: coreEquivalent, field: .hardwareProfile)
                Text(" of ")
                PrivacyProtectedText(value: String(usage.logicalCoreCount), field: .hardwareProfile)
                Text(" cores")
            }
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            usage.accessibilityDescription(hidingHardware: redactionReasons.contains(.privacy))
        )
    }
}
