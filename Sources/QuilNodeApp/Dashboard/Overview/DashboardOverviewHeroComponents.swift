import SwiftUI

struct ProtocolStatusCheck: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(minHeight: 32)
            .background(theme.colors.surface.opacity(0.74))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(tint.opacity(0.36), lineWidth: max(theme.metrics.borderWidth, 0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

extension View {
    func protocolLabelStyle(color: Color) -> some View {
        font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.25)
            .foregroundStyle(color)
    }
}
