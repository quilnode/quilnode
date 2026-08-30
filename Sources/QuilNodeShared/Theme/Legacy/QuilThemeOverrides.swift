import Foundation

public struct QuilThemeColorOverrides: Codable, Hashable, Sendable {
    public var accent: String?
    public var accentSecondary: String?
    public var success: String?
    public var warning: String?
    public var danger: String?
    public var info: String?
    public var privacy: String?
    public var frame: String?
    public var wallet: String?
    public var canvas: String?
    public var sidebar: String?
    public var surface: String?
    public var surfaceElevated: String?
    public var border: String?
    public var primaryText: String?
    public var secondaryText: String?

    public init(
        accent: String? = nil,
        accentSecondary: String? = nil,
        success: String? = nil,
        warning: String? = nil,
        danger: String? = nil,
        info: String? = nil,
        privacy: String? = nil,
        frame: String? = nil,
        wallet: String? = nil,
        canvas: String? = nil,
        sidebar: String? = nil,
        surface: String? = nil,
        surfaceElevated: String? = nil,
        border: String? = nil,
        primaryText: String? = nil,
        secondaryText: String? = nil
    ) {
        self.accent = accent
        self.accentSecondary = accentSecondary
        self.success = success
        self.warning = warning
        self.danger = danger
        self.info = info
        self.privacy = privacy
        self.frame = frame
        self.wallet = wallet
        self.canvas = canvas
        self.sidebar = sidebar
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.border = border
        self.primaryText = primaryText
        self.secondaryText = secondaryText
    }

    public var values: [(String, String)] {
        [
            ("accent", accent), ("accentSecondary", accentSecondary),
            ("success", success), ("warning", warning), ("danger", danger),
            ("info", info), ("privacy", privacy), ("frame", frame),
            ("wallet", wallet), ("canvas", canvas), ("sidebar", sidebar),
            ("surface", surface), ("surfaceElevated", surfaceElevated),
            ("border", border), ("primaryText", primaryText),
            ("secondaryText", secondaryText),
        ].compactMap { key, value in value.map { (key, $0) } }
    }
}

public struct QuilThemeMetricOverrides: Codable, Hashable, Sendable {
    public var sidebarCollapsedWidth: Double?
    public var sidebarExpandedWidth: Double?
    public var navigationRowHeight: Double?
    public var controlCornerRadius: Double?
    public var heroCornerRadius: Double?
    public var spacingScale: Double?
    public var borderWidth: Double?

    public init(
        sidebarCollapsedWidth: Double? = nil,
        sidebarExpandedWidth: Double? = nil,
        navigationRowHeight: Double? = nil,
        controlCornerRadius: Double? = nil,
        heroCornerRadius: Double? = nil,
        spacingScale: Double? = nil,
        borderWidth: Double? = nil
    ) {
        self.sidebarCollapsedWidth = sidebarCollapsedWidth
        self.sidebarExpandedWidth = sidebarExpandedWidth
        self.navigationRowHeight = navigationRowHeight
        self.controlCornerRadius = controlCornerRadius
        self.heroCornerRadius = heroCornerRadius
        self.spacingScale = spacingScale
        self.borderWidth = borderWidth
    }
}

public struct QuilThemeTypographyOverrides: Codable, Hashable, Sendable {
    public var scale: Double?
    public var displayDesign: String?
    public var dataDesign: String?

    public init(scale: Double? = nil, displayDesign: String? = nil, dataDesign: String? = nil) {
        self.scale = scale
        self.displayDesign = displayDesign
        self.dataDesign = dataDesign
    }
}
