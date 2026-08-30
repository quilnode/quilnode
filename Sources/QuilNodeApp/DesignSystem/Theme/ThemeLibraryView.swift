import SwiftUI

struct ThemeLibraryView: View {
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.quilTheme) private var theme
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var searchIsFocused: Bool

    private var filteredThemes: [QuilTheme] {
        ThemeLibraryPresentation.filteredThemes(themeController.displayedThemes, query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.42)
            searchAndAppearance
            Divider().opacity(0.42)
            themeList
            Divider().opacity(0.42)
            ThemeSpecimenBand(candidate: themeController.selectedTheme)
                .padding(10)
            Divider().opacity(0.42)
            footer
            themeIssues
        }
        .frame(width: 452)
        .background { ThemeCanvasBackground() }
        .background(searchShortcut)
        .onExitCommand { isPresented = false }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Theme Studio")
                .font(.title3.weight(.semibold))
            Text("\(themeController.displayedThemes.count) themes")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
            Spacer()
            Text("⌘K")
                .font(.caption2.monospaced())
                .foregroundStyle(theme.colors.secondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(theme.colors.surfaceElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
                .help("Focus theme search")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var searchAndAppearance: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colors.secondaryText)
                TextField("Search themes", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchIsFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchIsFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(theme.colors.surfaceElevated.opacity(0.78), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        searchIsFocused ? theme.colors.accent.opacity(0.72) : theme.colors.border.opacity(0.45),
                        lineWidth: searchIsFocused ? 1 : 0.5
                    )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("quilnode-theme-search")

            Picker("Appearance", selection: $themeController.appearancePreference) {
                ForEach(ThemeAppearancePreference.allCases) { preference in
                    Label(preference.sidebarLabel, systemImage: preference.systemImage).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("quilnode-theme-appearance-picker")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var themeList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if filteredThemes.isEmpty {
                    ContentUnavailableView(
                        "No matching themes",
                        systemImage: "paintpalette",
                        description: Text("Try a theme name, author, or style tag.")
                    )
                    .frame(minHeight: 150)
                } else {
                    ForEach(filteredThemes) { candidate in
                        ThemeLibraryRow(
                            candidate: candidate,
                            supportsLight: themeController.supports(.light, inFamily: candidate.familyID),
                            supportsDark: themeController.supports(.dark, inFamily: candidate.familyID),
                            isSelected: candidate.familyID == themeController.selectedThemeID
                        ) {
                            themeController.select(candidate)
                        }
                    }
                }
            }
            .padding(10)
        }
        .frame(height: 300)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Themes Folder", systemImage: "folder") {
                themeController.revealThemesDirectory()
            }
            Button("Reload", systemImage: "arrow.clockwise") {
                themeController.reload()
            }
            Spacer()
            Button("Done") { isPresented = false }
                .keyboardShortcut(.defaultAction)
        }
        .font(.caption)
        .padding(10)
    }

    private var searchShortcut: some View {
        Button("Focus theme search") {
            searchIsFocused = true
        }
        .keyboardShortcut("k", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var themeIssues: some View {
        if !themeController.loadIssues.isEmpty {
            DisclosureGroup(
                "\(themeController.loadIssues.count) theme issue\(themeController.loadIssues.count == 1 ? "" : "s")"
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(themeController.loadIssues.enumerated()), id: \.offset) { _, issue in
                        Text(issue)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.warning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }
}
