import SwiftUI

struct ThemeLibraryRow: View {
    let candidate: QuilTheme
    let supportsLight: Bool
    let supportsDark: Bool
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.quilTheme) private var activeTheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                selectionMark
                ApplicationBrandMark(size: 28, theme: candidate)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(activeTheme.colors.primaryText)
                        .lineLimit(1)
                    Text(ThemeLibraryPresentation.summary(for: candidate))
                        .font(.caption2)
                        .foregroundStyle(activeTheme.colors.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                ThemePaletteFingerprint(theme: candidate)
                Text(
                    ThemeLibraryPresentation.variantLabel(
                        supportsLight: supportsLight,
                        supportsDark: supportsDark
                    )
                )
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(activeTheme.colors.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(activeTheme.colors.surfaceElevated.opacity(0.78), in: Capsule())
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
            .background(rowBackground)
            .overlay(rowBorder)
        }
        .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.9, pressedScale: 0.995))
        .quilHoverSurface(tint: candidate.colors.accent, cornerRadius: 11)
        .accessibilityLabel(
            "\(candidate.name), \(ThemeLibraryPresentation.variantLabel(supportsLight: supportsLight, supportsDark: supportsDark))"
                + (isSelected ? ", selected" : "")
        )
        .accessibilityHint("Selects this theme family")
    }

    private var selectionMark: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isSelected ? activeTheme.colors.accent : activeTheme.colors.border)
            .frame(width: 18)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(
                isSelected
                    ? activeTheme.colors.selection.opacity(0.58)
                    : activeTheme.colors.surface.opacity(0.34)
            )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(
                isSelected ? activeTheme.colors.accent.opacity(0.62) : activeTheme.colors.border.opacity(0.34),
                lineWidth: isSelected ? 1 : 0.5
            )
            .allowsHitTesting(false)
    }
}

struct ThemePaletteFingerprint: View {
    let theme: QuilTheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(theme.colors.pickerSwatches.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(theme.colors.border.opacity(0.35), lineWidth: 0.5))
            }
        }
        .accessibilityHidden(true)
    }
}

struct ThemeSpecimenBand: View {
    let candidate: QuilTheme

    @Environment(\.quilTheme) private var activeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SELECTED THEME")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(activeTheme.colors.secondaryText)
                Spacer()
                Text(ThemeLibraryPresentation.provenance(for: candidate))
                    .font(.caption2.monospaced())
                    .foregroundStyle(activeTheme.colors.secondaryText)
            }

            HStack(spacing: 13) {
                specimen

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name)
                        .font(.headline)
                        .foregroundStyle(activeTheme.colors.primaryText)
                    Text(ThemeLibraryPresentation.summary(for: candidate))
                        .font(.caption2)
                        .foregroundStyle(activeTheme.colors.secondaryText)
                        .lineLimit(2)
                    ThemePaletteFingerprint(theme: candidate)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(activeTheme.colors.surfaceElevated.opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(activeTheme.colors.border.opacity(0.42), lineWidth: 0.5)
        }
    }

    private var specimen: some View {
        HStack(spacing: 0) {
            candidate.colors.sidebar
                .frame(width: 20)
                .overlay(ApplicationBrandMark(size: 14, theme: candidate))
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(candidate.colors.accent)
                    .frame(width: 43, height: 5)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == 0 ? candidate.colors.accentSecondary : candidate.colors.surfaceElevated)
                            .frame(height: 12)
                    }
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(candidate.colors.border.opacity(0.7))
                    .frame(height: 3)
            }
            .padding(8)
            .background(candidate.colors.canvas)
        }
        .frame(width: 112, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(candidate.colors.border.opacity(0.62), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}
