import Foundation

/// Structural and component-level tokens stored in `<name>.quiltheme/style.json`.
public struct QuilThemeStyleDocument: Codable, Hashable, Sendable {
    public var spacing: Spacing
    public var corners: Corners
    public var controls: Controls
    public var surfaces: Surfaces
    public var typography: Typography
    public var effects: Effects
    public var composition: Composition

    public init(
        spacing: Spacing = .init(),
        corners: Corners = .init(),
        controls: Controls = .init(),
        surfaces: Surfaces = .init(),
        typography: Typography = .init(),
        effects: Effects = .init(),
        composition: Composition = .init()
    ) {
        self.spacing = spacing
        self.corners = corners
        self.controls = controls
        self.surfaces = surfaces
        self.typography = typography
        self.effects = effects
        self.composition = composition
    }

    private enum CodingKeys: String, CodingKey {
        case spacing, corners, controls, surfaces, typography, effects, composition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spacing = try container.decodeIfPresent(Spacing.self, forKey: .spacing) ?? .init()
        corners = try container.decodeIfPresent(Corners.self, forKey: .corners) ?? .init()
        controls = try container.decodeIfPresent(Controls.self, forKey: .controls) ?? .init()
        surfaces = try container.decodeIfPresent(Surfaces.self, forKey: .surfaces) ?? .init()
        typography = try container.decodeIfPresent(Typography.self, forKey: .typography) ?? .init()
        effects = try container.decodeIfPresent(Effects.self, forKey: .effects) ?? .init()
        composition = try container.decodeIfPresent(Composition.self, forKey: .composition) ?? .init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spacing, forKey: .spacing)
        try container.encode(corners, forKey: .corners)
        try container.encode(controls, forKey: .controls)
        try container.encode(surfaces, forKey: .surfaces)
        try container.encode(typography, forKey: .typography)
        try container.encode(effects, forKey: .effects)
        try container.encode(composition, forKey: .composition)
    }

    public struct Spacing: Codable, Hashable, Sendable {
        public var scale: Double?
        public var sidebarCollapsedWidth: Double?
        public var sidebarExpandedWidth: Double?
        public var navigationRowHeight: Double?
        public var panelPadding: Double?
        public var panelGap: Double?

        public init(
            scale: Double? = nil, sidebarCollapsedWidth: Double? = nil, sidebarExpandedWidth: Double? = nil,
            navigationRowHeight: Double? = nil, panelPadding: Double? = nil, panelGap: Double? = nil
        ) {
            self.scale = scale
            self.sidebarCollapsedWidth = sidebarCollapsedWidth
            self.sidebarExpandedWidth = sidebarExpandedWidth
            self.navigationRowHeight = navigationRowHeight
            self.panelPadding = panelPadding
            self.panelGap = panelGap
        }
    }

    public struct Corners: Codable, Hashable, Sendable {
        public var control: Double?
        public var hero: Double?
        public var navigation: Double?
        public init(control: Double? = nil, hero: Double? = nil, navigation: Double? = nil) {
            self.control = control
            self.hero = hero
            self.navigation = navigation
        }
    }

    public struct Controls: Codable, Hashable, Sendable {
        public var navigationSelectionStyle: String?
        public var selectionFillAlpha: Double?
        public var selectedBorderWidth: Double?
        public var iconScale: Double?
        public var ringStyle: String?
        public var ringThickness: Double?

        public init(
            navigationSelectionStyle: String? = nil, selectionFillAlpha: Double? = nil,
            selectedBorderWidth: Double? = nil, iconScale: Double? = nil, ringStyle: String? = nil,
            ringThickness: Double? = nil
        ) {
            self.navigationSelectionStyle = navigationSelectionStyle
            self.selectionFillAlpha = selectionFillAlpha
            self.selectedBorderWidth = selectedBorderWidth
            self.iconScale = iconScale
            self.ringStyle = ringStyle
            self.ringThickness = ringThickness
        }
    }

    public struct Surfaces: Codable, Hashable, Sendable {
        public var treatment: String?
        public var borderStyle: String?
        public var surfaceOpacity: Double?
        public var elevatedOpacity: Double?
        public var borderOpacity: Double?
        public var heroAccentOpacity: Double?

        public init(
            treatment: String? = nil, borderStyle: String? = nil, surfaceOpacity: Double? = nil,
            elevatedOpacity: Double? = nil, borderOpacity: Double? = nil, heroAccentOpacity: Double? = nil
        ) {
            self.treatment = treatment
            self.borderStyle = borderStyle
            self.surfaceOpacity = surfaceOpacity
            self.elevatedOpacity = elevatedOpacity
            self.borderOpacity = borderOpacity
            self.heroAccentOpacity = heroAccentOpacity
        }
    }

    public struct Typography: Codable, Hashable, Sendable {
        public var scale: Double?
        public var displayDesign: String?
        public var dataDesign: String?
        public init(scale: Double? = nil, displayDesign: String? = nil, dataDesign: String? = nil) {
            self.scale = scale
            self.displayDesign = displayDesign
            self.dataDesign = dataDesign
        }
    }

    /// Atmosphere and rendering tokens. These remain declarative and bounded:
    /// a theme can change how shared primitives render, but cannot ship code.
    public struct Effects: Codable, Hashable, Sendable {
        public var backdrop: String?
        public var decoration: String?
        public var decorationOpacity: Double?
        public var scene: String?
        public var sceneOpacity: Double?
        public var shadow: String?
        public var shadowOpacity: Double?
        public var accentTreatment: String?
        public var motionScale: Double?

        public init(
            backdrop: String? = nil,
            decoration: String? = nil,
            decorationOpacity: Double? = nil,
            shadow: String? = nil,
            shadowOpacity: Double? = nil,
            accentTreatment: String? = nil,
            motionScale: Double? = nil,
            scene: String? = nil,
            sceneOpacity: Double? = nil
        ) {
            self.backdrop = backdrop
            self.decoration = decoration
            self.decorationOpacity = decorationOpacity
            self.scene = scene
            self.sceneOpacity = sceneOpacity
            self.shadow = shadow
            self.shadowOpacity = shadowOpacity
            self.accentTreatment = accentTreatment
            self.motionScale = motionScale
        }
    }

    /// Bounded component recipes let a theme alter hierarchy and visual
    /// composition without changing dashboard content or executing code.
    public struct Composition: Codable, Hashable, Sendable {
        public var pageHeader: String?
        public var sidebarBrand: String?
        public var hero: String?
        public var metricStrip: String?
        public var panel: String?
        public var badge: String?
        public var dataLabels: String?

        public init(
            pageHeader: String? = nil,
            sidebarBrand: String? = nil,
            hero: String? = nil,
            metricStrip: String? = nil,
            panel: String? = nil,
            badge: String? = nil,
            dataLabels: String? = nil
        ) {
            self.pageHeader = pageHeader
            self.sidebarBrand = sidebarBrand
            self.hero = hero
            self.metricStrip = metricStrip
            self.panel = panel
            self.badge = badge
            self.dataLabels = dataLabels
        }
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []
        if let value = spacing.scale, !(0.8...1.35).contains(value) {
            issues.append("style.spacing.scale must be between 0.8 and 1.35.")
        }
        if let value = spacing.sidebarCollapsedWidth, !(56...96).contains(value) {
            issues.append("style.spacing.sidebarCollapsedWidth must be between 56 and 96.")
        }
        if let value = spacing.sidebarExpandedWidth, !(160...320).contains(value) {
            issues.append("style.spacing.sidebarExpandedWidth must be between 160 and 320.")
        }
        if let value = spacing.navigationRowHeight, !(36...64).contains(value) {
            issues.append("style.spacing.navigationRowHeight must be between 36 and 64.")
        }
        if let value = spacing.panelPadding, !(10...32).contains(value) {
            issues.append("style.spacing.panelPadding must be between 10 and 32.")
        }
        if let value = spacing.panelGap, !(6...28).contains(value) {
            issues.append("style.spacing.panelGap must be between 6 and 28.")
        }
        if let value = corners.control, !(0...32).contains(value) {
            issues.append("style.corners.control must be between 0 and 32.")
        }
        if let value = corners.hero, !(0...40).contains(value) {
            issues.append("style.corners.hero must be between 0 and 40.")
        }
        if let value = corners.navigation, !(0...24).contains(value) {
            issues.append("style.corners.navigation must be between 0 and 24.")
        }
        if let value = controls.navigationSelectionStyle, !["row", "capsule", "icon"].contains(value) {
            issues.append("style.controls.navigationSelectionStyle must be row, capsule, or icon.")
        }
        if let value = controls.ringStyle, !["gradient", "solid"].contains(value) {
            issues.append("style.controls.ringStyle must be gradient or solid.")
        }
        if let value = controls.selectionFillAlpha, !(0...0.4).contains(value) {
            issues.append("style.controls.selectionFillAlpha must be between 0 and 0.4.")
        }
        if let value = controls.selectedBorderWidth, !(0...3).contains(value) {
            issues.append("style.controls.selectedBorderWidth must be between 0 and 3.")
        }
        if let value = controls.iconScale, !(0.8...1.3).contains(value) {
            issues.append("style.controls.iconScale must be between 0.8 and 1.3.")
        }
        if let value = controls.ringThickness, !(5...18).contains(value) {
            issues.append("style.controls.ringThickness must be between 5 and 18.")
        }
        if let value = surfaces.treatment, !["material", "tinted", "solid"].contains(value) {
            issues.append("style.surfaces.treatment must be material, tinted, or solid.")
        }
        if let value = surfaces.borderStyle, !["solid", "dashed"].contains(value) {
            issues.append("style.surfaces.borderStyle must be solid or dashed.")
        }
        for (name, value) in [
            ("surfaceOpacity", surfaces.surfaceOpacity), ("elevatedOpacity", surfaces.elevatedOpacity),
            ("borderOpacity", surfaces.borderOpacity), ("heroAccentOpacity", surfaces.heroAccentOpacity),
        ] {
            if let value, !(0...1).contains(value) { issues.append("style.surfaces.\(name) must be between 0 and 1.") }
        }
        if let value = typography.scale, !(0.85...1.25).contains(value) {
            issues.append("style.typography.scale must be between 0.85 and 1.25.")
        }
        if let value = typography.displayDesign, !["default", "rounded", "serif", "monospaced"].contains(value) {
            issues.append("style.typography.displayDesign must be default, rounded, serif, or monospaced.")
        }
        if let value = typography.dataDesign, !["default", "rounded", "serif", "monospaced"].contains(value) {
            issues.append("style.typography.dataDesign must be default, rounded, serif, or monospaced.")
        }
        if let value = effects.backdrop, !["solid", "gradient", "spotlight"].contains(value) {
            issues.append("style.effects.backdrop must be solid, gradient, or spotlight.")
        }
        if let value = effects.decoration, !["none", "grid", "dots", "scanlines"].contains(value) {
            issues.append("style.effects.decoration must be none, grid, dots, or scanlines.")
        }
        if let value = effects.decorationOpacity, !(0...0.25).contains(value) {
            issues.append("style.effects.decorationOpacity must be between 0 and 0.25.")
        }
        if let value = effects.scene, !["none", "orbital"].contains(value) {
            issues.append("style.effects.scene must be none or orbital.")
        }
        if let value = effects.sceneOpacity, !(0...1).contains(value) {
            issues.append("style.effects.sceneOpacity must be between 0 and 1.")
        }
        if let value = effects.shadow, !["none", "soft", "glow"].contains(value) {
            issues.append("style.effects.shadow must be none, soft, or glow.")
        }
        if let value = effects.shadowOpacity, !(0...0.5).contains(value) {
            issues.append("style.effects.shadowOpacity must be between 0 and 0.5.")
        }
        if let value = effects.accentTreatment, !["solid", "gradient"].contains(value) {
            issues.append("style.effects.accentTreatment must be solid or gradient.")
        }
        if let value = effects.motionScale, !(0...2).contains(value) {
            issues.append("style.effects.motionScale must be between 0 and 2.")
        }
        if let value = composition.pageHeader, !["native", "editorial", "output"].contains(value) {
            issues.append("style.composition.pageHeader must be native, editorial, or output.")
        }
        if let value = composition.sidebarBrand, !["tile", "wordmark", "index"].contains(value) {
            issues.append("style.composition.sidebarBrand must be tile, wordmark, or index.")
        }
        if let value = composition.hero, !["card", "orbital", "topology", "plate", "terminal"].contains(value) {
            issues.append("style.composition.hero must be card, orbital, topology, plate, or terminal.")
        }
        if let value = composition.metricStrip, !["band", "ruled", "cells"].contains(value) {
            issues.append("style.composition.metricStrip must be band, ruled, or cells.")
        }
        if let value = composition.panel, !["card", "ruled", "terminal"].contains(value) {
            issues.append("style.composition.panel must be card, ruled, or terminal.")
        }
        if let value = composition.badge, !["capsule", "label", "stamp"].contains(value) {
            issues.append("style.composition.badge must be capsule, label, or stamp.")
        }
        if let value = composition.dataLabels, !["human", "registry", "terminal"].contains(value) {
            issues.append("style.composition.dataLabels must be human, registry, or terminal.")
        }
        return issues
    }
}
