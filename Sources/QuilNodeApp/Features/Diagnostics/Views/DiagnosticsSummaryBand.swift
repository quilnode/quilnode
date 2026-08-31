import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticsSummaryBand: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass
    let report: NodeDiagnosticReport
    let presentation: DiagnosticsPresentation
    let isScanning: Bool
    let scanStage: String
    let lastScanAt: Date?

    var body: some View {
        Group {
            if dashboardLayoutClass.isCompact {
                VStack(alignment: .leading, spacing: 0) {
                    overallSummary.padding(.vertical, 11)
                    Divider()
                    HStack(spacing: 0) {
                        count("Passed", presentation.passedCount, theme.colors.success)
                        count("Waiting", presentation.waitingCount, theme.colors.info)
                        count("Review", presentation.reviewCount, theme.colors.warning)
                        count("Action", presentation.failedCount, theme.colors.danger)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    Divider()
                    scanSummary.padding(.vertical, 11)
                }
            } else {
                HStack(spacing: 0) {
                    overallSummary
                    divider
                    count("Passed", presentation.passedCount, theme.colors.success)
                    count("Waiting", presentation.waitingCount, theme.colors.info)
                    count("Review", presentation.reviewCount, theme.colors.warning)
                    count("Action", presentation.failedCount, theme.colors.danger)
                    divider
                    scanSummary.frame(width: 210, alignment: .leading)
                }
            }
        }
        .padding(.vertical, dashboardLayoutClass.isCompact ? 0 : 11)
        .controlSurface(tint: overallTint)
    }

    private var overallSummary: some View {
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scanSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isScanning ? "SCAN IN PROGRESS" : "LAST FULL CHECK")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Text(isScanning ? scanStage : (lastScanAt?.formatted(date: .omitted, time: .standard) ?? "Not run"))
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if isScanning {
                ProgressView().controlSize(.small)
            } else {
                Text("Current local evidence").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func count(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(String(value)).font(.headline.bold().monospacedDigit()).foregroundStyle(tint)
            Text(title.uppercased()).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
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
        case .waiting: return "Waiting for protocol progress"
        case .advisory: return "Review recommended"
        case .failed: return "Action required"
        }
    }

    private var overallDetail: String {
        switch report.overallState {
        case .checking: "No failure is declared before its probe completes."
        case .passed: "No local repair is recommended."
        case .waiting: "Expected waiting is not a local failure. Inspect the pending checks below."
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
