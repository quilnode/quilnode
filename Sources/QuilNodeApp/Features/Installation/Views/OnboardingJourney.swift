import SwiftUI

struct OnboardingShell<Content: View, Footer: View>: View {
    @Environment(\.quilTheme) private var theme

    let stage: OnboardingStage
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?
    var height: CGFloat = 680
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        stage: OnboardingStage,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        height: CGFloat = 680,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.stage = stage
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.height = height
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingJourneyHeader(
                currentStage: stage,
                secondaryActionTitle: secondaryActionTitle,
                secondaryAction: secondaryAction
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.7)
            footer
                .frame(minHeight: 62)
                .padding(.horizontal, 24)
        }
        .frame(width: 900, height: height)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .foregroundStyle(theme.colors.primaryText)
    }
}

struct OnboardingJourneyHeader: View {
    @Environment(\.quilTheme) private var theme

    let currentStage: OnboardingStage
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 10) {
                ApplicationBrandMark(size: 25, theme: theme)
                Text("QuilNode setup")
                    .font(.subheadline.bold())
                Spacer()
                if let secondaryActionTitle, let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(OnboardingStage.allCases.enumerated()), id: \.element.id) { index, stage in
                    OnboardingStageNode(stage: stage, currentStage: currentStage)
                    if index < OnboardingStage.allCases.count - 1 {
                        OnboardingStageConnector(isComplete: stage.rawValue < currentStage.rawValue)
                            .padding(.top, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(theme.colors.surface.opacity(0.32))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.border.opacity(0.35))
                .frame(height: 0.5)
        }
    }
}

private struct OnboardingStageNode: View {
    @Environment(\.quilTheme) private var theme

    let stage: OnboardingStage
    let currentStage: OnboardingStage

    private var isComplete: Bool { stage.rawValue < currentStage.rawValue }
    private var isCurrent: Bool { stage == currentStage }
    private var tint: Color {
        if isComplete { return theme.colors.success }
        if isCurrent { return theme.colors.accent }
        return theme.colors.secondaryText
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isCurrent ? 0.16 : 0.08))
                Circle()
                    .strokeBorder(tint.opacity(isCurrent || isComplete ? 0.9 : 0.42), lineWidth: isCurrent ? 2 : 1)
                Image(systemName: isComplete ? "checkmark" : stage.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)

            Text(stage.title)
                .font(.caption2.weight(isCurrent ? .bold : .semibold))
                .foregroundStyle(isCurrent ? theme.colors.primaryText : theme.colors.secondaryText)
            Text(stage.status(relativeTo: currentStage))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: 92)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stage.title), \(stage.status(relativeTo: currentStage))")
    }
}

private struct OnboardingStageConnector: View {
    @Environment(\.quilTheme) private var theme
    let isComplete: Bool

    var body: some View {
        Capsule()
            .fill(isComplete ? theme.colors.success.opacity(0.8) : theme.colors.border.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
    }
}
