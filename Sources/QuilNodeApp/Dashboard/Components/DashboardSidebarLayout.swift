import SwiftUI

/// Padding must precede the outer flexible frame. Reversing these modifiers
/// makes the section wider than the sidebar and visually shifts the rail.
extension View {
    func sidebarSection(inset: CGFloat) -> some View {
        padding(.horizontal, inset)
            .frame(maxWidth: .infinity)
    }
}
