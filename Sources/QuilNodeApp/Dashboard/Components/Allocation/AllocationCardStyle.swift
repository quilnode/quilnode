import SwiftUI

extension View {
    func protocolSectionLabel(color: Color) -> some View {
        font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(color)
    }

    func allocationCellSurface(theme: QuilTheme, borderColor: Color? = nil) -> some View {
        padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(theme.colors.surface.opacity(0.46))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        borderColor ?? theme.colors.border.opacity(0.48),
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    func protocolAllocationCardSurface(
        theme: QuilTheme,
        borderColor: Color,
        emphasized: Bool
    ) -> some View {
        padding(.horizontal, 11)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(theme.colors.surface.opacity(emphasized ? 0.78 : 0.48))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
