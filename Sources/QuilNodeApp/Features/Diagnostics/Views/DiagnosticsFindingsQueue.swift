import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticsFindingsQueue: View {
    @Environment(\.quilTheme) private var theme
    let findings: [NodeDiagnosticCheck]
    let selectedID: String?
    var fillsWidth = false
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Findings queue").font(.headline)
                Spacer()
                Text("\(findings.count)").font(.caption.bold().monospacedDigit())
            }
            .padding(12)
            Divider()
            if findings.isEmpty {
                ContentUnavailableView(
                    "No findings",
                    systemImage: "checkmark.seal.fill",
                    description: Text("All completed local checks passed.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ForEach(findings) { check in
                    Button {
                        onSelect(check.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(check.title, systemImage: DiagnosticVisuals.icon(check.state))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(DiagnosticVisuals.stateLabel(check.state))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(DiagnosticVisuals.tint(check.state, theme: theme))
                            }
                            Text(check.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            if let observedAt = check.observedAt {
                                Text(observedAt.formatted(.relative(presentation: .named)))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedID == check.id
                                ? DiagnosticVisuals.tint(check.state, theme: theme).opacity(0.075)
                                : Color.clear
                        )
                    }
                    .buttonStyle(QuilPressFeedbackButtonStyle())
                    Divider()
                }
            }
        }
        .frame(width: fillsWidth ? nil : 278, alignment: .top)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .top)
        .frame(minHeight: 286, alignment: .top)
        .controlSurface(tint: findings.isEmpty ? theme.colors.success : theme.colors.warning)
    }
}
