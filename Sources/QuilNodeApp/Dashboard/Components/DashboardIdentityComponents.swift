import AppKit
import SwiftUI

struct DashboardCircleIcon: View {
    let systemImage: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct IdentityRow: View {
    let label: String
    let value: String
    let systemImage: String
    var externalURL: URL? = nil
    var showsCopy = true
    let privacyField: PrivacyField?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)
            Group {
                if let externalURL, value != "—" {
                    Button {
                        NSWorkspace.shared.open(externalURL)
                    } label: {
                        PrivacyProtectedText(value: value, field: privacyField)
                            .underline(color: .secondary.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help("Open on Quilscan")
                } else {
                    PrivacyProtectedText(value: value, field: privacyField)
                        .textSelection(.enabled)
                }
            }
            .font(.callout.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            Spacer(minLength: 0)
            if showsCopy, value != "—" {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("Copy \(label)")
            }
            if externalURL != nil, value != "—" {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Opens Quilscan only when clicked")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
    }
}
