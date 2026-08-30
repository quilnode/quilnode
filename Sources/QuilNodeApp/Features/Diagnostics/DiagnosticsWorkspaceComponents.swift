import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticsSummaryBand: View {
    @Environment(\.quilTheme) private var theme
    let report: NodeDiagnosticReport
    let presentation: DiagnosticsPresentation
    let isScanning: Bool
    let scanStage: String
    let lastScanAt: Date?

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(overallTint.opacity(0.13))
                    if isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: overallIcon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(overallTint)
                    }
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(overallTitle).font(.headline)
                    Text(overallDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            divider
            count("Passed", presentation.passedCount, theme.colors.success)
            count("Waiting", presentation.waitingCount, theme.colors.info)
            count("Review", presentation.reviewCount, theme.colors.warning)
            count("Action", presentation.failedCount, theme.colors.danger)
            divider

            VStack(alignment: .leading, spacing: 4) {
                Text(isScanning ? "SCAN IN PROGRESS" : "LAST FULL CHECK")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(isScanning ? scanStage : (lastScanAt?.formatted(date: .omitted, time: .standard) ?? "Not run"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Current local evidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(width: 210, alignment: .leading)
        }
        .padding(.vertical, 11)
        .controlSurface(tint: overallTint)
    }

    private func count(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(String(value)).font(.headline.bold().monospacedDigit()).foregroundStyle(tint)
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 68)
    }

    private var divider: some View {
        Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1, height: 54)
    }

    private var overallTitle: String {
        if isScanning { return "Running local checks" }
        switch report.overallState {
        case .checking: return "Evidence collecting"
        case .passed: return "All tested systems are ready"
        case .waiting: return "Shared recovery in progress"
        case .advisory: return "Review recommended"
        case .failed: return "Action required"
        }
    }

    private var overallDetail: String {
        switch report.overallState {
        case .checking: "No failure is declared before its probe completes."
        case .passed: "No local repair is recommended."
        case .waiting: "Keep the healthy node running while shared state recovers."
        case .advisory: "The node can continue; inspect the prioritized findings."
        case .failed: "A readiness condition failed; use the scoped repair."
        }
    }

    private var overallTint: Color {
        switch report.overallState {
        case .checking, .waiting: theme.colors.info
        case .passed: theme.colors.success
        case .advisory: theme.colors.warning
        case .failed: theme.colors.danger
        }
    }

    private var overallIcon: String {
        switch report.overallState {
        case .checking: "ellipsis.circle.fill"
        case .passed: "checkmark.seal.fill"
        case .waiting: "hourglass.circle.fill"
        case .advisory: "exclamationmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }
}

struct DiagnosticsFindingsQueue: View {
    @Environment(\.quilTheme) private var theme
    let findings: [NodeDiagnosticCheck]
    let selectedID: String?
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
                                Label(check.title, systemImage: diagnosticIcon(check.state))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(diagnosticStateLabel(check.state))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(diagnosticTint(check.state, theme: theme))
                            }
                            Text(check.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
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
                                ? diagnosticTint(check.state, theme: theme).opacity(0.075)
                                : Color.clear
                        )
                    }
                    .buttonStyle(QuilPressFeedbackButtonStyle())
                    Divider()
                }
            }
        }
        .frame(width: 278, alignment: .top)
        .frame(minHeight: 286, alignment: .top)
        .controlSurface(tint: findings.isEmpty ? theme.colors.success : theme.colors.warning)
    }
}

struct DiagnosticsProofMatrix: View {
    @Environment(\.quilTheme) private var theme
    let categories: [DiagnosticCategoryPresentation]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(categories) { category in
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
                                Image(systemName: diagnosticIcon(check.state))
                                    .foregroundStyle(diagnosticTint(check.state, theme: theme))
                                Text(check.title)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(2)
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
        }
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

func diagnosticTint(_ state: NodeDiagnosticState, theme: QuilTheme) -> Color {
    switch state {
    case .checking, .waiting: theme.colors.info
    case .passed: theme.colors.success
    case .advisory: theme.colors.warning
    case .failed: theme.colors.danger
    }
}

func diagnosticIcon(_ state: NodeDiagnosticState) -> String {
    switch state {
    case .checking: "ellipsis.circle"
    case .passed: "checkmark.circle.fill"
    case .waiting: "hourglass.circle.fill"
    case .advisory: "exclamationmark.circle.fill"
    case .failed: "xmark.octagon.fill"
    }
}

func diagnosticStateLabel(_ state: NodeDiagnosticState) -> String {
    switch state {
    case .checking: "CHECKING"
    case .passed: "PASS"
    case .waiting: "WAITING"
    case .advisory: "REVIEW"
    case .failed: "ACTION"
    }
}
