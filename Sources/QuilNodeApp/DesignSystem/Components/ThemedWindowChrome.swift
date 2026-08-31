import AppKit
import SwiftUI

/// A real unified macOS titlebar: the native traffic lights remain untouched,
/// while page identity and the small set of global actions live in the frame.
/// Keeping this separate from scrolling content prevents a duplicate header and
/// makes every theme own the entire window rather than beginning below it.
struct ThemedWindowChrome<Actions: View>: View {
    @Environment(\.quilTheme) private var theme

    let sidebarWidth: CGFloat
    let title: String
    let systemImage: String
    let index: Int
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: sidebarWidth)

            HStack(spacing: 18) {
                brandIdentity
                    .layoutPriority(1)

                Spacer(minLength: 16)

                actions()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, theme.metrics.panelPadding + 8)
            .padding(.trailing, theme.metrics.panelPadding + 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 56)
        .background(theme.colors.canvas.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.border.opacity(0.34))
                .frame(height: max(theme.metrics.borderWidth, 0.5))
                .allowsHitTesting(false)
        }
        .background(WindowChromeConfigurator())
    }

    private var brandIdentity: some View {
        HStack(spacing: 9) {
            ApplicationBrandMark(size: 22, theme: theme)
            Text("QuilNode")
                .font(
                    .system(
                        size: 14 * theme.typography.scale,
                        weight: .semibold,
                        design: theme.typography.displayDesign
                    )
                )
            if theme.recipes.hero != .topology && theme.recipes.hero != .orbital {
                Text("/")
                    .foregroundStyle(theme.colors.border)
                pageIdentity
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("QuilNode, \(title)")
    }

    @ViewBuilder
    private var pageIdentity: some View {
        switch theme.recipes.pageHeader {
        case .native:
            HStack(spacing: 10) {
                Text(title)
                    .font(
                        .system(
                            size: 12 * theme.typography.scale, weight: .medium, design: theme.typography.displayDesign
                        )
                    )
                    .foregroundStyle(theme.colors.secondaryText)
            }

        case .editorial:
            HStack(spacing: 7) {
                Text(String(format: "%02d", index))
                    .foregroundStyle(theme.colors.accent)
                Text("/  \(title.lowercased())")
                    .foregroundStyle(theme.colors.primaryText)
            }
            .font(.system(size: 12 * theme.typography.scale, weight: .semibold, design: .monospaced))
            .tracking(1.1)

        case .output:
            Text(title.uppercased())
                .font(.system(size: 13 * theme.typography.scale, weight: .bold, design: .monospaced))
                .tracking(0.8)
        }
    }

}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configure(view.window)
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unifiedCompact
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
    }
}
