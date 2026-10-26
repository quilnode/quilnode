import SwiftUI

/// Plain-language log subject first; structured evidence remains one click
/// away. A log's suggested action is evidence, never an automatic repair.
struct DiagnosticMessageRow: View {
    @Environment(\.quilTheme) private var theme
    let message: String
    let isWaiting: Bool
    @State private var expanded = false

    private var subject: String {
        let withoutDate = message.components(separatedBy: " — ").dropFirst().joined(separator: " — ")
        let content = withoutDate.isEmpty ? message : withoutDate
        let title = content.components(separatedBy: " {").first ?? content
        return String(title.prefix(240)) + (title.count > 240 ? "…" : "")
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(message)
                .font(.caption.monospaced()).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isWaiting ? "hourglass.circle" : "exclamationmark.circle")
                    .foregroundStyle(isWaiting ? theme.colors.info : theme.colors.warning)
                VStack(alignment: .leading, spacing: 5) {
                    Text(subject).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text("Node log · expand for timestamp and full evidence")
                        .font(.caption).foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
    }
}
