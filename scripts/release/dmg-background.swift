import AppKit

// Builder-only artwork. Geometry comes from build-dmg.sh, shared with Finder.
// Native fonts and a system arrow keep the installer readable and asset-free.
let args = CommandLine.arguments
guard args.count == 7,
    let width = Int(args[2]), let height = Int(args[3]),
    let left = Double(args[4]), let right = Double(args[5]), let iconY = Double(args[6]),
    width >= 500, width <= 1000, height >= 300, height <= 700
else { exit(64) }

let size = NSSize(width: width, height: height)
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width * 2, pixelsHigh: height * 2,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)
else { exit(1) }
bitmap.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.cgContext.scaleBy(x: 2, y: 2)
NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

func label(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    NSAttributedString(
        string: text,
        attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
    ).draw(in: NSRect(x: 24, y: y, width: size.width - 48, height: 40))
}

label(
    "Install QuilNode", y: size.height - 82, font: .systemFont(ofSize: 28, weight: .semibold),
    color: NSColor(calibratedWhite: 0.13, alpha: 1))
label(
    "Drag QuilNode into Applications.", y: size.height - 115, font: .systemFont(ofSize: 15),
    color: NSColor(calibratedWhite: 0.35, alpha: 1))
let accent = NSColor(calibratedRed: 0.05, green: 0.50, blue: 0.76, alpha: 1)
if let arrow = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(pointSize: 32, weight: .medium))?
    .withSymbolConfiguration(.init(paletteColors: [accent]))
{
    arrow.draw(in: NSRect(x: (left + right) / 2 - 22, y: Double(height) - iconY - 22, width: 44, height: 44))
}
label(
    "Then open QuilNode from Applications.", y: 46, font: .systemFont(ofSize: 13),
    color: NSColor(calibratedWhite: 0.32, alpha: 1))
label(
    "Apple Silicon  ·  macOS 14 or later", y: 12, font: .systemFont(ofSize: 11),
    color: NSColor(calibratedWhite: 0.43, alpha: 1))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[1]), options: .withoutOverwriting)
