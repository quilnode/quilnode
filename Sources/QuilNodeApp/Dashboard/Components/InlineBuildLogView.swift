import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct InlineBuildLogView: View {
    let logURL: URL
    let isLive: Bool
    let privacyModeEnabled: Bool

    @State private var snapshot = BuildLogSnapshot.waiting
    @State private var revision = 0
    @State private var followsLatest = true

    var body: some View {
        BuildEvidencePanel(
            snapshot: snapshot,
            isLive: isLive,
            privacyModeEnabled: privacyModeEnabled,
            followsLatest: $followsLatest,
            revision: revision
        )
        .task(id: "\(logURL.path)|\(isLive)") {
            repeat {
                let next = await Task.detached(priority: .utility) {
                    Self.readSnapshot(of: logURL)
                }.value
                if !next.hasSameEvidence(as: snapshot) {
                    snapshot = next
                    revision += 1
                }
                if !isLive { break }
                try? await Task.sleep(for: .milliseconds(750))
            } while !Task.isCancelled
        }
    }

    nonisolated private static func readSnapshot(of url: URL) -> BuildLogSnapshot {
        let maximumBytes = 96 * 1_024
        guard
            let data = try? BoundedLocalData.readTail(
                from: url,
                maximumFileBytes: 128 * 1_024 * 1_024,
                maximumTailBytes: maximumBytes
            )
        else {
            return .unavailable
        }

        return BuildLogSnapshot.parse(
            String(decoding: data, as: UTF8.self),
            reachedByteLimit: data.count == maximumBytes,
            observedAt: Date()
        )
    }
}

struct BuildEvidencePanel: View {
    @Environment(\.quilTheme) private var theme
    let snapshot: BuildLogSnapshot
    let isLive: Bool
    let privacyModeEnabled: Bool
    @Binding var followsLatest: Bool
    let revision: Int

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.42)
            evidenceStrip
            transcript
        }
        .background(theme.colors.surface.opacity(0.54), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(theme.colors.border.opacity(0.52), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "chevron.up")
                .font(.caption2.bold())
                .foregroundStyle(theme.colors.accent)
            Text("BUILD EVIDENCE")
                .font(.caption2.bold())
                .tracking(0.8)
            HStack(spacing: 5) {
                Circle()
                    .fill(isLive ? theme.colors.success : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(isLive ? "Live" : "Receipt")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isLive ? theme.colors.success : theme.colors.secondaryText)
            }
            Spacer()
            Toggle("Follow latest", isOn: $followsLatest)
                .toggleStyle(.checkbox)
                .font(.caption)
            Button("Copy", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snapshot.output, forType: .string)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(snapshot.output.isEmpty)
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
    }

    private var evidenceStrip: some View {
        TimelineView(.periodic(from: .now, by: isLive ? 5 : 60)) { timeline in
            HStack(spacing: 0) {
                evidenceCell(
                    title: "ACTIVITY",
                    value: isLive ? "Build active" : "Build receipt",
                    detail: snapshot.activityDetail,
                    systemImage: isLive ? "bolt.circle.fill" : "checkmark.circle.fill",
                    tint: isLive ? theme.colors.success : theme.colors.info,
                    minWidth: 132
                )
                evidenceDivider
                evidenceCell(
                    title: "LATEST EVENT",
                    value: sanitized(snapshot.latestEvent),
                    detail: snapshot.hasOutput ? "Local compiler output" : "Awaiting first line",
                    systemImage: "text.line.last.and.arrowtriangle.forward",
                    tint: theme.colors.info,
                    minWidth: 210
                )
                evidenceDivider
                evidenceCell(
                    title: "LOG UPDATED",
                    value: logAgeLabel(at: timeline.date),
                    detail: isLive ? "Watching local log" : "Final snapshot",
                    systemImage: "clock.arrow.circlepath",
                    tint: isLive ? theme.colors.success : theme.colors.secondaryText,
                    minWidth: 126
                )
                evidenceDivider
                evidenceCount(title: "WARNINGS", value: snapshot.warningCount, tint: theme.colors.warning)
                evidenceDivider
                evidenceCount(title: "ERRORS", value: snapshot.errorCount, tint: theme.colors.danger)
                evidenceDivider
                evidenceCell(
                    title: "VISIBLE LINES",
                    value: "\(snapshot.visibleLineCount)",
                    detail: snapshot.wasTrimmed ? "latest 320" : "bounded tail",
                    systemImage: "text.alignleft",
                    tint: theme.colors.secondaryText,
                    minWidth: 104
                )
            }
        }
        .frame(minHeight: 68)
        .background(theme.colors.surfaceElevated.opacity(0.36))
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.wasTrimmed ? "Showing latest 320 lines" : "Showing \(snapshot.visibleLineCount) lines")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)

            ScrollViewReader { proxy in
                GeometryReader { viewport in
                    ScrollView([.vertical, .horizontal]) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(sanitized(snapshot.displayOutput))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.colors.primaryText.opacity(0.86))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: true, vertical: false)
                            Color.clear.frame(width: 1, height: 1).id("build-log-bottom")
                        }
                        .frame(
                            minWidth: max(viewport.size.width - 20, 0),
                            alignment: .topLeading
                        )
                        .padding(10)
                    }
                    .background(theme.colors.canvas.opacity(0.68), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(theme.colors.border.opacity(0.42), lineWidth: 0.5)
                    }
                    .onChange(of: revision) { _, _ in
                        guard followsLatest else { return }
                        proxy.scrollTo("build-log-bottom", anchor: .bottom)
                    }
                }
                .frame(height: 190)
            }
        }
        .padding(10)
    }

    private var evidenceDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.4))
            .frame(width: 0.5, height: 42)
    }

    private func evidenceCell(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        tint: Color,
        minWidth: CGFloat
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(theme.colors.secondaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(minWidth: minWidth, maxWidth: .infinity, alignment: .leading)
    }

    private func evidenceCount(title: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(theme.colors.secondaryText)
            Text("\(value)")
                .font(.headline.weight(.semibold).monospacedDigit())
                .foregroundStyle(value > 0 ? tint : theme.colors.secondaryText)
        }
        .frame(minWidth: 68)
    }

    private func sanitized(_ value: String) -> String {
        PrivacySanitizer.display(value, enabled: privacyModeEnabled)
    }

    private func logAgeLabel(at now: Date) -> String {
        guard let observedAt = snapshot.observedAt else { return "Waiting" }
        let seconds = max(Int(now.timeIntervalSince(observedAt)), 0)
        if seconds < 5 { return "Just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
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
