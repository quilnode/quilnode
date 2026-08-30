import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticsProofMatrix: View {
    @Environment(\.quilTheme) private var theme
    let categories: [DiagnosticCategoryPresentation]
    let selectedID: String?
    var compactLayout = false
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            if compactLayout {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 2),
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(categories) { category in categoryCard(category) }
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(categories) { category in categoryCard(category) }
                }
            }
        }
    }

    private func categoryCard(_ category: DiagnosticCategoryPresentation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(categoryTitle(category.category))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(category.passedCount)/\(category.checks.count)")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(category.failedCount > 0 ? theme.colors.danger : theme.colors.success)
            }
            .padding(10)
            Divider()
            ForEach(category.checks) { check in
                Button {
                    onSelect(check.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: DiagnosticVisuals.icon(check.state))
                            .foregroundStyle(DiagnosticVisuals.tint(check.state, theme: theme))
                        Text(check.title).font(.caption2.weight(.medium)).lineLimit(2)
                        Spacer(minLength: 2)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedID == check.id ? theme.colors.info.opacity(0.08) : Color.clear)
                }
                .buttonStyle(QuilPressFeedbackButtonStyle())
            }
            Spacer(minLength: 0)
            Divider()
            HStack(spacing: 6) {
                Text("\(category.reviewCount) review")
                Text("\(category.failedCount) failed")
            }
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(9)
        }
        .frame(maxWidth: .infinity, minHeight: 286, alignment: .top)
        .controlSurface()
    }

    private func categoryTitle(_ category: NodeDiagnosticCategory) -> String {
        switch category {
        case .runtime: "Runtime"
        case .progress: "Chain"
        case .network: "Network"
        case .tooling: "Tooling"
        }
    }
}
