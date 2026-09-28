import AppKit

// Finder uses point coordinates. Store 1x and 2x representations in one TIFF so
// the same layout remains sharp on both standard and Retina displays.
let size = NSSize(width: 720, height: 480)
let image = NSImage(size: size)
let output = CommandLine.arguments[1]

func text(_ value: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
          color: NSColor, centered: Bool = false) {
    let style = NSMutableParagraphStyle()
    style.alignment = centered ? .center : .left
    (value as NSString).draw(in: rect, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style
    ])
}

for scale in [1, 2] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: Int(size.width) * scale,
                              pixelsHigh: Int(size.height) * scale,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    // NSGraphicsContext already applies the bitmap representation's point scale.
    context.cgContext.translateBy(x: 0, y: size.height)
    context.cgContext.scaleBy(x: 1, y: -1)
    // Use a flipped context to match Finder's top-to-bottom icon positions.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    NSGradient(starting: NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 1),
               ending: .white)!.draw(in: NSRect(origin: .zero, size: size), angle: 90)
    let ink = NSColor(calibratedWhite: 0.14, alpha: 1)
    let secondary = NSColor(calibratedWhite: 0.42, alpha: 1)
    text("启动台", in: NSRect(x: 36, y: 28, width: 648, height: 43),
         size: 30, weight: .semibold, color: ink)
    text("ClassicLaunchpad · Apple silicon & Intel", in: NSRect(x: 36, y: 76, width: 648, height: 24),
         size: 13, color: secondary)

    // Horizontal installation arrow; the app and folder are real Finder icons.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 321, y: 190))
    arrow.line(to: NSPoint(x: 393, y: 190))
    arrow.move(to: NSPoint(x: 376, y: 173))
    arrow.line(to: NSPoint(x: 393, y: 190))
    arrow.line(to: NSPoint(x: 376, y: 207))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.90, alpha: 1).setStroke()
    arrow.stroke()

    text("拖动安装 · 拖曳安裝 · Drag to install",
         in: NSRect(x: 36, y: 270, width: 648, height: 30),
         size: 18, weight: .medium, color: ink, centered: true)
    text("拖入 Applications 后，再从应用程序打开 / Open from Applications after copying",
         in: NSRect(x: 24, y: 306, width: 672, height: 25),
         size: 12, color: secondary, centered: true)
    NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: 48, y: 342))
    divider.line(to: NSPoint(x: 672, y: 342))
    divider.lineWidth = 1
    divider.stroke()
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(rep)
}

guard let data = image.tiffRepresentation else { fatalError("Could not render DMG background") }
try data.write(to: URL(fileURLWithPath: output))
