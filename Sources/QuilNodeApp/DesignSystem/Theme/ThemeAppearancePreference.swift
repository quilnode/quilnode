import AppKit

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

enum ThemeAppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    @MainActor var resolvedAppearance: QuilThemeAppearance {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system:
            NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }
}
