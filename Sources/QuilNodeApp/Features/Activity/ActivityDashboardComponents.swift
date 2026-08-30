import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ActivityHeader: View {
    @Environment(\.quilTheme) private var theme

    let narrative: ActivityNarrative
    @Binding var range: ActivityTimeRange
    @Binding var mode: ActivityMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(narrative.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.colors.primaryText)
                    Text(narrative.subtitle)
                        .font(.callout)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer(minLength: 20)
                HStack(spacing: 9) {
                    Text("Activity range")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.colors.secondaryText)
                    Picker("Activity range", selection: $range) {
                        ForEach(ActivityTimeRange.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 208)
                }
            }

            Picker("Activity mode", selection: $mode) {
                ForEach(ActivityMode.allCases) { value in
                    Text(value.label).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 290)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct ActivitySummaryBand: View {
    @Environment(\.quilTheme) private var theme

    let summary: NodeActivitySummary
    let chainProgress: ChainProgressAssessment

    var body: some View {
        HStack(spacing: 0) {
            metric(
                title: "Frames advanced",
                value: summary.frameDelta.formatted(),
                detail: "in selected range",
                tint: theme.colors.frame
            )
            separator
            metric(
                title: "Average pace",
                value: paceValue,
                detail: paceDetail,
                tint: theme.colors.info
            )
            separator
            metric(
                title: "Peer band",
                value: peerBand + "  net " + peerDelta,
                detail: "observed range",
                tint: theme.colors.accentSecondary,
                privacyField: .networkActivity
            )
            separator
            metric(
                title: "Runtime continuity",
                value: summary.continuity.map { String(format: "%.0f%%", $0 * 100) } ?? "Calibrating",
                detail: "of local samples observed",
                tint: continuityTint
            )
        }
        .padding(.vertical, 12)
        .background(theme.colors.surface.opacity(theme.components.surfaceOpacity))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    theme.colors.border.opacity(0.68),
                    lineWidth: max(theme.metrics.borderWidth, 0.5)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
    }

    private func metric(
        title: String,
        value: String,
        detail: String,
        tint: Color,
        privacyField: PrivacyField? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 18, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.58))
            .frame(width: max(theme.metrics.borderWidth, 0.5), height: 56)
    }

    private var paceValue: String {
        if chainProgress.state == .archiveRecovery { return "Network hold" }
        return summary.averageFramesPerMinute.map { String(format: "%.2f/min", $0) } ?? "Calibrating"
    }

    private var paceDetail: String {
        chainProgress.state == .archiveRecovery ? "archive recovery detected" : "frames per minute"
    }

    private var peerBand: String {
        guard let minimum = summary.peerMinimum, let maximum = summary.peerMaximum else { return "Calibrating" }
        return minimum == maximum ? String(minimum) : "\(minimum)–\(maximum)"
    }

    private var peerDelta: String {
        guard summary.peerMinimum != nil else { return "—" }
        if summary.peerDelta == 0 { return "±0" }
        return summary.peerDelta > 0 ? "+\(summary.peerDelta)" : String(summary.peerDelta)
    }

    private var continuityTint: Color {
        guard let continuity = summary.continuity else { return theme.colors.info }
        if continuity >= 0.98 { return theme.colors.success }
        if continuity >= 0.90 { return theme.colors.warning }
        return theme.colors.danger
    }
}

struct ActivityEmptyState: View {
    @Environment(\.quilTheme) private var theme

    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.info)
                .frame(width: 34, height: 34)
                .background(theme.colors.info.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
        }
        .padding(16)
    }
}

struct ActivityProvenanceRow: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Label("Local node evidence", systemImage: "lock.shield.fill")
            Label("30-second samples", systemImage: "timer")
            Label("7-day retention", systemImage: "calendar")
            Spacer()
            Text("No explorer or remote agent")
        }
        .font(.caption2)
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 4)
    }
}
