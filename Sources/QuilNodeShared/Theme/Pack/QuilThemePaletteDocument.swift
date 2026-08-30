import Foundation

/// Omarchy-style canonical palette stored in `<name>.quiltheme/colors.json`.
/// All values are optional so packs can inherit and override selectively.
public struct QuilThemePaletteDocument: Codable, Hashable, Sendable {
    public var accent: String?
    public var selection: String?
    public var muted: String?

    public var background: String?
    public var darkBackground: String?
    public var darkerBackground: String?
    public var lighterBackground: String?

    public var foreground: String?
    public var darkForeground: String?
    public var lightForeground: String?
    public var brightForeground: String?

    public var red: String?
    public var yellow: String?
    public var orange: String?
    public var green: String?
    public var cyan: String?
    public var blue: String?
    public var magenta: String?

    public var privacy: String?
    public var frame: String?
    public var wallet: String?

    public init(
        accent: String? = nil,
        selection: String? = nil,
        muted: String? = nil,
        background: String? = nil,
        darkBackground: String? = nil,
        darkerBackground: String? = nil,
        lighterBackground: String? = nil,
        foreground: String? = nil,
        darkForeground: String? = nil,
        lightForeground: String? = nil,
        brightForeground: String? = nil,
        red: String? = nil,
        yellow: String? = nil,
        orange: String? = nil,
        green: String? = nil,
        cyan: String? = nil,
        blue: String? = nil,
        magenta: String? = nil,
        privacy: String? = nil,
        frame: String? = nil,
        wallet: String? = nil
    ) {
        self.accent = accent
        self.selection = selection
        self.muted = muted
        self.background = background
        self.darkBackground = darkBackground
        self.darkerBackground = darkerBackground
        self.lighterBackground = lighterBackground
        self.foreground = foreground
        self.darkForeground = darkForeground
        self.lightForeground = lightForeground
        self.brightForeground = brightForeground
        self.red = red
        self.yellow = yellow
        self.orange = orange
        self.green = green
        self.cyan = cyan
        self.blue = blue
        self.magenta = magenta
        self.privacy = privacy
        self.frame = frame
        self.wallet = wallet
    }

    public func validationIssues() -> [String] {
        values.compactMap { token, value in
            Self.isValidColor(value)
                ? nil : "colors.\(token) must be #RRGGBB, #RRGGBBAA, or a supported system:* color."
        }
    }

    public var values: [(String, String)] {
        [
            ("accent", accent), ("selection", selection), ("muted", muted),
            ("background", background), ("darkBackground", darkBackground),
            ("darkerBackground", darkerBackground), ("lighterBackground", lighterBackground),
            ("foreground", foreground), ("darkForeground", darkForeground),
            ("lightForeground", lightForeground), ("brightForeground", brightForeground),
            ("red", red), ("yellow", yellow), ("orange", orange), ("green", green),
            ("cyan", cyan), ("blue", blue), ("magenta", magenta),
            ("privacy", privacy), ("frame", frame), ("wallet", wallet),
        ].compactMap { key, value in value.map { (key, $0) } }
    }

    private static func isValidColor(_ value: String) -> Bool {
        if value.hasPrefix("system:") {
            return [
                "system:accent", "system:primary", "system:secondary",
                "system:window", "system:control", "system:separator",
            ].contains(value)
        }
        guard value.first == "#" else { return false }
        let hex = value.dropFirst()
        return (hex.count == 6 || hex.count == 8) && hex.allSatisfy(\.isHexDigit)
    }
}
