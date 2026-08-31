import AppKit
import SwiftUI

/// Resolves the sealed application icon once and applies it to the running
/// process. The asset catalog is authoritative for Finder, Launchpad, and new
/// launches; the bundled ICNS is retained as a deterministic fallback for the
/// command-line packaging path and for stale Dock caches after an in-place app
/// replacement.
@MainActor
enum ApplicationIcon {
    static func resolvedImage() -> NSImage? {
        if let catalogIcon = NSImage(named: NSImage.applicationIconName),
            catalogIcon.isValid,
            catalogIcon.size.width > 0
        {
            return catalogIcon
        }

        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL),
            icon.isValid
        else { return nil }
        return icon
    }

    static func installForCurrentProcess() {
        guard let icon = resolvedImage() else { return }
        NSApp.applicationIconImage = icon
    }
}

/// A single source of truth for compact branding. Four registered SVG layers
/// preserve the logo geometry while letting each theme own its color hierarchy.
/// Passing one tint collapses the same mark into a native menu-bar template.
struct ApplicationBrandMark: View {
    let size: CGFloat
    let network: Color
    let nodes: Color
    let core: Color
    let qGlyph: Color

    init(size: CGFloat, tint: Color) {
        self.init(size: size, network: tint, nodes: tint, core: tint, qGlyph: tint)
    }

    init(size: CGFloat, network: Color, nodes: Color, core: Color, qGlyph: Color) {
        self.size = size
        self.network = network
        self.nodes = nodes
        self.core = core
        self.qGlyph = qGlyph
    }

    /// The canonical semantic mapping used by every themed app surface. Keep
    /// this here so the dashboard, sidebar, and menu panel cannot drift into
    /// slightly different interpretations of the same four-layer mark.
    init(size: CGFloat, theme: QuilTheme) {
        self.init(
            size: size,
            network: theme.colors.accent,
            nodes: theme.colors.accentSecondary,
            core: theme.colors.success,
            qGlyph: theme.colors.primaryText
        )
    }

    var body: some View {
        ZStack {
            layer("QuilNodeBrandNetwork", color: network)
            layer("QuilNodeBrandNodes", color: nodes)
            layer("QuilNodeBrandCore", color: core)
            layer("QuilNodeBrandQ", color: qGlyph)
        }
        .frame(width: size, height: size)
        .clipped()
        .compositingGroup()
        .accessibilityHidden(true)
    }

    private func layer(_ name: String, color: Color) -> some View {
        image(named: name)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(color)
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func image(named name: String) -> Image {
        #if DEBUG
            // SwiftPM visual tests register the source SVGs because they do
            // not package the Xcode asset catalog. Release lookup is unchanged.
            if let image = NSImage(named: name) { return Image(nsImage: image) }
        #endif
        return Image(name)
    }
}

/// Status-item artwork intentionally uses one flattened template image. AppKit
/// owns its contrast, while avoiding multi-layer SVG drawing outside the very
/// small layout host used by `MenuBarExtra`.
struct MenuBarBrandMark: View {
    let size: CGFloat

    private static let templateImage: NSImage? = {
        guard let source = NSImage(named: "QuilNodeBrandMark"),
            let image = source.copy() as? NSImage
        else { return nil }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }()

    @ViewBuilder
    var body: some View {
        if let image = Self.templateImage {
            Image(nsImage: image)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Text("Q")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}
