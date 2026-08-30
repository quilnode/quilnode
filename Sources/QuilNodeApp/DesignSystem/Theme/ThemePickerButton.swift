import SwiftUI

/// Compact launcher plus a visual theme gallery. A gallery is important here:
/// names alone do not communicate palette, density, or light/dark appearance.
struct ThemePickerButton: View {
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.quilTheme) private var theme
    @State private var isPresented = false
    var compact = false
    var fillsWidth = false
    var controlHeight: CGFloat = 30
    var popoverEdge: Edge = .bottom
    var embedded = false
    var showChevron = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: compact ? 0 : 10) {
                if embedded {
                    ThemeSwatchGlyph(colors: theme.colors.pickerSwatches)
                } else {
                    Image(systemName: "paintpalette.fill")
                }
                if !compact {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(embedded ? "Theme" : theme.name)
                            .foregroundStyle(theme.colors.primaryText)
                        if embedded {
                            Text(theme.name)
                                .font(.caption2)
                                .foregroundStyle(theme.colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 6)
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.colors.secondaryText.opacity(0.72))
                    }
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.colors.accent)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
            .frame(width: compact && !fillsWidth ? controlHeight : nil, height: controlHeight)
            .padding(.horizontal, compact ? 0 : 9)
            .contentShape(Rectangle())
            .background {
                if !embedded {
                    RoundedRectangle(
                        cornerRadius: fillsWidth ? theme.metrics.controlCornerRadius : controlHeight / 2,
                        style: .continuous
                    )
                    .fill(theme.colors.selection.opacity(0.32))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .popover(isPresented: $isPresented, arrowEdge: popoverEdge) {
            ThemeGallery(isPresented: $isPresented)
                .environmentObject(themeController)
                .quilThemed(themeController.selectedTheme)
        }
        .help("Theme: \(theme.name)")
        .accessibilityLabel("Choose theme. Current theme: \(theme.name)")
        .accessibilityIdentifier("quilnode-theme-picker")
    }
}

/// A theme is a palette, so the launcher previews the active palette instead
/// of using a generic paint icon. The overlapping discs remain legible at the
/// 16–20 pt sizes used by both sidebar modes.
private struct ThemeSwatchGlyph: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            Circle()
                .fill(colors[safe: 1] ?? .gray)
                .frame(width: 13, height: 13)
                .offset(x: 4, y: -3)
            Circle()
                .fill(colors[safe: 2] ?? .gray)
                .frame(width: 13, height: 13)
                .offset(x: 4, y: 4)
            Circle()
                .fill(colors.first ?? .gray)
                .frame(width: 15, height: 15)
                .offset(x: -4)
                .overlay(Circle().strokeBorder(.white.opacity(0.36), lineWidth: 0.5).offset(x: -4))
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ThemeGallery: View {
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.quilTheme) private var theme
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme Library").font(.headline)
                    Text("Palette, surfaces, density & type")
                        .font(.caption2).foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Text("\(themeController.displayedThemes.count)")
                    .font(.caption.bold().monospacedDigit())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(theme.colors.selection.opacity(0.5), in: Capsule())
            }
            .padding(14)

            Divider().opacity(0.45)

            Picker("Appearance", selection: $themeController.appearancePreference) {
                ForEach(ThemeAppearancePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().opacity(0.45)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(themeController.displayedThemes) { candidate in
                        ThemeGalleryRow(
                            theme: candidate,
                            supportsLight: themeController.supports(.light, inFamily: candidate.familyID),
                            supportsDark: themeController.supports(.dark, inFamily: candidate.familyID),
                            isSelected: candidate.familyID == themeController.selectedThemeID
                        ) {
                            themeController.select(candidate)
                        }
                    }
                }
                .padding(10)
            }
            .frame(height: 410)

            Divider().opacity(0.45)
            HStack {
                Button("Themes Folder", systemImage: "folder") { themeController.revealThemesDirectory() }
                Button("Reload", systemImage: "arrow.clockwise") { themeController.reload() }
                Spacer()
                Button("Done") { isPresented = false }.keyboardShortcut(.defaultAction)
            }
            .font(.caption)
            .padding(10)

            if !themeController.loadIssues.isEmpty {
                DisclosureGroup(
                    "\(themeController.loadIssues.count) theme issue\(themeController.loadIssues.count == 1 ? "" : "s")"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(themeController.loadIssues.enumerated()), id: \.offset) { _, issue in
                            Text(issue).font(.caption2).foregroundStyle(theme.colors.warning)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 5)
                }
                .font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .frame(width: 372)
        .background { ThemeCanvasBackground() }
    }
}

private struct ThemeGalleryRow: View {
    let theme: QuilTheme
    let supportsLight: Bool
    let supportsDark: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.colors.canvas)
                    HStack(spacing: 2) {
                        ForEach(Array(theme.colors.pickerSwatches.enumerated()), id: \.offset) { _, color in
                            Capsule().fill(color).frame(width: 5, height: 22)
                        }
                    }
                }
                .frame(width: 48, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).strokeBorder(theme.colors.border.opacity(0.65), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(theme.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(modeLabel)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(theme.colors.selection.opacity(0.6), in: Capsule())
                    }
                    Text(theme.summary ?? (theme.isBuiltIn ? "Built in" : "by \(theme.author)"))
                        .font(.caption2).foregroundStyle(theme.colors.secondaryText).lineLimit(1)
                }
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.colors.accent)
                }
            }
            .foregroundStyle(theme.colors.primaryText)
            .padding(8)
            .background(
                isSelected ? theme.colors.selection.opacity(0.46) : theme.colors.surface.opacity(0.42),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? theme.colors.accent.opacity(0.55) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name), \(theme.appearance.rawValue) theme\(isSelected ? ", selected" : "")")
    }

    private var modeLabel: String {
        if supportsLight && supportsDark { return "LIGHT · DARK" }
        return theme.appearance == .light ? "LIGHT" : "DARK"
    }
}
