import SwiftUI

struct DashboardCircleIcon: View {
    let systemImage: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
