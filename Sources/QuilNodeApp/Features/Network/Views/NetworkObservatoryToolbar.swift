import SwiftUI

struct NetworkObservatoryToolbar: View {
    @Environment(\.quilTheme) private var theme

    @Binding var lens: NetworkObservatoryLens
    @Binding var query: String
    @Binding var zoom: CGFloat
    let availableLenses: [NetworkObservatoryLens]

    var body: some View {
        HStack(spacing: 10) {
            lensPicker
            searchField
            zoomControls
        }
    }

    private var lensPicker: some View {
        Menu {
            ForEach(availableLenses) { candidate in
                Button {
                    lens = candidate
                } label: {
                    if candidate == lens {
                        Label(candidate.title, systemImage: "checkmark")
                    } else {
                        Label(candidate.title, systemImage: candidate.systemImage)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: lens.systemImage)
                    .foregroundStyle(theme.colors.accentSecondary)
                Text(lens.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(theme.colors.primaryText)
            .padding(.horizontal, 9)
            .frame(width: 180, height: 28)
            .contentShape(Rectangle())
            .controlSurface()
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .accessibilityLabel("Shard lens")
        .help(lens.detail)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.secondaryText)
            TextField("Shard, ring or worker", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.secondaryText)
                .accessibilityLabel("Clear shard search")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 190, height: 28)
        .controlSurface()
        .help("Searches within the selected lens. Local workers are included only when Privacy Mode is off")
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            zoomButton("minus", adjustment: -0.1)
            Text("\(Int(zoom * 100))%")
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 42)
            zoomButton("plus", adjustment: 0.1)
        }
        .frame(height: 28)
        .controlSurface()
    }

    private func zoomButton(_ systemImage: String, adjustment: CGFloat) -> some View {
        Button {
            zoom = min(max(zoom + adjustment, 0.72), 1.18)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.colors.accent)
        .accessibilityLabel(adjustment > 0 ? "Zoom in" : "Zoom out")
    }
}
