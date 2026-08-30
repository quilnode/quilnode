import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct InlineBuildLogView: View {
    @Environment(\.quilTheme) private var theme
    let logURL: URL
    let isLive: Bool
    let privacyModeEnabled: Bool

    @State private var output = "Waiting for compiler output…"
    @State private var revision = 0
    @State private var followsLatest = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isLive ? theme.colors.success : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(isLive ? "LIVE BUILD OUTPUT" : "BUILD OUTPUT")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Follow latest", isOn: $followsLatest)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(PrivacySanitizer.display(output, enabled: privacyModeEnabled))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.86))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                        Color.clear.frame(width: 1, height: 1).id("build-log-bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(height: 220)
                .onChange(of: revision) { _, _ in
                    guard followsLatest else { return }
                    proxy.scrollTo("build-log-bottom", anchor: .bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        }
        .task(id: "\(logURL.path)|\(isLive)") {
            repeat {
                let next = await Task.detached(priority: .utility) {
                    Self.readTail(of: logURL)
                }.value
                if next != output {
                    output = next
                    revision += 1
                }
                if !isLive { break }
                try? await Task.sleep(for: .milliseconds(750))
            } while !Task.isCancelled
        }
    }

    nonisolated private static func readTail(of url: URL) -> String {
        let maximumBytes = 96 * 1_024
        guard
            let data = try? BoundedLocalData.readTail(
                from: url,
                maximumFileBytes: 128 * 1_024 * 1_024,
                maximumTailBytes: maximumBytes
            )
        else {
            return "Build output is not available yet."
        }
        // Keep disk work and SwiftUI text layout bounded independently.
        // Compiler logs often contain thousands of short warning lines;
        // rendering the entire byte tail as selectable text makes a simple
        // expand/collapse action noticeably block the main thread.
        let maximumLines = 320
        let text = String(decoding: data, as: UTF8.self)
        guard !text.isEmpty else { return "Waiting for compiler output…" }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let wasTrimmed = data.count == maximumBytes || lines.count > maximumLines
        let visible = lines.suffix(maximumLines).joined(separator: "\n")
        return wasTrimmed ? "… showing the latest \(maximumLines) lines …\n\(visible)" : visible
    }
}

struct UpdateDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
