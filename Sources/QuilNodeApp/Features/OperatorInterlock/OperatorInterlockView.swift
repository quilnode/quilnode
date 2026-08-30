import SwiftUI

struct OperatorInterlockView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    let model: OperatorInterlockModel
    let onCancel: () -> Void
    let onConfirm: (OperatorInterlockDecision) -> Void

    @State private var selectedDecisionID: String

    init(
        model: OperatorInterlockModel,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (OperatorInterlockDecision) -> Void
    ) {
        self.model = model
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedDecisionID = State(initialValue: model.defaultDecisionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.colors.border.opacity(0.52))

            ScrollView {
                VStack(spacing: 12) {
                    OperatorInterlockRunway(steps: model.steps)
                    OperatorInterlockScopeLedger(
                        changes: model.changes,
                        preserved: model.preserved
                    )
                    verificationStrip
                    if model.decisions.count > 1 {
                        decisionGrid
                    }
                    trustStrip
                }
                .padding(16)
            }

            Divider().overlay(theme.colors.border.opacity(0.52))
            actionBar
        }
        .frame(width: 680, height: panelHeight)
        .background { ThemeCanvasBackground() }
        .onExitCommand(perform: onCancel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Confirmation: \(model.title)")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 13) {
            DashboardCircleIcon(
                systemImage: model.symbol,
                tint: color(for: model.tone),
                size: 44
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(model.eyebrow)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(color(for: model.tone))
                Text(model.title)
                    .font(.title2.weight(.bold))
                Text(model.outcome)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(theme.colors.surfaceElevated.opacity(0.92), in: Circle())
            }
            .buttonStyle(QuilPressFeedbackButtonStyle())
            .accessibilityLabel(model.cancelTitle)
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var verificationStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.colors.success)
                Text("VERIFICATION AFTER ACTION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            HStack(spacing: 0) {
                ForEach(Array(model.verification.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(theme.colors.success)
                        Text(item)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if index < model.verification.count - 1 {
                        Rectangle()
                            .fill(theme.colors.border.opacity(0.48))
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 9)
                    }
                }
            }
        }
        .padding(13)
        .controlSurface(tint: theme.colors.success)
    }

    private var decisionGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHEN TO START")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(theme.colors.secondaryText)

            HStack(spacing: 10) {
                ForEach(model.decisions) { decision in
                    OperatorInterlockDecisionCard(
                        decision: decision,
                        isSelected: selectedDecisionID == decision.id,
                        onSelect: { selectedDecisionID = decision.id }
                    )
                }
            }
        }
    }

    private var trustStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(theme.colors.success)
                .padding(.top, 1)
            Text(model.trustNote)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text("LOCAL")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(theme.colors.success)
        }
        .padding(12)
        .controlSurface(tint: theme.colors.success)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Label("Review the exact scope above", systemImage: "scope")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer()
            Button(model.cancelTitle, action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            Button(selectedDecision.actionTitle) {
                onConfirm(selectedDecision)
            }
            .buttonStyle(.borderedProminent)
            .tint(color(for: selectedDecision.tone))
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .background(theme.colors.surface.opacity(0.96))
    }

    private var selectedDecision: OperatorInterlockDecision {
        model.decisions.first(where: { $0.id == selectedDecisionID }) ?? model.defaultDecision
    }

    private var panelHeight: CGFloat {
        if model.decisions.count > 1 { return 810 }
        if model.preserved.count > 4 { return 680 }
        return 620
    }

    private func color(for tone: OperatorInterlockTone) -> Color {
        switch tone {
        case .accent: theme.colors.accent
        case .success: theme.colors.success
        case .information: theme.colors.info
        case .warning: theme.colors.warning
        case .destructive: theme.colors.danger
        }
    }
}

struct OperatorInterlockRunway: View {
    @Environment(\.quilTheme) private var theme

    let steps: [OperatorInterlockStep]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    DashboardCircleIcon(systemImage: step.symbol, tint: color(for: step.tone), size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(.caption.weight(.semibold))
                        Text(step.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if index < steps.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.colors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.top, 11)
                }
            }
        }
        .padding(13)
        .controlSurface(tint: theme.colors.info)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action sequence")
    }

    private func color(for tone: OperatorInterlockTone) -> Color {
        switch tone {
        case .accent: theme.colors.accent
        case .success: theme.colors.success
        case .information: theme.colors.info
        case .warning: theme.colors.warning
        case .destructive: theme.colors.danger
        }
    }
}

private struct OperatorInterlockScopeLedger: View {
    @Environment(\.quilTheme) private var theme

    let changes: [OperatorInterlockScopeItem]
    let preserved: [OperatorInterlockScopeItem]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            scopeColumn("WILL CHANGE", items: changes, tint: theme.colors.info)
            Rectangle()
                .fill(theme.colors.border.opacity(0.52))
                .frame(width: 1)
            scopeColumn("PRESERVED", items: preserved, tint: theme.colors.success)
        }
        .controlSurface(tint: theme.colors.accent)
    }

    private func scopeColumn(_ title: String, items: [OperatorInterlockScopeItem], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(tint)
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 19)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct OperatorInterlockDecisionCard: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    let decision: OperatorInterlockDecision
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    DashboardCircleIcon(systemImage: decision.symbol, tint: tint, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(decision.title)
                            .font(.caption.weight(.semibold))
                        Text(decision.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? tint : theme.colors.secondaryText)
                }

                ForEach(decision.bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(tint.opacity(isSelected ? 0.11 : 0.035), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(isSelected ? 0.8 : 0.18), lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .animation(motion.selection, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tint: Color {
        switch decision.tone {
        case .accent: theme.colors.accent
        case .success: theme.colors.success
        case .information: theme.colors.info
        case .warning: theme.colors.warning
        case .destructive: theme.colors.danger
        }
    }
}
