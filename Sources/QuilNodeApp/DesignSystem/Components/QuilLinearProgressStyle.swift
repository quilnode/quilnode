import SwiftUI

/// Explicit theme color for determinate progress on macOS, independent of the
/// system accent or inactive-window tint. Unknown progress keeps the native spinner.
struct QuilLinearProgressStyle: ProgressViewStyle {
    @Environment(\.quilTheme) private var theme
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
            if let fraction = configuration.fractionCompleted {
                GeometryReader { geometry in
                    Capsule()
                        .fill(theme.colors.border.opacity(0.35))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(tint)
                                .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                        }
                }
                .frame(height: 8)
                .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
            } else {
                ProgressView().progressViewStyle(.circular).controlSize(.small)
            }
            configuration.currentValueLabel
        }
    }
}
