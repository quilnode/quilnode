import SwiftUI

struct NetworkRouterTaskView: View {
    @Environment(\.quilTheme) private var theme

    let tasks: [NetworkRouterTask]
    let profileTitle: String
    let customizePorts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Router setup")
                        .font(.headline)
                    Text("The router remains a manual boundary; QuilNode never requests its password.")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Text(profileTitle.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.65)
                    .foregroundStyle(theme.colors.accent)
                Button("Customize ports", systemImage: "slider.horizontal.3", action: customizePorts)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            HStack(spacing: 0) {
                ForEach(tasks) { task in
                    NetworkRouterTaskCell(task: task)
                    if task.id != tasks.last?.id {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.colors.secondaryText.opacity(0.65))
                            .padding(.horizontal, 5)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(12)
        .controlSurface()
    }
}

private struct NetworkRouterTaskCell: View {
    @Environment(\.quilTheme) private var theme
    let task: NetworkRouterTask

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(task.status)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch task.state {
        case .complete: theme.colors.success
        case .ready: theme.colors.info
        case .manual: theme.colors.warning
        case .waiting: theme.colors.secondaryText
        }
    }

    private var symbol: String {
        switch task.state {
        case .complete: "checkmark"
        case .ready: String(task.id) + ".circle.fill"
        case .manual: "hand.raised.fill"
        case .waiting: "hourglass"
        }
    }
}
