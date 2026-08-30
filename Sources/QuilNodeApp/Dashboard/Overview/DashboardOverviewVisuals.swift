import SwiftUI

extension DashboardView {
    var protocolSignal: Color { theme.colors.info }

    func protocolRule(opacity: Double) -> some View {
        Rectangle()
            .fill(theme.colors.border.opacity(opacity))
            .frame(height: max(theme.metrics.borderWidth, 0.5))
            .allowsHitTesting(false)
    }
}
