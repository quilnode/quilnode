import SwiftUI

struct OperatorInterlockView: View {
    @Environment(\.quilTheme) private var theme

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
                    OperatorInterlockScopeLedger(changes: model.changes, preserved: model.preserved)
                    verificationStrip
                    if model.decisions.count > 1 { decisionGrid }
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
            DashboardCircleIcon(systemImage: model.symbol, tint: model.tone.color(in: theme), size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.eyebrow)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(model.tone.color(in: theme))
                Text(model.title).font(.title2.weight(.bold))
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
                Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.colors.success)
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
            Button(selectedDecision.actionTitle) { onConfirm(selectedDecision) }
                .buttonStyle(.borderedProminent)
                .tint(selectedDecision.tone.color(in: theme))
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
}
