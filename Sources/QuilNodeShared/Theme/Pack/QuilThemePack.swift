import Foundation

public struct QuilThemePack: Hashable, Sendable {
    public var metadata: QuilThemePackMetadata
    public var colors: QuilThemePaletteDocument
    public var style: QuilThemeStyleDocument
    public var variants: QuilThemeVariantsDocument

    public init(
        metadata: QuilThemePackMetadata, colors: QuilThemePaletteDocument, style: QuilThemeStyleDocument = .init(),
        variants: QuilThemeVariantsDocument = .init()
    ) {
        self.metadata = metadata
        self.colors = colors
        self.style = style
        self.variants = variants
    }

    public func validationIssues() -> [String] {
        metadata.validationIssues() + colors.validationIssues() + style.validationIssues() + variants.validationIssues()
    }
}
