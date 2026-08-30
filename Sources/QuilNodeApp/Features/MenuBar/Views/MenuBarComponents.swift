import SwiftUI

struct MenuBarSectionSurface<Content: View>: View {
    @Environment(\.quilTheme) private var theme

    var tint: Color? = nil
    var contentPadding: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (tint ?? theme.colors.surfaceElevated).opacity(tint == nil ? 0.68 : 0.09),
                in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                    .strokeBorder(
                        (tint ?? theme.colors.border).opacity(tint == nil ? 0.52 : 0.24),
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
            }
    }
}

struct MenuBarEpochRunway: View {
    @Environment(\.quilTheme) private var theme

    let frame: UInt64?
    let epoch: UInt64?
    let progress: Double
    let progressText: String
    let eta: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.frame)
                    .accessibilityHidden(true)

                metric("Frame", value: frame?.grouped ?? "—")
                Divider().frame(height: 16)
                metric("Epoch", value: epoch?.grouped ?? "—")
                Divider().frame(height: 16)

                PrivacyProtectedText(value: progressText, field: .networkActivity)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.colors.frame)

                Spacer(minLength: 2)

                PrivacyProtectedText(value: eta, field: .networkActivity)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }

            MenuBarProgressTrack(value: progress, tint: theme.colors.frame)
                .quilLiveValueTransition(value: progress)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            theme.colors.surfaceElevated.opacity(0.62),
            in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                .strokeBorder(theme.colors.border.opacity(0.42), lineWidth: 0.6)
        }
        .accessibilityElement(children: .combine)
    }

    private func metric(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: .networkActivity)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.primaryText)
        }
        .font(.caption.monospacedDigit())
        .lineLimit(1)
    }
}

struct MenuBarEvidenceMetric: Identifiable {
    let label: String
    let value: String
    let privacyField: PrivacyField?
    let tint: Color

    var id: String { label }
}

struct MenuBarEvidenceRow: View {
    @Environment(\.quilTheme) private var theme

    let title: String
    let systemImage: String
    let tint: Color
    let metrics: [MenuBarEvidenceMetric]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(
                        tint.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 7) {
                        ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                            if index > 0 {
                                Text("·")
                                    .foregroundStyle(theme.colors.secondaryText.opacity(0.6))
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(metric.label)
                                    .foregroundStyle(theme.colors.secondaryText)
                                PrivacyProtectedText(value: metric.value, field: metric.privacyField)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(metric.tint)
                                    .quilLiveValueTransition(value: metric.value)
                            }
                        }
                    }
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 5)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.colors.secondaryText.opacity(0.62))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 11)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: tint, cornerRadius: theme.metrics.controlCornerRadius)
        .accessibilityHint("Opens \(title) in the dashboard")
    }
}

struct MenuBarResourceMeter: View {
    @Environment(\.quilTheme) private var theme

    let title: String
    let value: String
    let fraction: Double
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    tint.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 4)
                    PrivacyProtectedText(value: value, field: .hardwareProfile)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(tint)
                        .quilLiveValueTransition(value: value)
                }
                MenuBarProgressTrack(value: fraction, tint: tint)
                    .quilLiveValueTransition(value: fraction)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A compact compositor-only progress track. SwiftUI's macOS linear
/// `ProgressView` keeps an AppKit intrinsic width inside dense HStacks, which
/// produced dot-sized meters. Geometry here fills the available row without
/// introducing timers, layout animation, or a custom drawing loop.
struct MenuBarProgressTrack: View {
    @Environment(\.quilTheme) private var theme

    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let fraction = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(theme.colors.border.opacity(0.48))
                if fraction > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geometry.size.width * fraction, 3))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

struct MenuBarStatusPill: View {
    let value: String
    let suffix: String
    let systemImage: String
    let privacyField: PrivacyField
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .accessibilityHidden(true)
            PrivacyProtectedPhrase(value: value, suffix: suffix, field: privacyField)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 0.5))
    }
}

struct MenuBarActionTile: View {
    @Environment(\.quilTheme) private var theme

    let title: String
    let systemImage: String
    var tint: Color? = nil
    var role: ButtonRole? = nil
    var isBusy = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 3) {
                Group {
                    if isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(height: 16)

                Text(title)
                    .font(.system(size: 8.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint ?? theme.colors.secondaryText)
            .frame(width: 46, height: 44)
            .background(
                theme.colors.surfaceElevated.opacity(0.74),
                in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
                    .strokeBorder(theme.colors.border.opacity(0.42), lineWidth: 0.6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.86, pressedScale: 0.97))
        .quilHoverSurface(tint: tint ?? theme.colors.accent, cornerRadius: theme.metrics.controlCornerRadius)
        .disabled(isDisabled)
        .help(title)
        .accessibilityLabel(title)
    }
}
