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

struct EpochProgressRing: View {
    @Environment(\.quilTheme) private var theme
    let progress: Double
    let epoch: UInt64
    let frame: UInt64
    let tint: Color
    var compact = false
    var etaLabel: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.12), lineWidth: ringWidth)
            if theme.components.ringStyle == .gradient {
                Circle()
                    .trim(from: 0, to: max(0.01, progress))
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.55), tint, theme.colors.privacy.opacity(0.82)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .trim(from: 0, to: max(0.01, progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                .padding(compact ? 13 : 18)

            VStack(spacing: compact ? 1 : 3) {
                Text("FRAME")
                    .font(.system(size: compact ? 7 : 9, weight: .bold))
                    .tracking(compact ? 0.8 : 1.2)
                    .foregroundStyle(.secondary)
                Text(frame.grouped)
                    .font(
                        .system(
                            size: (compact ? 12 : 20) * theme.typography.scale, weight: .bold,
                            design: theme.typography.displayDesign
                        ).monospacedDigit()
                    )
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .quilLiveValueTransition(value: frame)
                Text("epoch \(epoch)")
                    .font(.system(size: compact ? 8 : 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .quilLiveValueTransition(value: epoch)
                if let etaLabel {
                    Text(etaLabel)
                        .font(.system(size: compact ? 7 : 9, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .padding(compact ? 16 : 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let base = "Frame \(frame), epoch \(epoch), \(Int(progress * 100)) percent complete"
        return etaLabel.map { "\(base), \($0)" } ?? base
    }

    private var ringWidth: CGFloat {
        theme.components.ringThickness * (compact ? 0.78 : 1)
    }
}
