import AppKit

// Finder uses point coordinates. Store 1x and 2x representations in one TIFF so
// the same layout remains sharp on both standard and Retina displays.
let size = NSSize(width: 720, height: 750)
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

    // The app and Applications shortcut are real Finder icons.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 322, y: 190))
    arrow.line(to: NSPoint(x: 397, y: 190))
    arrow.move(to: NSPoint(x: 378, y: 172))
    arrow.line(to: NSPoint(x: 397, y: 190))
    arrow.line(to: NSPoint(x: 378, y: 208))
    arrow.lineWidth = 7
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.90, alpha: 1).setStroke()
    arrow.stroke()

    text("将“启动台”拖到 Applications 安装",
         in: NSRect(x: 36, y: 270, width: 648, height: 30),
         size: 18, weight: .medium, color: ink, centered: true)
    text("Drag Launchpad to Applications to install",
         in: NSRect(x: 24, y: 306, width: 672, height: 25),
         size: 12, color: secondary, centered: true)
    text("也可双击左侧“启动台”自动安装或更新；若只唤醒旧版，请先退出旧版",
         in: NSRect(x: 24, y: 332, width: 672, height: 18),
         size: 11, color: secondary, centered: true)
    // Installation help stays in the window, using a settings illustration
    // with the app's own name rather than an unrelated third-party app alert.
    let red = NSColor(calibratedRed: 0.78, green: 0.17, blue: 0.16, alpha: 1)
    text("安装后若提示无法打开，请参照下方操作。",
         in: NSRect(x: 36, y: 352, width: 648, height: 25),
         size: 16, weight: .medium, color: red, centered: true)
    text("Confirm the source, then use Privacy & Security → Open Anyway.",
         in: NSRect(x: 36, y: 380, width: 648, height: 21),
         size: 12, color: secondary, centered: true)

    let panel = NSRect(x: 36, y: 412, width: 648, height: 144)
    NSColor(calibratedWhite: 0.975, alpha: 1).setFill()
    NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12).fill()
    NSColor(calibratedWhite: 0.87, alpha: 1).setStroke()
    NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12).stroke()
    NSColor(calibratedRed: 0.16, green: 0.49, blue: 0.93, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 46, y: 426, width: 136, height: 30),
                 xRadius: 6, yRadius: 6).fill()
    if let symbol = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white])) {
        symbol.draw(in: NSRect(x: 54, y: 433, width: 15, height: 15))
    }
    text("隐私与安全性", in: NSRect(x: 76, y: 433, width: 102, height: 20),
         size: 12, weight: .medium, color: .white)
    text("登录密码", in: NSRect(x: 58, y: 472, width: 114, height: 20),
         size: 12, color: secondary)
    text("触控 ID 与密码", in: NSRect(x: 58, y: 506, width: 120, height: 20),
         size: 12, color: secondary)
    text("安全性", in: NSRect(x: 202, y: 430, width: 88, height: 22),
         size: 14, weight: .semibold, color: ink)
    text("系统设置 → 隐私与安全性", in: NSRect(x: 294, y: 432, width: 363, height: 22),
         size: 13, color: red)
    text("已阻止打开“启动台”", in: NSRect(x: 202, y: 474, width: 343, height: 22),
         size: 13, weight: .medium, color: ink)
    text("确认来源可信后，在系统设置中允许打开。",
         in: NSRect(x: 202, y: 503, width: 327, height: 21),
         size: 11, color: secondary)

    let button = NSBezierPath(roundedRect: NSRect(x: 563, y: 494, width: 104, height: 30),
                             xRadius: 7, yRadius: 7)
    NSColor.white.setFill(); button.fill()
    NSColor(calibratedWhite: 0.78, alpha: 1).setStroke(); button.stroke()
    text("仍要打开", in: NSRect(x: 565, y: 501, width: 100, height: 22),
         size: 13, weight: .medium, color: ink, centered: true)
    text("Open Anyway", in: NSRect(x: 561, y: 530, width: 108, height: 18),
         size: 10, color: secondary, centered: true)
    let pointer = NSBezierPath()
    pointer.move(to: NSPoint(x: 513, y: 509)); pointer.line(to: NSPoint(x: 551, y: 509))
    pointer.move(to: NSPoint(x: 543, y: 502)); pointer.line(to: NSPoint(x: 551, y: 509))
    pointer.line(to: NSPoint(x: 543, y: 516))
    pointer.lineWidth = 2; pointer.lineCapStyle = .round; pointer.lineJoinStyle = .round
    red.setStroke(); pointer.stroke()

    text("先尝试打开应用 → 系统设置 → 隐私与安全性 → 仍要打开",
         in: NSRect(x: 36, y: 568, width: 648, height: 21),
         size: 12, color: ink, centered: true)
    text("操作示意 · 请在系统设置中操作 / Illustration only",
         in: NSRect(x: 36, y: 592, width: 648, height: 18),
         size: 10, color: secondary, centered: true)
    NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: 48, y: 616))
    divider.line(to: NSPoint(x: 672, y: 616))
    divider.lineWidth = 1
    divider.stroke()
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(rep)
}

guard let data = image.tiffRepresentation else { fatalError("Could not render DMG background") }
try data.write(to: URL(fileURLWithPath: output))
