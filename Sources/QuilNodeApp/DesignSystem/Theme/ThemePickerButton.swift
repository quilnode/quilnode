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
            ThemeLibraryView(isPresented: $isPresented)
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
