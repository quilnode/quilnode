import AppKit
import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

/// Fully resolved runtime theme. Files are decoded into data-only documents and
/// then resolved here, so views never need to know where a theme came from.
struct QuilTheme: Identifiable {
    let id: String
    let familyID: String
    let name: String
    let author: String
    let version: String
    let appearance: QuilThemeAppearance
    let summary: String?
    let tags: [String]
    let colors: Colors
    let metrics: Metrics
    let typography: Typography
    let components: Components
    let recipes: Recipes
    let isBuiltIn: Bool

    struct Colors {
        var accent: Color
        var accentSecondary: Color
        var selection: Color
        var muted: Color
        var success: Color
        var warning: Color
        var danger: Color
        var info: Color
        var privacy: Color
        var frame: Color
        var wallet: Color
        var canvas: Color
        var sidebar: Color
        var surface: Color
        var surfaceElevated: Color
        var border: Color
        var primaryText: Color
        var secondaryText: Color

        var pickerSwatches: [Color] { [accent, accentSecondary, success, warning, danger] }

        func applying(_ overrides: QuilThemeColorOverrides) -> Self {
            var copy = self
            copy.accent = Color(themeValue: overrides.accent, fallback: accent)
            copy.accentSecondary = Color(themeValue: overrides.accentSecondary, fallback: accentSecondary)
            copy.success = Color(themeValue: overrides.success, fallback: success)
            copy.warning = Color(themeValue: overrides.warning, fallback: warning)
            copy.danger = Color(themeValue: overrides.danger, fallback: danger)
            copy.info = Color(themeValue: overrides.info, fallback: info)
            copy.privacy = Color(themeValue: overrides.privacy, fallback: privacy)
            copy.frame = Color(themeValue: overrides.frame, fallback: frame)
            copy.wallet = Color(themeValue: overrides.wallet, fallback: wallet)
            copy.canvas = Color(themeValue: overrides.canvas, fallback: canvas)
            copy.sidebar = Color(themeValue: overrides.sidebar, fallback: sidebar)
            copy.surface = Color(themeValue: overrides.surface, fallback: surface)
            copy.surfaceElevated = Color(themeValue: overrides.surfaceElevated, fallback: surfaceElevated)
            copy.border = Color(themeValue: overrides.border, fallback: border)
            copy.primaryText = Color(themeValue: overrides.primaryText, fallback: primaryText)
            copy.secondaryText = Color(themeValue: overrides.secondaryText, fallback: secondaryText)
            return copy
        }

        func applying(_ palette: QuilThemePaletteDocument) -> Self {
            var copy = self
            copy.accent = Color(themeValue: palette.accent, fallback: accent)
            copy.accentSecondary = Color(themeValue: palette.magenta ?? palette.blue, fallback: accentSecondary)
            copy.selection = Color(themeValue: palette.selection, fallback: selection)
            copy.muted = Color(themeValue: palette.muted, fallback: muted)
            copy.success = Color(themeValue: palette.green, fallback: success)
            copy.warning = Color(themeValue: palette.yellow, fallback: warning)
            copy.danger = Color(themeValue: palette.red, fallback: danger)
            copy.info = Color(themeValue: palette.cyan ?? palette.blue, fallback: info)
            copy.privacy = Color(themeValue: palette.privacy ?? palette.magenta, fallback: privacy)
            copy.frame = Color(themeValue: palette.frame ?? palette.orange, fallback: frame)
            copy.wallet = Color(themeValue: palette.wallet ?? palette.cyan, fallback: wallet)
            copy.canvas = Color(themeValue: palette.background, fallback: canvas)
            copy.sidebar = Color(themeValue: palette.darkBackground, fallback: sidebar)
            copy.surface = Color(themeValue: palette.lighterBackground, fallback: surface)
            copy.surfaceElevated = Color(themeValue: palette.selection, fallback: surfaceElevated)
            copy.border = Color(themeValue: palette.muted, fallback: border)
            copy.primaryText = Color(themeValue: palette.foreground, fallback: primaryText)
            copy.secondaryText = Color(
                themeValue: palette.darkForeground ?? palette.lightForeground, fallback: secondaryText)
            return copy
        }
    }

    struct Metrics {
        var sidebarCollapsedWidth: CGFloat
        var sidebarExpandedWidth: CGFloat
        var navigationRowHeight: CGFloat
        var controlCornerRadius: CGFloat
        var heroCornerRadius: CGFloat
        var spacingScale: CGFloat
        var borderWidth: CGFloat
        var navigationCornerRadius: CGFloat
        var panelPadding: CGFloat
        var panelGap: CGFloat

        func applying(_ overrides: QuilThemeMetricOverrides) -> Self {
            var copy = self
            copy.sidebarCollapsedWidth = overrides.sidebarCollapsedWidth.map { CGFloat($0) } ?? sidebarCollapsedWidth
            copy.sidebarExpandedWidth = overrides.sidebarExpandedWidth.map { CGFloat($0) } ?? sidebarExpandedWidth
            copy.navigationRowHeight = overrides.navigationRowHeight.map { CGFloat($0) } ?? navigationRowHeight
            copy.controlCornerRadius = overrides.controlCornerRadius.map { CGFloat($0) } ?? controlCornerRadius
            copy.heroCornerRadius = overrides.heroCornerRadius.map { CGFloat($0) } ?? heroCornerRadius
            copy.spacingScale = overrides.spacingScale.map { CGFloat($0) } ?? spacingScale
            copy.borderWidth = overrides.borderWidth.map { CGFloat($0) } ?? borderWidth
            return copy
        }

        func applying(_ style: QuilThemeStyleDocument) -> Self {
            var copy = self
            copy.sidebarCollapsedWidth =
                style.spacing.sidebarCollapsedWidth.map { CGFloat($0) } ?? sidebarCollapsedWidth
            copy.sidebarExpandedWidth = style.spacing.sidebarExpandedWidth.map { CGFloat($0) } ?? sidebarExpandedWidth
            copy.navigationRowHeight = style.spacing.navigationRowHeight.map { CGFloat($0) } ?? navigationRowHeight
            copy.panelPadding = style.spacing.panelPadding.map { CGFloat($0) } ?? panelPadding
            copy.panelGap = style.spacing.panelGap.map { CGFloat($0) } ?? panelGap
            copy.spacingScale = style.spacing.scale.map { CGFloat($0) } ?? spacingScale
            copy.controlCornerRadius = style.corners.control.map { CGFloat($0) } ?? controlCornerRadius
            copy.heroCornerRadius = style.corners.hero.map { CGFloat($0) } ?? heroCornerRadius
            copy.navigationCornerRadius = style.corners.navigation.map { CGFloat($0) } ?? navigationCornerRadius
            copy.borderWidth = style.controls.selectedBorderWidth.map { CGFloat($0) } ?? borderWidth
            return copy
        }
    }

    struct Typography {
        var scale: CGFloat
        var displayDesign: Font.Design
        var dataDesign: Font.Design

        func applying(_ overrides: QuilThemeTypographyOverrides) -> Self {
            .init(
                scale: overrides.scale.map { CGFloat($0) } ?? scale,
                displayDesign: Font.Design(themeValue: overrides.displayDesign) ?? displayDesign,
                dataDesign: Font.Design(themeValue: overrides.dataDesign) ?? dataDesign
            )
        }

        func applying(_ style: QuilThemeStyleDocument) -> Self {
            .init(
                scale: style.typography.scale.map { CGFloat($0) } ?? scale,
                displayDesign: Font.Design(themeValue: style.typography.displayDesign) ?? displayDesign,
                dataDesign: Font.Design(themeValue: style.typography.dataDesign) ?? dataDesign
            )
        }
    }

    struct Components {
        enum NavigationSelection: String { case row, capsule, icon }
        enum RingStyle: String { case gradient, solid }
        enum SurfaceTreatment: String { case material, tinted, solid }
        enum SurfaceBorderStyle: String { case solid, dashed }
        enum BackdropStyle: String { case solid, gradient, spotlight }
        enum DecorationStyle: String { case none, grid, dots, scanlines }
        enum SceneStyle: String { case none, orbital }
        enum ShadowStyle: String { case none, soft, glow }
        enum AccentTreatment: String { case solid, gradient }

        var navigationSelection: NavigationSelection
        var ringStyle: RingStyle
        var surfaceTreatment: SurfaceTreatment
        var surfaceBorderStyle: SurfaceBorderStyle = .solid
        var backdropStyle: BackdropStyle = .solid
        var decorationStyle: DecorationStyle = .none
        var shadowStyle: ShadowStyle = .soft
        var accentTreatment: AccentTreatment = .gradient
        var selectionFillAlpha: Double
        var selectedBorderWidth: CGFloat
        var iconScale: CGFloat
        var ringThickness: CGFloat
        var surfaceOpacity: Double
        var elevatedOpacity: Double
        var borderOpacity: Double
        var heroAccentOpacity: Double
        var decorationOpacity: Double = 0
        var sceneStyle: SceneStyle = .orbital
        var sceneOpacity: Double = 0.58
        var shadowOpacity: Double = 0.14
        var motionScale: Double = 1

        func applying(_ style: QuilThemeStyleDocument) -> Self {
            var copy = self
            copy.navigationSelection =
                style.controls.navigationSelectionStyle.flatMap(NavigationSelection.init(rawValue:))
                ?? navigationSelection
            copy.ringStyle = style.controls.ringStyle.flatMap(RingStyle.init(rawValue:)) ?? ringStyle
            copy.surfaceTreatment =
                style.surfaces.treatment.flatMap(SurfaceTreatment.init(rawValue:)) ?? surfaceTreatment
            copy.surfaceBorderStyle =
                style.surfaces.borderStyle.flatMap(SurfaceBorderStyle.init(rawValue:)) ?? surfaceBorderStyle
            copy.backdropStyle = style.effects.backdrop.flatMap(BackdropStyle.init(rawValue:)) ?? backdropStyle
            copy.decorationStyle = style.effects.decoration.flatMap(DecorationStyle.init(rawValue:)) ?? decorationStyle
            copy.shadowStyle = style.effects.shadow.flatMap(ShadowStyle.init(rawValue:)) ?? shadowStyle
            copy.accentTreatment =
                style.effects.accentTreatment.flatMap(AccentTreatment.init(rawValue:)) ?? accentTreatment
            copy.selectionFillAlpha = style.controls.selectionFillAlpha ?? selectionFillAlpha
            copy.selectedBorderWidth = style.controls.selectedBorderWidth.map { CGFloat($0) } ?? selectedBorderWidth
            copy.iconScale = style.controls.iconScale.map { CGFloat($0) } ?? iconScale
            copy.ringThickness = style.controls.ringThickness.map { CGFloat($0) } ?? ringThickness
            copy.surfaceOpacity = style.surfaces.surfaceOpacity ?? surfaceOpacity
            copy.elevatedOpacity = style.surfaces.elevatedOpacity ?? elevatedOpacity
            copy.borderOpacity = style.surfaces.borderOpacity ?? borderOpacity
            copy.heroAccentOpacity = style.surfaces.heroAccentOpacity ?? heroAccentOpacity
            copy.decorationOpacity = style.effects.decorationOpacity ?? decorationOpacity
            copy.sceneStyle = style.effects.scene.flatMap(SceneStyle.init(rawValue:)) ?? sceneStyle
            copy.sceneOpacity = style.effects.sceneOpacity ?? sceneOpacity
            copy.shadowOpacity = style.effects.shadowOpacity ?? shadowOpacity
            copy.motionScale = style.effects.motionScale ?? motionScale
            return copy
        }
    }

    struct Recipes {
        enum PageHeader: String { case native, editorial, output }
        enum SidebarBrand: String { case tile, wordmark, index }
        enum Hero: String { case card, orbital, topology, plate, terminal }
        enum MetricStrip: String { case band, ruled, cells }
        enum Panel: String { case card, ruled, terminal }
        enum Badge: String { case capsule, label, stamp }
        enum DataLabels: String { case human, registry, terminal }

        var pageHeader: PageHeader = .native
        var sidebarBrand: SidebarBrand = .tile
        var hero: Hero = .card
        var metricStrip: MetricStrip = .band
        var panel: Panel = .card
        var badge: Badge = .capsule
        var dataLabels: DataLabels = .human

        func applying(_ style: QuilThemeStyleDocument) -> Self {
            var copy = self
            copy.pageHeader = style.composition.pageHeader.flatMap(PageHeader.init(rawValue:)) ?? pageHeader
            copy.sidebarBrand = style.composition.sidebarBrand.flatMap(SidebarBrand.init(rawValue:)) ?? sidebarBrand
            copy.hero = style.composition.hero.flatMap(Hero.init(rawValue:)) ?? hero
            copy.metricStrip = style.composition.metricStrip.flatMap(MetricStrip.init(rawValue:)) ?? metricStrip
            copy.panel = style.composition.panel.flatMap(Panel.init(rawValue:)) ?? panel
            copy.badge = style.composition.badge.flatMap(Badge.init(rawValue:)) ?? badge
            copy.dataLabels = style.composition.dataLabels.flatMap(DataLabels.init(rawValue:)) ?? dataLabels
            return copy
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    func applying(_ manifest: QuilThemeManifest) -> QuilTheme {
        .init(
            id: manifest.id, familyID: manifest.id, name: manifest.name, author: manifest.author,
            version: manifest.version,
            appearance: manifest.appearance ?? appearance, summary: nil, tags: [],
            colors: colors.applying(manifest.colors), metrics: metrics.applying(manifest.metrics),
            typography: typography.applying(manifest.typography), components: components, recipes: recipes,
            isBuiltIn: false
        )
    }

    func applying(_ pack: QuilThemePack) -> QuilTheme {
        .init(
            id: pack.metadata.id, familyID: pack.metadata.id, name: pack.metadata.name, author: pack.metadata.author,
            version: pack.metadata.version, appearance: pack.metadata.appearance,
            summary: pack.metadata.summary, tags: pack.metadata.tags,
            colors: colors.applying(pack.colors), metrics: metrics.applying(pack.style),
            typography: typography.applying(pack.style), components: components.applying(pack.style),
            recipes: recipes.applying(pack.style),
            isBuiltIn: false
        )
    }

    func applying(
        familyID: String,
        variantID: String,
        appearance: QuilThemeAppearance,
        colors variantColors: QuilThemePaletteDocument,
        style variantStyle: QuilThemeStyleDocument
    ) -> QuilTheme {
        .init(
            id: variantID, familyID: familyID, name: name, author: author, version: version,
            appearance: appearance, summary: summary, tags: tags,
            colors: colors.applying(variantColors), metrics: metrics.applying(variantStyle),
            typography: typography.applying(variantStyle), components: components.applying(variantStyle),
            recipes: recipes.applying(variantStyle), isBuiltIn: isBuiltIn
        )
    }
}

extension Color {
    init(themeValue: String?, fallback: Color) {
        guard let themeValue else {
            self = fallback
            return
        }
        if themeValue.hasPrefix("system:") {
            switch themeValue {
            case "system:accent": self = .accentColor
            case "system:primary": self = .primary
            case "system:secondary": self = .secondary
            case "system:window": self = Color(nsColor: .windowBackgroundColor)
            case "system:control": self = Color(nsColor: .controlBackgroundColor)
            case "system:separator": self = Color(nsColor: .separatorColor)
            default: self = fallback
            }
            return
        }
        let raw = themeValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard (raw.count == 6 || raw.count == 8), let value = UInt64(raw, radix: 16) else {
            self = fallback
            return
        }
        let red = Double((value >> (raw.count == 8 ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (raw.count == 8 ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (raw.count == 8 ? 8 : 0)) & 0xFF) / 255
        let alpha = raw.count == 8 ? Double(value & 0xFF) / 255 : 1
        self = Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Font.Design {
    init?(themeValue: String?) {
        guard let themeValue else { return nil }
        switch themeValue.lowercased() {
        case "default": self = .default
        case "rounded": self = .rounded
        case "serif": self = .serif
        case "monospaced": self = .monospaced
        default: return nil
        }
    }
}
