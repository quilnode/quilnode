import SwiftUI

struct OnboardingChoiceCard<Expanded: View>: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    var badge: String?
    let select: () -> Void
    @ViewBuilder let expanded: Expanded

    init(
        title: String,
        detail: String,
        systemImage: String,
        isSelected: Bool,
        badge: String? = nil,
        select: @escaping () -> Void,
        @ViewBuilder expanded: () -> Expanded
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.badge = badge
        self.select = select
        self.expanded = expanded()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: select) {
                HStack(spacing: 13) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.secondaryText.opacity(0.65))
                        .contentTransition(.symbolEffect(.replace))

                    DashboardCircleIcon(
                        systemImage: systemImage,
                        tint: isSelected ? theme.colors.accent : theme.colors.secondaryText.opacity(0.62),
                        size: 30
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                            if let badge {
                                Text(badge.uppercased())
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .tracking(0.7)
                                    .foregroundStyle(theme.colors.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(theme.colors.accent.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(theme.colors.secondaryText)
                    }

                    Spacer(minLength: 12)
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colors.secondaryText)
                        .contentTransition(.symbolEffect(.replace))
                }
                .contentShape(Rectangle())
                .padding(10)
            }
            .buttonStyle(QuilPressFeedbackButtonStyle())

            if isSelected {
                Divider().opacity(0.62)
                expanded
                    .padding(10)
                    .transition(motion.revealTransition)
            }
        }
        .background(theme.colors.surface.opacity(isSelected ? 0.9 : 0.58))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? theme.colors.accent.opacity(0.86) : theme.colors.border.opacity(0.48),
                    lineWidth: isSelected ? max(theme.metrics.borderWidth, 1.2) : max(theme.metrics.borderWidth, 0.5)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
        .quilHoverSurface(tint: theme.colors.accent, cornerRadius: theme.metrics.controlCornerRadius)
        .animation(motion.disclosure, value: isSelected)
    }
}

struct OnboardingEvidenceRow: View {
    @Environment(\.quilTheme) private var theme
    let systemImage: String
    let title: String
    let detail: String
    var tint: Color? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint ?? theme.colors.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingTrustStrip: View {
    @Environment(\.quilTheme) private var theme

    struct Item: Identifiable {
        let id: String
        let systemImage: String
        let title: String
        let detail: String

        init(systemImage: String, title: String, detail: String) {
            id = title
            self.systemImage = systemImage
            self.title = title
            self.detail = detail
        }
    }

    let items: [Item]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(index == 1 ? theme.colors.accentSecondary : theme.colors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.caption.weight(.semibold))
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)

                if index < items.count - 1 {
                    Divider().frame(height: 42)
                }
            }
        }
        .padding(.vertical, 9)
        .controlSurface()
    }
}

struct OnboardingProgressPanel: View {
    @Environment(\.quilTheme) private var theme
    let progress: OnboardingRuntimeProgress
    let detail: String
    var fraction: Double?
    var isEstimate = true
    var startedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("Step \(progress.step) of \(progress.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
                if let startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(
                            InstallationOperationPresentation.elapsedDescription(
                                from: startedAt,
                                to: context.date
                            )
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.colors.secondaryText)
                    }
                }
            }
            if isEstimate {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(theme.colors.accent)
            } else {
                ProgressView(value: resolvedFraction, total: 1)
                    .tint(theme.colors.accent)
            }
            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .controlSurface(tint: theme.colors.accent)
    }

    private var resolvedFraction: Double {
        if let fraction { return min(max(fraction, 0), 1) }
        return Double(progress.step - 1) / Double(max(progress.total - 1, 1))
    }
}

struct OnboardingSectionLabel: View {
    @Environment(\.quilTheme) private var theme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.3)
            .foregroundStyle(theme.colors.secondaryText)
    }
}
