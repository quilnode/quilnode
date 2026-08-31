import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let graphite = makeBuiltIn(
        id: "quil.graphite", name: "Graphite", summary: "Restrained graphite glass with cyan telemetry.",
        palette: .init(
            accent: "#63D7E8", selection: "#30383F", muted: "#53606A",
            background: "#121416", darkBackground: "#191D21", darkerBackground: "#0D0F11", lighterBackground: "#252B30",
            foreground: "#EEF2F3", darkForeground: "#849096", lightForeground: "#C8D0D3", brightForeground: "#FFFFFF",
            red: "#FF6B6B", yellow: "#E7C86E", orange: "#E99D67", green: "#6ED6A0", cyan: "#63D7E8", blue: "#8D8AFF",
            magenta: "#C782FF"
        ),
        style: .init(
            surfaces: .init(treatment: "material", surfaceOpacity: 0.62, elevatedOpacity: 0.84, borderOpacity: 0.20))
    )

    static let graphiteLight = makeBuiltInVariant(
        base: graphite, id: "quil.graphite.light", appearance: .light,
        summary: "Graphite translated to cool paper, ink and cyan telemetry.",
        palette: .init(
            accent: "#087E8B", selection: "#D8E2E5", muted: "#B5C2C6",
            background: "#F4F6F7", darkBackground: "#E8ECEE", darkerBackground: "#D9E0E3", lighterBackground: "#FFFFFF",
            foreground: "#263238", darkForeground: "#6D7B81", lightForeground: "#435159", brightForeground: "#111719",
            red: "#C33B3B", yellow: "#8B6B00", orange: "#B85D1D", green: "#287A4E", cyan: "#087E8B", blue: "#5652C7",
            magenta: "#8D45B5"
        )
    )
}
