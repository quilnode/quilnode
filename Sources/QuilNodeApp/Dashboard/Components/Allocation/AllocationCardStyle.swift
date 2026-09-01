import SwiftUI

extension View {
    func protocolSectionLabel(color: Color) -> some View {
        font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(color)
    }
}
