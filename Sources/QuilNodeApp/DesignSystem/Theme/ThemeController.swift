import AppKit
import Darwin
import Foundation
import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
final class ThemeController: ObservableObject {
    @Published private(set) var themes: [QuilTheme] = QuilTheme.builtIns
    @Published var loadIssues: [String] = []
    @Published var selectedThemeID: String {
        didSet { UserDefaults.standard.set(selectedThemeID, forKey: Self.selectionKey) }
    }
    @Published var appearancePreference: ThemeAppearancePreference {
        didSet { UserDefaults.standard.set(appearancePreference.rawValue, forKey: Self.appearanceKey) }
    }

    private struct Candidate {
        let source: URL
        let id: String
        let base: String
        let resolve: (QuilTheme) -> [QuilTheme]
    }

    private static let selectionKey = "selectedQuilThemeID"
    private static let appearanceKey = "selectedQuilThemeAppearance"
    private static let defaultThemeMigrationKey = "didMigrateToQuilNodeDefaultThemeV1"
    private static let maximumThemeDocumentBytes = 512 * 1_024
    private static let maximumThemePackEntries = 32
    private let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    private let watcher = ThemeDirectoryWatcher()
    private var appearanceObserver: NSObjectProtocol?

    let themesDirectory: URL

    var selectedTheme: QuilTheme {
        theme(inFamily: selectedThemeID) ?? .quilNode
    }

    var displayedThemes: [QuilTheme] {
        var seen: Set<String> = []
        return themes.compactMap { theme in
            guard seen.insert(theme.familyID).inserted else { return nil }
            return self.theme(inFamily: theme.familyID)
        }
    }

    init(fileManager: FileManager = .default) {
        let support =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        themesDirectory = support.appendingPathComponent("QuilNode", isDirectory: true).appendingPathComponent(
            "Themes", isDirectory: true)
        selectedThemeID = Self.migratedInitialThemeSelection(defaults: .standard)
        appearancePreference =
            ThemeAppearancePreference(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "system")
            ?? .system

        prepareThemesDirectory(fileManager: fileManager)
        reload()
        watcher.start(url: themesDirectory) { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
    }

    func select(_ theme: QuilTheme) {
        guard themes.contains(where: { $0.familyID == theme.familyID }) else { return }
        selectedThemeID = theme.familyID
        objectWillChange.send()
    }

    #if DEBUG
        /// No preference migration, directory creation, or watchers in visual fixtures.
        init(previewTheme: QuilTheme) {
            themesDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            selectedThemeID = previewTheme.familyID
            appearancePreference = previewTheme.appearance == .light ? .light : .dark
        }
    #endif

    func reload() {
        let builtIns = QuilTheme.builtIns
        var resolved = Dictionary(uniqueKeysWithValues: builtIns.map { ($0.id, $0) })
        var issues: [String] = []
        var pending = loadCandidates(issues: &issues)

        for _ in 0...pending.count {
            var next: [Candidate] = []
            var madeProgress = false
            for candidate in pending {
                guard let base = resolved[candidate.base] else {
                    next.append(candidate)
                    continue
                }
                guard resolved[candidate.id] == nil else {
                    issues.append("\(candidate.source.lastPathComponent): duplicate theme id ‘\(candidate.id)’.")
                    continue
                }
                let variants = candidate.resolve(base)
                guard variants.allSatisfy({ resolved[$0.id] == nil }) else {
                    issues.append(
                        "\(candidate.source.lastPathComponent): duplicate theme variant id in family ‘\(candidate.id)’."
                    )
                    continue
                }
                variants.forEach { resolved[$0.id] = $0 }
                madeProgress = true
            }
            pending = next
            if pending.isEmpty || !madeProgress { break }
        }
        for candidate in pending {
            issues.append("\(candidate.source.lastPathComponent): base theme ‘\(candidate.base)’ was not found.")
        }

        let custom = resolved.values.filter { !$0.isBuiltIn }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        themes = builtIns + custom
        loadIssues = issues
        if !themes.contains(where: { $0.familyID == selectedThemeID || $0.id == selectedThemeID }) {
            selectedThemeID = QuilTheme.quilNode.familyID
        } else if let legacy = themes.first(where: { $0.id == selectedThemeID }) {
            selectedThemeID = legacy.familyID
        }
    }

    /// A legacy build used `quil.classic` for what is now the distinct QuilNode
    /// palette. Migrate that historical default exactly once,
    /// while preserving every explicit third-party or bundled theme choice.
    static func migratedInitialThemeSelection(defaults: UserDefaults) -> String {
        let stored = defaults.string(forKey: selectionKey)
        guard !defaults.bool(forKey: defaultThemeMigrationKey) else {
            return stored ?? QuilTheme.quilNode.familyID
        }

        defaults.set(true, forKey: defaultThemeMigrationKey)
        guard stored == nil || stored == QuilTheme.classic.id || stored == "quil.classic.light" else {
            return stored ?? QuilTheme.quilNode.familyID
        }
        return QuilTheme.quilNode.familyID
    }

    func supports(_ appearance: QuilThemeAppearance, inFamily familyID: String) -> Bool {
        themes.contains { $0.familyID == familyID && $0.appearance == appearance }
    }

    private func theme(inFamily familyID: String) -> QuilTheme? {
        let family = themes.filter { $0.familyID == familyID || $0.id == familyID }
        guard !family.isEmpty else { return nil }
        let desired = appearancePreference.resolvedAppearance
        return family.first(where: { $0.appearance == desired })
            ?? family.first(where: { $0.appearance == .system })
            ?? family.first
    }

    func revealThemesDirectory() { NSWorkspace.shared.open(themesDirectory) }

    private func loadCandidates(issues: inout [String]) -> [Candidate] {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: themesDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            issues.append("Could not read the custom themes folder: \(error.localizedDescription)")
            return []
        }

        return urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { url in
                if url.lastPathComponent.hasSuffix(".quiltheme.json") {
                    return loadLegacyManifest(at: url, issues: &issues)
                }
                guard url.lastPathComponent.hasSuffix(".quiltheme") else { return nil }
                return loadPack(at: url, issues: &issues)
            }
    }

    private func loadLegacyManifest(at url: URL, issues: inout [String]) -> Candidate? {
        do {
            let manifest = try decoder.decode(
                QuilThemeManifest.self,
                from: try Self.readThemeData(
                    at: url,
                    maximumBytes: Self.maximumThemeDocumentBytes
                )
            )
            let validation = manifest.validationIssues()
            guard validation.isEmpty else {
                issues.append(contentsOf: validation.map { "\(url.lastPathComponent): \($0)" })
                return nil
            }
            return Candidate(source: url, id: manifest.id, base: manifest.base ?? QuilTheme.classic.id) {
                [$0.applying(manifest)]
            }
        } catch {
            issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private func loadPack(at directory: URL, issues: inout [String]) -> Candidate? {
        do {
            let rootValues = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
                issues.append(
                    "\(directory.lastPathComponent): theme packs must be real directories, not symbolic links.")
                return nil
            }

            let allowed = Set(["theme.json", "colors.json", "style.json", "variants.json", "preview.png", "README.md"])
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])
            guard contents.count <= Self.maximumThemePackEntries else {
                issues.append(
                    "\(directory.lastPathComponent): theme packs are limited to \(Self.maximumThemePackEntries) entries."
                )
                return nil
            }
            for child in contents {
                let values = try child.resourceValues(forKeys: [
                    .isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey,
                ])
                guard values.isSymbolicLink != true,
                    values.isRegularFile == true
                else {
                    issues.append("\(directory.lastPathComponent): symbolic links are not allowed inside theme packs.")
                    return nil
                }
                guard allowed.contains(child.lastPathComponent) else {
                    issues.append(
                        "\(directory.lastPathComponent): ignored unknown file ‘\(child.lastPathComponent)’; packs are data-only."
                    )
                    continue
                }
                let maximumBytes =
                    child.pathExtension.lowercased() == "png"
                    ? 5 * 1_024 * 1_024
                    : (child.pathExtension.lowercased() == "md"
                        ? 1 * 1_024 * 1_024
                        : Self.maximumThemeDocumentBytes)
                guard let size = values.fileSize, size > 0, size <= maximumBytes else {
                    issues.append(
                        "\(directory.lastPathComponent): ‘\(child.lastPathComponent)’ exceeds its safe size limit.")
                    return nil
                }
            }

            let metadataURL = directory.appendingPathComponent("theme.json")
            let colorsURL = directory.appendingPathComponent("colors.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path),
                FileManager.default.fileExists(atPath: colorsURL.path)
            else {
                issues.append("\(directory.lastPathComponent): theme.json and colors.json are required.")
                return nil
            }
            let metadata = try decoder.decode(
                QuilThemePackMetadata.self,
                from: try Self.readThemeData(at: metadataURL, maximumBytes: Self.maximumThemeDocumentBytes)
            )
            let colors = try decoder.decode(
                QuilThemePaletteDocument.self,
                from: try Self.readThemeData(at: colorsURL, maximumBytes: Self.maximumThemeDocumentBytes)
            )
            let styleURL = directory.appendingPathComponent("style.json")
            let style =
                FileManager.default.fileExists(atPath: styleURL.path)
                ? try decoder.decode(
                    QuilThemeStyleDocument.self,
                    from: Self.readThemeData(at: styleURL, maximumBytes: Self.maximumThemeDocumentBytes))
                : QuilThemeStyleDocument()
            let variantsURL = directory.appendingPathComponent("variants.json")
            let variants =
                FileManager.default.fileExists(atPath: variantsURL.path)
                ? try decoder.decode(
                    QuilThemeVariantsDocument.self,
                    from: Self.readThemeData(at: variantsURL, maximumBytes: Self.maximumThemeDocumentBytes))
                : QuilThemeVariantsDocument()
            let pack = QuilThemePack(metadata: metadata, colors: colors, style: style, variants: variants)
            let validation = pack.validationIssues()
            guard validation.isEmpty else {
                issues.append(contentsOf: validation.map { "\(directory.lastPathComponent): \($0)" })
                return nil
            }
            return Candidate(source: directory, id: metadata.id, base: metadata.base) { base in
                let resolvedBase = base.applying(pack)
                guard variants.light != nil || variants.dark != nil else { return [resolvedBase] }
                var resolvedVariants: [QuilTheme] = []
                if let light = variants.light {
                    resolvedVariants.append(
                        resolvedBase.applying(
                            familyID: metadata.id, variantID: "\(metadata.id).light", appearance: .light,
                            colors: light.colors, style: light.style
                        ))
                }
                if let dark = variants.dark {
                    resolvedVariants.append(
                        resolvedBase.applying(
                            familyID: metadata.id, variantID: "\(metadata.id).dark", appearance: .dark,
                            colors: dark.colors, style: dark.style
                        ))
                }
                return resolvedVariants
            }
        } catch {
            issues.append("\(directory.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private static func readThemeData(at url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard values.isRegularFile == true,
            values.isSymbolicLink != true,
            let size = values.fileSize,
            size > 0,
            size <= maximumBytes
        else { throw ThemeLoadBoundaryError.unsafeDocument }
        return try BoundedLocalData.read(from: url, maximumBytes: maximumBytes)
    }

}
