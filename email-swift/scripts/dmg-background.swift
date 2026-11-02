// Renders the DMG window background (660x400 pt) at 1x and 2x.
// Usage: swift scripts/dmg-background.swift <out-1x.png> <out-2x.png>
import AppKit

let width: CGFloat = 660
let height: CGFloat = 400
/// Icon centers in Finder coordinates (origin top-left); must match package-dmg.sh.
let appCenter = CGPoint(x: 170, y: 185)
let appsCenter = CGPoint(x: 490, y: 185)

func render(scale: CGFloat, to path: String) throws {
    let pixelsWide = Int(width * scale)
    let pixelsHigh = Int(height * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw NSError(domain: "dmg-background", code: 1) }
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Flip to top-left origin so coordinates match Finder icon positions.
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)

    // Soft vertical gradient.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.975, green: 0.978, blue: 0.990, alpha: 1),
        NSColor(srgbRed: 0.918, green: 0.929, blue: 0.957, alpha: 1),
    ])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

    // Subtle drop zones behind the two icons.
    let zoneColor = NSColor(srgbRed: 0.40, green: 0.45, blue: 0.60, alpha: 0.07)
    for center in [appCenter, appsCenter] {
        let r = NSRect(x: center.x - 78, y: center.y - 78, width: 156, height: 156)
        zoneColor.setFill()
        NSBezierPath(roundedRect: r, xRadius: 28, yRadius: 28).fill()
    }

    // Arrow between the icons.
    let accent = NSColor(srgbRed: 0.32, green: 0.38, blue: 0.55, alpha: 0.55)
    accent.setStroke()
    accent.setFill()
    let startX = appCenter.x + 96
    let endX = appsCenter.x - 96
    let y = appCenter.y
    let shaft = NSBezierPath()
    shaft.lineWidth = 4
    shaft.lineCapStyle = .round
    let dash: [CGFloat] = [1, 12]
    shaft.setLineDash(dash, count: dash.count, phase: 0)
    shaft.move(to: NSPoint(x: startX, y: y))
    shaft.line(to: NSPoint(x: endX - 16, y: y))
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: endX, y: y))
    head.line(to: NSPoint(x: endX - 18, y: y - 11))
    head.line(to: NSPoint(x: endX - 18, y: y + 11))
    head.close()
    head.fill()

    // Caption (drawn in an unflipped sub-context so text is upright).
    ctx.saveGState()
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let title: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.20, green: 0.23, blue: 0.32, alpha: 0.9),
        .paragraphStyle: paragraph,
    ]
    let subtitle: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.35, green: 0.38, blue: 0.47, alpha: 0.85),
        .paragraphStyle: paragraph,
    ]
    // Unflipped: y measured from bottom.
    NSAttributedString(string: "将 Email Vault 拖到「应用程序」完成安装", attributes: title)
        .draw(in: NSRect(x: 0, y: 72, width: width, height: 22))
    NSAttributedString(string: "Drag Email Vault to Applications to install", attributes: subtitle)
        .draw(in: NSRect(x: 0, y: 50, width: width, height: 18))
    ctx.restoreGState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "dmg-background", code: 2)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: dmg-background.swift <out-1x.png> <out-2x.png>\n".utf8))
    exit(2)
}
try render(scale: 1, to: args[1])
try render(scale: 2, to: args[2])
