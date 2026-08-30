import AppKit
import SwiftUI

extension Color {
    init(themeValue: String?, fallback: Color) {
        guard let themeValue else {
            self = fallback
            return
        }
        if themeValue.hasPrefix("system:") {
            switch themeValue {
            case "system:accent": self = .accentColor
            case "system:primary": self = .primary
            case "system:secondary": self = .secondary
            case "system:window": self = Color(nsColor: .windowBackgroundColor)
            case "system:control": self = Color(nsColor: .controlBackgroundColor)
            case "system:separator": self = Color(nsColor: .separatorColor)
            default: self = fallback
            }
            return
        }

        let raw = themeValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard (raw.count == 6 || raw.count == 8), let value = UInt64(raw, radix: 16) else {
            self = fallback
            return
        }
        let red = Double((value >> (raw.count == 8 ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (raw.count == 8 ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (raw.count == 8 ? 8 : 0)) & 0xFF) / 255
        let alpha = raw.count == 8 ? Double(value & 0xFF) / 255 : 1
        self = Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Font.Design {
    init?(themeValue: String?) {
        guard let themeValue else { return nil }
        switch themeValue.lowercased() {
        case "default": self = .default
        case "rounded": self = .rounded
        case "serif": self = .serif
        case "monospaced": self = .monospaced
        default: return nil
        }
    }
}
