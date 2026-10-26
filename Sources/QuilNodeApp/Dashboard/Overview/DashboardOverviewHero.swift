import QuilNodeCore
import SwiftUI

extension DashboardView {
    func overviewHero(layoutClass: DashboardLayoutClass) -> some View {
        let status = OverviewStatusPresentation(snapshot: monitor.snapshot, phase: monitor.observationPhase)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                overviewStatusCopy(status)
                Spacer(minLength: 20)
                overviewStatusAction(status)
            }
            VStack(alignment: .leading, spacing: 16) {
                overviewStatusCopy(status)
                overviewStatusAction(status)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ThemeHeroBackground() }
        .overlay(alignment: .bottom) { protocolRule(opacity: 0.5) }
    }

    private func overviewStatusCopy(_ status: OverviewStatusPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("YOUR LOCAL NODE", systemImage: "desktopcomputer")
                .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.4)
                .foregroundStyle(theme.colors.secondaryText)
            HStack(spacing: 12) {
                Image(systemName: status.symbol)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(status.needsAttention ? theme.colors.warning : theme.colors.info)
                Text(status.title)
                    .font(
                        .system(
                            size: 30 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign)
                    )
                    .foregroundStyle(theme.colors.primaryText)
            }
            Text(status.detail)
                .font(.callout).foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private func overviewStatusAction(_ status: OverviewStatusPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                if status.workersNeedingReview > 0 {
                    openOverviewNetwork(.observatory)
                } else {
                    destination = .diagnostics
                }
            } label: {
                Label(
                    status.workersNeedingReview > 0
                        ? "Inspect workers" : (status.needsAttention ? "Review diagnostics" : "Open diagnostics"),
                    systemImage: "arrow.right")
            }
            .buttonStyle(.bordered).controlSize(.large)
            PrivacyProtectedText(value: status.freshness.label, field: .localTimestamp)
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
        }
    }
}
