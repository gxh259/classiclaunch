import AppKit
import QuartzCore
import Carbon
import ServiceManagement
import SQLite3

struct AppEntry {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage
}

enum LauncherIcon {
    static func original() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    static func dockImage(from original: NSImage) -> NSImage {
        NSImage(size: original.size, flipped: false) { rect in
            let inset = rect.width * 0.06
            original.draw(in: rect.insetBy(dx: inset, dy: inset))
            return true
        }
    }
}

enum GridLayout: Equatable {
    case fiveBySeven, sixByEight, sevenByEight, sevenByNine
    case custom(rows: Int, columns: Int)

    static let presets: [GridLayout] = [.fiveBySeven, .sixByEight, .sevenByEight, .sevenByNine]
    static let allowedRows = 2...12
    static let allowedColumns = 3...16

    init?(rawValue: String) {
        switch rawValue {
        case "5×7": self = .fiveBySeven
        case "6×8": self = .sixByEight
        case "7×8": self = .sevenByEight
        case "7×9": self = .sevenByNine
        case "7×7": self = .custom(rows: 7, columns: 7) // Preserve existing layouts.
        default:
            guard rawValue.hasPrefix("custom:") else { return nil }
            let values = rawValue.dropFirst("custom:".count).split(separator: "×")
            guard values.count == 2, let rows = Int(values[0]), let columns = Int(values[1]),
                  Self.allowedRows.contains(rows), Self.allowedColumns.contains(columns) else { return nil }
            self = .custom(rows: rows, columns: columns)
        }
    }

    var rawValue: String {
        switch self {
        case .fiveBySeven: "5×7"
        case .sixByEight: "6×8"
        case .sevenByEight: "7×8"
        case .sevenByNine: "7×9"
        case let .custom(rows, columns): "custom:\(rows)×\(columns)"
        }
    }

    var rows: Int {
        switch self {
        case .fiveBySeven: 5
        case .sixByEight: 6
        case .sevenByEight, .sevenByNine: 7
        case let .custom(rows, _): rows
        }
    }

    var columns: Int {
        switch self {
        case .fiveBySeven: 7
        case .sixByEight, .sevenByEight: 8
        case .sevenByNine: 9
        case let .custom(_, columns): columns
        }
    }
}

enum LauncherTheme: String, CaseIterable {
    case light, dark, system

    var title: String {
        switch self {
        case .light: L("明亮")
        case .dark: L("黑暗")
        case .system: L("跟随系统")
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}

// Borderless NSWindow instances do not accept keyboard focus by default.
final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RenamePanel: NSPanel {
    let nameField = NSTextField(frame: NSRect(x: 24, y: 68, width: 352, height: 30))

    init(title: String, currentName: String, parentLevel: NSWindow.Level) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
                   styleMask: [.titled], backing: .buffered, defer: false)
        self.title = title
        level = NSWindow.Level(rawValue: parentLevel.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .windowBackgroundColor
        isOpaque = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        center()
        let label = NSTextField(labelWithString: L("名称"))
        label.frame = NSRect(x: 24, y: 108, width: 352, height: 24)
        contentView?.addSubview(label)
        nameField.stringValue = currentName
        contentView?.addSubview(nameField)
        let cancel = NSButton(title: L("取消"), target: self, action: #selector(cancelRename(_:)))
        cancel.frame = NSRect(x: 216, y: 18, width: 76, height: 32)
        contentView?.addSubview(cancel)
        let save = NSButton(title: L("保存"), target: self, action: #selector(saveRename(_:)))
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 300, y: 18, width: 76, height: 32)
        contentView?.addSubview(save)
    }

    @objc private func cancelRename(_ sender: Any?) {
        NSApp.stopModal(withCode: .alertSecondButtonReturn)
    }

    @objc private func saveRename(_ sender: Any?) {
        NSApp.stopModal(withCode: .alertFirstButtonReturn)
    }
}

final class SettingsCanvas: NSView {
    override var isFlipped: Bool { true }
}

// Dark mode renders its wallpaper inside the launcher. Light mode leaves this
// view clear so the separate visual-effect layer can show the desktop beneath.
final class WallpaperView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var showsWallpaper = true { didSet { needsDisplay = true } }
    var onAppearanceChanged: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?()
    }

    override func draw(_ dirtyRect: NSRect) {
        if !showsWallpaper {
            NSColor.clear.setFill()
            bounds.fill(using: .copy)
            return
        }
        NSColor(calibratedWhite: 0.23, alpha: 1).setFill()
        bounds.fill()
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let destination = NSRect(x: bounds.midX - size.width / 2,
                                 y: bounds.midY - size.height / 2,
                                 width: size.width, height: size.height)
        NSGraphicsContext.current?.saveGraphicsState()
        bounds.clip()
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

final class AppCatalog {
    private(set) static var lastDockDatabaseOpened = false
    private(set) static var lastDockAppCount = 0
    private(set) static var lastApplicationsCount = 0
    static var includeDockSystemApps: Bool {
        LauncherStore.shared.data.preferences.includeDockSystemApps
    }

    static func load() -> [AppEntry] {
        lastDockDatabaseOpened = false
        let dockURLs = loadDockLaunchpadApps()
        lastDockAppCount = dockURLs.count
        let manager = FileManager.default
        let rootURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        var applicationURLs: [URL] = []
        var directories: [(URL, Int)] = [(rootURL, 0)]
        while let (directory, depth) = directories.popLast() {
            guard let children = try? manager.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []) else { continue }
            for url in children {
                guard !url.lastPathComponent.hasPrefix(".") else { continue }
                if url.pathExtension.lowercased() == "app" {
                    // Finder also shows app links such as /Applications/Safari.app.
                    // The skipsHiddenFiles option unexpectedly filters that link.
                    if manager.fileExists(atPath: url.path) { applicationURLs.append(url) }
                    continue
                }
                guard depth < 3,
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isDirectory == true, values.isSymbolicLink != true else { continue }
                directories.append((url, depth + 1))
            }
        }
        lastApplicationsCount = applicationURLs.count
        // Finder presents these system apps inside its Utilities folder too.
        let systemUtilities = URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true)
        if let children = try? manager.contentsOfDirectory(at: systemUtilities,
            includingPropertiesForKeys: nil, options: []) {
            applicationURLs += children.filter {
                !$0.lastPathComponent.hasPrefix(".") &&
                $0.pathExtension.lowercased() == "app" &&
                manager.fileExists(atPath: $0.path)
            }
        }
        var byPath: [String: URL] = [:]
        for url in applicationURLs { byPath[url.standardizedFileURL.path] = url }
        for url in dockURLs {
            let path = url.standardizedFileURL.path
            if path.hasPrefix("/Applications/") || includeDockSystemApps {
                if byPath[path] == nil { byPath[path] = url }
            }
        }
        let urls = byPath.values.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let groups = Dictionary(grouping: urls) { Bundle(url: $0)?.bundleIdentifier ?? "" }
        let primaryPath = groups.mapValues { $0.last?.standardizedFileURL.path ?? "" }
        let entries = urls.map { url -> AppEntry in
            let path = url.standardizedFileURL.path
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier ?? ""
            let id = !bundleID.isEmpty && primaryPath[bundleID] == path
                ? bundleID : "path:\(path)"
            return AppEntry(id: id, name: visibleName(at: url, bundle: bundle, manager: manager), url: url,
                            icon: NSWorkspace.shared.icon(forFile: path))
        }
        return entries.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func visibleName(at url: URL, bundle: Bundle?, manager: FileManager) -> String {
        if let bundle {
            let languages = Bundle.preferredLocalizations(
                from: bundle.localizations, forPreferences: Locale.preferredLanguages)
            let table: [String: [String: Any]]? = bundle.url(forResource: "InfoPlist", withExtension: "loctable")
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: [String: Any]] }
            for language in languages {
                let normalized = language.replacingOccurrences(of: "-", with: "_")
                let tableValues = table?[language] ?? table?.first(where: {
                    $0.key.replacingOccurrences(of: "-", with: "_")
                        .caseInsensitiveCompare(normalized) == .orderedSame
                })?.value
                if let tableValues, let name = localizedName(in: tableValues) { return name }
                if let stringsURL = bundle.url(forResource: "InfoPlist", withExtension: "strings",
                                               subdirectory: nil, localization: language),
                   let data = try? Data(contentsOf: stringsURL),
                   let values = try? PropertyListSerialization.propertyList(from: data, format: nil)
                       as? [String: Any],
                   let name = localizedName(in: values) {
                    return name
                }
            }
        }
        let finderName = manager.displayName(atPath: url.path)
        return finderName.hasSuffix(".app")
            ? String(finderName.dropLast(4)) : finderName
    }

    private static func localizedName(in values: [String: Any]) -> String? {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let value = values[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    // The old Dock Launchpad database may still contain system apps that are
    // absent from /Applications. Its schema and contents are private, so this
    // source is read-only and each bookmark is checked against a live bundle.
    private static func loadDockLaunchpadApps() -> [URL] {
        guard let databaseURL = dockDatabaseURL() else { return [] }
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            if database != nil { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database,
            "SELECT bundleid, bookmark FROM apps WHERE bookmark IS NOT NULL", -1,
            &statement, nil) == SQLITE_OK, let statement else { return [] }
        defer { sqlite3_finalize(statement) }
        lastDockDatabaseOpened = true

        let manager = FileManager.default
        var result: [URL] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idBytes = sqlite3_column_text(statement, 0),
                  let bookmarkBytes = sqlite3_column_blob(statement, 1) else { continue }
            let databaseID = String(cString: idBytes)
            let bookmark = Data(bytes: bookmarkBytes, count: Int(sqlite3_column_bytes(statement, 1)))
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI],
                                     relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasSuffix(".app"),
                  path.hasPrefix("/Applications/") ||
                  path.hasPrefix("/System/Applications/") ||
                  path.hasPrefix(NSHomeDirectory() + "/Applications/"),
                  manager.fileExists(atPath: path),
                  let bundleID = Bundle(url: url)?.bundleIdentifier,
                  bundleID == databaseID else { continue }
            result.append(url)
        }
        return result
    }

    private static func dockDatabaseURL() -> URL? {
        var roots: [URL] = []
        let length = confstr(_CS_DARWIN_USER_DIR, nil, 0)
        if length > 0 {
            var buffer = [CChar](repeating: 0, count: length)
            if confstr(_CS_DARWIN_USER_DIR, &buffer, length) > 0 {
                roots.append(URL(fileURLWithPath: String(cString: buffer), isDirectory: true))
            }
        }
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL
        if temporary.lastPathComponent == "T" {
            roots.append(temporary.deletingLastPathComponent().appendingPathComponent("0", isDirectory: true))
        }
        for root in roots {
            let candidate = root.appendingPathComponent("com.apple.dock.launchpad/db/db")
            if FileManager.default.isReadableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}

private struct PageScrollState {
    private var accumulatedDelta: CGFloat = 0
    private var gestureConsumed = false
    private var lastEventAt: TimeInterval = -.infinity
    private var lastPageChangeAt: TimeInterval = -.infinity

    mutating func direction(delta: CGFloat, precise: Bool, phase: NSEvent.Phase,
                            momentum: NSEvent.Phase, at time: TimeInterval) -> Int? {
        guard momentum.isEmpty, abs(delta) > 0.01 else { return nil }
        if precise {
            if phase.contains(.began) || time - lastEventAt > 0.38 {
                accumulatedDelta = 0
                gestureConsumed = false
            }
            lastEventAt = time
            guard !gestureConsumed else { return nil }
            accumulatedDelta += delta
            guard abs(accumulatedDelta) >= 28 else { return nil }
            gestureConsumed = true
        } else {
            guard time - lastPageChangeAt >= 0.3, abs(delta) >= 1 else { return nil }
        }
        lastPageChangeAt = time
        return delta < 0 ? 1 : -1
    }
}

// Kept outside GridView's animated layer so only the icons move between pages.
final class PageIndicatorView: NSView {
    var pageCount = 1 { didSet { needsDisplay = true } }
    var page = 0 { didSet { needsDisplay = true } }
    var dotY: CGFloat = 92 { didSet { needsDisplay = true } }
    var onSelectPage: ((Int) -> Void)?
    var onScroll: ((NSEvent) -> Void)?
    var onSwipe: ((NSEvent) -> Void)?

    private var capsule: NSRect {
        let width = CGFloat(pageCount) * 18
        return NSRect(x: (bounds.width - width) / 2 - 8,
                      y: dotY - 9, width: width + 16, height: 26)
    }

    func pageIndex(at point: NSPoint) -> Int? {
        guard pageCount > 1, capsule.insetBy(dx: -3, dy: -7).contains(point) else { return nil }
        let startX = (bounds.width - CGFloat(pageCount) * 18) / 2
        return min(max(Int((point.x - startX) / 18), 0), pageCount - 1)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard pageCount > 1 else { return }
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let ink = dark ? NSColor.white : NSColor.black
        (dark ? NSColor.black.withAlphaComponent(0.25) : NSColor.white.withAlphaComponent(0.70)).setFill()
        NSBezierPath(roundedRect: capsule, xRadius: 13, yRadius: 13).fill()
        let startX = (bounds.width - CGFloat(pageCount) * 18) / 2
        for index in 0..<pageCount {
            (index == page ? ink : ink.withAlphaComponent(0.35)).setFill()
            NSBezierPath(ovalIn: NSRect(x: startX + CGFloat(index) * 18 + 5,
                                        y: dotY, width: 7, height: 7)).fill()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return pageIndex(at: local) == nil ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = pageIndex(at: point) { onSelectPage?(index) }
    }

    override func scrollWheel(with event: NSEvent) { onScroll?(event) }
    override func swipe(with event: NSEvent) { onSwipe?(event) }
}

final class GridView: NSView {
    var tiles: [DisplayTile] = [] { didSet { resetPointerGestures(); page = 0; needsDisplay = true } }
    var statusMessage: String? { didSet { needsDisplay = true } }
    var page = 0 { didSet { needsDisplay = true; onPageChanged?() } }
    var layout: GridLayout = .fiveBySeven { didSet { page = 0; needsDisplay = true } }
    var layoutLocked = false
    var onSelect: ((DisplayTile) -> Void)?
    var onDrop: ((DisplayTile, DisplayTile?, Bool) -> Void)?
    var onContext: ((DisplayTile, NSEvent) -> Void)?
    var onDismiss: (() -> Void)?
    var onCloseFolder: (() -> Void)?
    var onPageChanged: (() -> Void)?
    var folderMode = false { didSet { page = 0; needsDisplay = true } }
    var folderName = "" { didSet { needsDisplay = true } }
    var dockBottomInset: CGFloat = 0 { didSet { needsDisplay = true } }
    override var acceptsFirstResponder: Bool { true }

    private var mouseDrag = MousePageDragState()
    private var threeFingerSwipe = ThreeFingerSwipeState()
    private var lastTrackpadPageAt: TimeInterval = -.infinity
    private var scrollState = PageScrollState()
    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    private var labelColor: NSColor { folderMode && !isDark ? .black : .white }
    private var titleShadow: NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        return shadow
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private var columns: Int { layout.columns }
    private var rows: Int {
        folderMode ? min(3, max(1, (tiles.count + columns - 1) / columns)) : layout.rows
    }
    private var pageSize: Int { columns * rows }
    private var pageCount: Int { max(1, (tiles.count + pageSize - 1) / pageSize) }
    var numberOfPages: Int { pageCount }
    private var pageIndicatorY: CGFloat {
        folderMode ? folderPanel().minY + 20 : max(92, dockBottomInset + 30)
    }
    var indicatorBaselineY: CGFloat { pageIndicatorY }

    private func geometry() -> (NSRect, CGFloat, CGFloat) {
        if folderMode {
            let panel = folderPanel()
            let cellW = (panel.width - 88) / CGFloat(columns)
            let cellH = min(185, (panel.height - 90) / CGFloat(rows))
            return (NSRect(x: panel.minX + 44, y: panel.maxY - 38 - CGFloat(rows) * cellH,
                           width: CGFloat(columns) * cellW, height: CGFloat(rows) * cellH), cellW, cellH)
        }
        let cellW = min(260, (bounds.width - 110) / CGFloat(columns))
        let topInset: CGFloat = 125
        let bottomInset = pageIndicatorY + 42
        let cellH = min(215, max(1, (bounds.height - topInset - bottomInset) / CGFloat(rows)))
        return (NSRect(x: (bounds.width - CGFloat(columns) * cellW) / 2,
                       y: bounds.height - topInset - CGFloat(rows) * cellH,
                       width: CGFloat(columns) * cellW,
                       height: CGFloat(rows) * cellH), cellW, cellH)
    }

    private func folderPanel() -> NSRect {
        let width = min(bounds.width - 80, bounds.width * 0.84)
        let height = min(bounds.height - 210, 300 + CGFloat(rows - 1) * 180)
        return NSRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2,
                      width: width, height: height)
    }

    private func tileIndex(at point: NSPoint) -> Int? {
        let (rect, cellW, cellH) = geometry()
        guard rect.contains(point) else { return nil }
        let col = Int((point.x - rect.minX) / cellW)
        let row = Int((rect.maxY - point.y) / cellH)
        guard col >= 0, col < columns, row >= 0, row < rows else { return nil }
        let index = page * pageSize + row * columns + col
        return index < tiles.count ? index : nil
    }

    private func interactiveTileIndex(at point: NSPoint) -> Int? {
        guard let index = tileIndex(at: point) else { return nil }
        let (rect, cellW, cellH) = geometry()
        let local = index - page * pageSize
        let x = rect.minX + CGFloat(local % columns) * cellW
        let y = rect.maxY - CGFloat(local / columns + 1) * cellH
        let (icon, label) = tileFrames(x: x, y: y, cellW: cellW, cellH: cellH)
        return icon.insetBy(dx: -5, dy: -5).contains(point) || label.contains(point) ? index : nil
    }

    private func tileFrames(x: CGFloat, y: CGFloat, cellW: CGFloat, cellH: CGFloat) -> (NSRect, NSRect) {
        let labelHeight = min(31, max(12, cellH * 0.27))
        let iconSize = max(12, min(112, cellW - 12, cellH - labelHeight - 5))
        let icon = NSRect(x: x + (cellW - iconSize) / 2,
                          y: y + labelHeight + max(2, (cellH - labelHeight - iconSize) / 2),
                          width: iconSize, height: iconSize)
        let label = NSRect(x: x + 3, y: y + 2, width: cellW - 6, height: labelHeight)
        return (icon, label)
    }

    override func draw(_ dirtyRect: NSRect) {
        let cols = columns, count = pageCount
        if page >= count { page = count - 1 }
        let (rect, cellW, cellH) = geometry()
        if folderMode {
            NSColor.black.withAlphaComponent(0.18).setFill()
            bounds.fill()
            let panel = folderPanel()
            (isDark ? NSColor.black.withAlphaComponent(0.62) : NSColor.white.withAlphaComponent(0.90)).setFill()
            NSBezierPath(roundedRect: panel, xRadius: 39, yRadius: 39).fill()
            let titleStyle = NSMutableParagraphStyle(); titleStyle.alignment = .center
            (folderName as NSString).draw(in: NSRect(x: panel.minX, y: panel.maxY + 25,
                                                     width: panel.width, height: 40),
                withAttributes: [.font: NSFont.systemFont(ofSize: 29, weight: .medium),
                                 .foregroundColor: NSColor.white, .shadow: titleShadow,
                                 .paragraphStyle: titleStyle])
        }
        let start = page * pageSize
        let end = min(start + pageSize, tiles.count)
        if start < end {
            for index in start..<end {
                let local = index - start
                let col = local % cols, row = local / cols
                let x = rect.minX + CGFloat(col) * cellW
                let y = rect.maxY - CGFloat(row + 1) * cellH
                let (iconRect, titleRect) = tileFrames(x: x, y: y, cellW: cellW, cellH: cellH)
                let iconSize = iconRect.width
                let tile = tiles[index]
                if tile.ref.kind == "folder" {
                    (isDark ? NSColor.white.withAlphaComponent(0.58) : NSColor.white.withAlphaComponent(0.85)).setFill()
                    NSBezierPath(roundedRect: iconRect, xRadius: iconSize * 0.2,
                                 yRadius: iconSize * 0.2).fill()
                    let padding = max(2, iconSize * 0.08)
                    let gap = max(1, iconSize * 0.04)
                    let miniSize = max(2, (iconSize - 2 * padding - 2 * gap) / 3)
                    for (number, icon) in tile.icons.prefix(9).enumerated() {
                        icon.draw(in: NSRect(x: iconRect.minX + padding + CGFloat(number % 3) * (miniSize + gap),
                                             y: iconRect.minY + padding + CGFloat(2 - number / 3) * (miniSize + gap),
                                             width: miniSize, height: miniSize))
                    }
                } else { tile.icons.first?.draw(in: iconRect) }
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineBreakMode = .byTruncatingTail
                (tile.title as NSString).draw(in: titleRect, withAttributes: [
                    .font: NSFont.systemFont(ofSize: min(16, max(9, cellH * 0.23)), weight: .medium),
                    .foregroundColor: labelColor,
                    .shadow: folderMode && !isDark ? NSShadow() : titleShadow,
                    .paragraphStyle: paragraph
                ])
            }
        }
        if tiles.isEmpty && statusMessage == nil {
            let style = NSMutableParagraphStyle(); style.alignment = .center
            (L("没有找到应用") as NSString).draw(in: NSRect(x: 0, y: bounds.midY, width: bounds.width, height: 40),
                withAttributes: [.font: NSFont.systemFont(ofSize: 20),
                                 .foregroundColor: labelColor, .shadow: titleShadow, .paragraphStyle: style])
        }
        if let statusMessage {
            let width = min(720, bounds.width - 80)
            let box = NSRect(x: (bounds.width - width) / 2, y: 83, width: width, height: 46)
            NSColor.black.withAlphaComponent(0.45).setFill()
            NSBezierPath(roundedRect: box, xRadius: 23, yRadius: 23).fill()
            let style = NSMutableParagraphStyle(); style.alignment = .center
            (statusMessage as NSString).draw(in: box.insetBy(dx: 12, dy: 11),
                withAttributes: [.font: NSFont.systemFont(ofSize: 15, weight: .medium),
                                 .foregroundColor: NSColor.white, .paragraphStyle: style])
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        mouseDrag.begin(at: p, source: interactiveTileIndex(at: p), time: event.timestamp)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let direction = mouseDrag.direction(at: point, time: event.timestamp, layoutLocked: layoutLocked) {
            goToPage(page + direction)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDrag.isActive else { return }
        let point = convert(event.locationInWindow, from: nil)
        defer { mouseDrag = MousePageDragState() }
        if let direction = mouseDrag.direction(at: point, time: event.timestamp, layoutLocked: layoutLocked) {
            goToPage(page + direction)
        }
        if !mouseDrag.moved {
            if let source = mouseDrag.source, source < tiles.count { onSelect?(tiles[source]) }
            else if folderMode {
                if !folderPanel().contains(point) { onCloseFolder?() }
            } else { onDismiss?() }
            return
        }
        guard mouseDrag.intent == .rearrange, !layoutLocked,
              let sourceIndex = mouseDrag.source, sourceIndex < tiles.count else { return }
        let destinationIndex = tileIndex(at: point)
        if destinationIndex == sourceIndex { return }
        let target = destinationIndex.flatMap { $0 == sourceIndex ? nil : tiles[$0] }
        let (rect, cellW, _) = geometry()
        let fraction = ((point.x - rect.minX).truncatingRemainder(dividingBy: cellW)) / cellW
        let createFolder = target != nil && fraction > 0.27 && fraction < 0.73
        onDrop?(tiles[sourceIndex], target, createFolder)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = tileIndex(at: point) { onContext?(tiles[index], event) }
    }

    override func scrollWheel(with event: NSEvent) {
        guard !mouseDrag.isActive, !threeFingerSwipe.isTracking,
              ProcessInfo.processInfo.systemUptime - lastTrackpadPageAt > 0.4 else { return }
        let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
            ? event.scrollingDeltaY : event.scrollingDeltaX
        guard let direction = scrollState.direction(delta: delta,
            precise: event.hasPreciseScrollingDeltas, phase: event.phase,
            momentum: event.momentumPhase, at: ProcessInfo.processInfo.systemUptime) else { return }
        goToPage(page + direction)
    }

    override func touchesBegan(with event: NSEvent) { handleTouches(event) }
    override func touchesMoved(with event: NSEvent) { handleTouches(event) }
    override func touchesEnded(with event: NSEvent) {
        let consumed = threeFingerSwipe.consumed
        handleTouches(event)
        if consumed && !threeFingerSwipe.isTracking { lastTrackpadPageAt = ProcessInfo.processInfo.systemUptime }
    }
    override func touchesCancelled(with event: NSEvent) {
        if threeFingerSwipe.consumed { lastTrackpadPageAt = ProcessInfo.processInfo.systemUptime }
        threeFingerSwipe.reset()
    }

    private func handleTouches(_ event: NSEvent) {
        guard !mouseDrag.isActive else { threeFingerSwipe.reset(); return }
        let points = Dictionary(uniqueKeysWithValues: event.touches(matching: .touching, in: self)
            .filter { $0.type == .indirect }.compactMap { touch -> (AnyHashable, NSPoint)? in
                guard let identity = touch.identity as? AnyHashable else { return nil }
                return (identity, touch.normalizedPosition)
            })
        if let direction = threeFingerSwipe.direction(touches: points) {
            lastTrackpadPageAt = ProcessInfo.processInfo.systemUptime
            goToPage(page + direction)
        }
    }

    override func swipe(with event: NSEvent) {
        guard !mouseDrag.isActive,
              let direction = ThreeFingerSwipeState.nativeDirection(deltaX: event.deltaX, deltaY: event.deltaY),
              !threeFingerSwipe.consumed,
              ProcessInfo.processInfo.systemUptime - lastTrackpadPageAt > 0.4 else { return }
        if threeFingerSwipe.isTracking { threeFingerSwipe.consume() }
        lastTrackpadPageAt = ProcessInfo.processInfo.systemUptime
        goToPage(page + direction)
    }

    func resetPointerGestures() {
        mouseDrag = MousePageDragState()
        threeFingerSwipe.reset()
        lastTrackpadPageAt = -.infinity
    }

    func goToPage(_ next: Int) {
        guard next != page, next >= 0, next < pageCount else { return }
        if let layer {
            let transition = CATransition()
            transition.type = .push
            transition.subtype = next > page ? .fromRight : .fromLeft
            transition.duration = 0.22
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(transition, forKey: "pageTransition")
        }
        page = next
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onDismiss?()
        case 123: goToPage(page - 1)
        case 124: goToPage(page + 1)
        default: super.keyDown(with: event)
        }
    }
}

final class LauncherController: NSObject, NSApplicationDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    private let store = LauncherStore.shared
    private var window: NSWindow!
    private var wallpaperView: WallpaperView!
    private var backgroundEffect: NSVisualEffectView!
    private var wallpaperURL: URL?
    private var grid: GridView!
    private var pageIndicator: PageIndicatorView!
    private var search: NSSearchField!
    private var settingsButton: NSButton!
    private var settingsPanel: NSPanel?
    private var settingsScrollView: NSScrollView?
    private var customRowsField: NSTextField?
    private var customColumnsField: NSTextField?
    private var refreshButton: NSButton!
    private var model: LauncherModel!
    private var activeFolderID: String?
    private var contextRef: TileRef?
    private var hiddenMenuIDs: [String] = []
    private var statusItem: NSStatusItem?
    private var hotkeyManager: HotkeyManager!
    private var currentShortcut: Shortcut = .fallback
    private var cornerEnteredAt: Date?
    private var cornerArmed = true
    private var scanFeedbackTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if offerInstallationIfNeeded() { return }
        do { try LoginStartup.shared.migrateLegacyIfNeeded(appURL: Bundle.main.bundleURL) }
        catch { NSLog("Could not migrate login item: %@", error.localizedDescription) }
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        window = LauncherWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = NSColor(calibratedWhite: 0.23, alpha: 1)
        window.isOpaque = true
        window.hasShadow = false
        window.title = L("启动台")
        grid = GridView(frame: NSRect(origin: .zero, size: frame.size))
        grid.wantsLayer = true
        grid.dockBottomInset = max(0, screen.visibleFrame.minY - frame.minY)
        grid.autoresizingMask = [.width, .height]
        if let saved = store.data.preferences.gridLayout,
           let layout = GridLayout(rawValue: saved) { grid.layout = layout }
        grid.layoutLocked = store.data.preferences.lockLayout
        grid.onDismiss = { [weak self] in
            guard let self else { return }
            if self.settingsPanel?.isVisible == true { self.closeSettingsPanel() }
            else { self.window.orderOut(nil) }
        }
        grid.onCloseFolder = { [weak self] in self?.closeFolder(nil) }
        grid.onSelect = { [weak self] tile in
            guard let self else { return }
            if self.settingsPanel?.isVisible == true { self.closeSettingsPanel() }
            else { self.select(tile) }
        }
        grid.onDrop = { [weak self] source, target, makeFolder in
            guard let self, self.settingsPanel?.isVisible != true else { return }
            self.drop(source, target, makeFolder)
        }
        grid.onContext = { [weak self] tile, event in
            guard let self, self.settingsPanel?.isVisible != true else { return }
            self.showContextMenu(tile, event: event)
        }
        wallpaperView = WallpaperView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = wallpaperView
        backgroundEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        backgroundEffect.state = .active
        backgroundEffect.isEmphasized = false
        backgroundEffect.autoresizingMask = [.width, .height]
        wallpaperView.addSubview(backgroundEffect)
        // Keep the material out of the animated icon layer.
        let backdrop = NSView(frame: NSRect(origin: .zero, size: frame.size))
        backdrop.autoresizingMask = [.width, .height]
        wallpaperView.addSubview(backdrop)
        wallpaperView.onAppearanceChanged = { [weak self] in self?.updateBackgroundAppearance() }
        backdrop.addSubview(grid)
        pageIndicator = PageIndicatorView(frame: NSRect(origin: .zero, size: frame.size))
        pageIndicator.autoresizingMask = [.width, .height]
        pageIndicator.onSelectPage = { [weak self] index in self?.grid.goToPage(index) }
        pageIndicator.onScroll = { [weak self] event in self?.grid.scrollWheel(with: event) }
        pageIndicator.onSwipe = { [weak self] event in self?.grid.swipe(with: event) }
        backdrop.addSubview(pageIndicator)
        grid.onPageChanged = { [weak self] in self?.updatePageIndicator() }
        search = NSSearchField(frame: NSRect(x: (frame.width - 360) / 2,
                                           y: frame.height - 105, width: 360, height: 36))
        search.placeholderString = L("搜索应用")
        search.delegate = self
        search.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        backdrop.addSubview(search)
        settingsButton = NSButton(frame: NSRect(x: (frame.width - 360) / 2 + 370,
                                                y: frame.height - 103, width: 36, height: 32))
        settingsButton.bezelStyle = .regularSquare
        if let gear = NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("设置")) {
            settingsButton.image = gear.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)) ?? gear
            settingsButton.imagePosition = .imageOnly
        } else { settingsButton.title = "⚙" }
        settingsButton.isBordered = false
        settingsButton.contentTintColor = .labelColor
        settingsButton.toolTip = L("设置")
        settingsButton.target = self
        settingsButton.action = #selector(showSettings(_:))
        settingsButton.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        backdrop.addSubview(settingsButton)
        refreshButton = NSButton(frame: NSRect(x: (frame.width - 360) / 2 + 412,
                                               y: frame.height - 103, width: 36, height: 32))
        refreshButton.bezelStyle = .regularSquare
        if let refresh = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: L("重新扫描应用")) {
            refreshButton.image = refresh.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 19, weight: .medium)) ?? refresh
            refreshButton.imagePosition = .imageOnly
        } else { refreshButton.title = "↻" }
        refreshButton.isBordered = false
        refreshButton.contentTintColor = .labelColor
        refreshButton.toolTip = L("重新扫描应用")
        refreshButton.target = self
        refreshButton.action = #selector(rescan(_:))
        refreshButton.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        backdrop.addSubview(refreshButton)
        updateScreenGeometry(for: screen)
        applyTheme()
        model = LauncherModel()
        refreshGrid()
        updateStatusItemVisibility()
        hotkeyManager = HotkeyManager()
        hotkeyManager.onPressed = { [weak self] in self?.toggleLauncher(nil) }
        let savedCode = store.data.preferences.hotkeyCode ?? 0
        let savedModifiers = store.data.preferences.hotkeyModifiers ?? 0
        if savedCode > 0 && savedModifiers > 0 {
            currentShortcut = Shortcut(keyCode: UInt32(savedCode), modifiers: UInt32(savedModifiers),
                label: store.data.preferences.hotkeyLabel ?? L("快捷键"))
        }
        if !hotkeyManager.register(currentShortcut) { NSLog("Could not register global shortcut") }
        Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(checkHotCorner(_:)),
                             userInfo: nil, repeats: true)
        NotificationCenter.default.addObserver(self, selector: #selector(systemLocaleDidChange(_:)),
                                               name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        if !launchedAtLogin { show() }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if NSApp.modalWindow != nil { return event }
            if event.keyCode == 53 {
                if self.settingsPanel?.isVisible == true { self.closeSettingsPanel() }
                else if self.activeFolderID != nil { self.closeFolder(nil) }
                else { self.window.orderOut(nil) }
                return nil
            }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "r" {
                self.rescan(nil); return nil
            }
            return event
        }
    }

    private var launchedAtLogin: Bool {
        if ProcessInfo.processInfo.arguments.contains("--login") { return true }
        guard let launchEvent = NSAppleEventManager.shared().currentAppleEvent,
              launchEvent.eventID == kAEOpenApplication,
              let source = launchEvent.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return source.enumCodeValue == keyAELaunchedAsLogInItem ||
               source.typeCodeValue == keyAELaunchedAsLogInItem
    }

    private func offerInstallationIfNeeded() -> Bool {
        let appURL = Bundle.main.bundleURL.standardizedFileURL
        guard appURL.pathExtension.lowercased() == "app",
              appURL.deletingLastPathComponent().path != "/Applications" else { return false }
        let alert = NSAlert()
        alert.messageText = L("安装启动台")
        let hasShortcut = ["Applications", "应用程序"].contains { name in
            FileManager.default.fileExists(atPath:
                appURL.deletingLastPathComponent().appendingPathComponent(name).path)
        }
        alert.informativeText = hasShortcut
            ? L("请将“启动台.app”拖到旁边的应用程序文件夹快捷方式。安装完成后，从“应用程序”打开启动台。")
            : L("请在访达中将“启动台.app”拖到“应用程序”（/Applications）。安装完成后，从“应用程序”打开启动台。")
        alert.addButton(withTitle: L("在访达中显示"))
        alert.addButton(withTitle: L("暂时运行"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return true
        }
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show(); return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        closeSettingsPanel()
        window?.orderOut(nil)
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        guard window != nil, let screen = preferredScreen() else { return }
        updateScreenGeometry(for: screen)
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel === settingsPanel else { return }
        window.removeChildWindow(panel)
        settingsPanel = nil
        settingsScrollView = nil
        if NSApp.isActive && window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(search)
        }
    }

    private func applyTheme() {
        let theme = LauncherTheme(rawValue: store.data.preferences.theme) ?? .system
        window.appearance = theme.appearance
        updateBackgroundAppearance()
        grid.needsDisplay = true
        pageIndicator?.needsDisplay = true
    }

    private func updateBackgroundAppearance() {
        guard window != nil, backgroundEffect != nil else { return }
        let light = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) != .darkAqua
        window.isOpaque = !light
        window.backgroundColor = light ? .clear : NSColor(calibratedWhite: 0.23, alpha: 1)
        wallpaperView.showsWallpaper = !light
        backgroundEffect.material = .fullScreenUI
        backgroundEffect.blendingMode = light ? .behindWindow : .withinWindow
    }

    private func applyLanguage() {
        window.title = L("启动台")
        search.placeholderString = L("搜索应用")
        settingsButton.toolTip = L("设置")
        refreshButton.toolTip = L("重新扫描应用")
        statusItem?.button?.toolTip = L("启动台")
        settingsPanel?.title = L("启动台设置")
        NSApp.mainMenu?.items.first?.submenu?.items.first?.title = L("退出启动台")
        scanFeedbackTimer?.invalidate()
        grid.statusMessage = nil
        let previousPage = grid.page
        refreshGrid()
        grid.page = min(previousPage, grid.numberOfPages - 1)
    }

    @objc private func systemLocaleDidChange(_ notification: Notification) {
        guard store.data.preferences.language == LauncherLanguage.system.rawValue else { return }
        applyLanguage()
        scheduleSettingsPanelRefresh()
    }

    private func updateStatusItemVisibility() {
        if store.data.preferences.showMenuBarIcon {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let image = LauncherIcon.original()?.copy() as? NSImage {
                image.size = NSSize(width: 18, height: 18)
                item.button?.image = image
            } else { item.button?.title = "▦" }
            item.button?.toolTip = L("启动台")
            item.button?.target = self
            item.button?.action = #selector(toggleLauncher(_:))
            statusItem = item
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func updatePageIndicator() {
        guard let pageIndicator else { return }
        pageIndicator.pageCount = grid.numberOfPages
        pageIndicator.page = grid.page
        pageIndicator.dotY = grid.indicatorBaselineY
    }

    func controlTextDidChange(_ obj: Notification) { refreshGrid() }

    @objc private func changeLayout(_ sender: Any?) {
        guard let raw = (sender as? NSPopUpButton)?.selectedItem?.representedObject as? String else { return }
        let layout: GridLayout
        if raw == "custom" {
            layout = .custom(rows: grid.layout.rows, columns: grid.layout.columns)
        } else {
            guard let preset = GridLayout(rawValue: raw) else { return }
            layout = preset
        }
        applyLayout(layout)
    }

    private func applyLayout(_ layout: GridLayout) {
        grid.layout = layout
        store.updatePreferences { $0.gridLayout = layout.rawValue }
        updatePageIndicator()
        scheduleSettingsPanelRefresh()
    }

    @objc private func applyCustomLayout(_ sender: Any?) {
        guard let rowsField = customRowsField, let columnsField = customColumnsField else { return }
        let rows = Int(rowsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        let columns = Int(columnsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let rows, let columns, GridLayout.allowedRows.contains(rows),
              GridLayout.allowedColumns.contains(columns) else {
            let alert = NSAlert()
            alert.messageText = L("网格数值无效")
            alert.informativeText = L("行数需为 2–12，列数需为 3–16。")
            if let settingsPanel { alert.beginSheetModal(for: settingsPanel) }
            return
        }
        applyLayout(.custom(rows: rows, columns: columns))
    }

    private func refreshGrid() {
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        grid.tiles = model.tiles(in: activeFolderID, query: query)
        grid.folderMode = activeFolderID != nil
        grid.folderName = activeFolderID.map { model.folderTitle(for: $0) } ?? ""
        updatePageIndicator()
        search.isHidden = activeFolderID != nil
        settingsButton.isHidden = activeFolderID != nil
        refreshButton.isHidden = activeFolderID != nil || !store.data.preferences.showQuickRefreshButton
    }

    private func preferredScreen() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(point) })
            ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func updateScreenGeometry(for screen: NSScreen) {
        if window.frame != screen.frame {
            window.setFrame(screen.frame, display: window.isVisible)
        }
        grid.dockBottomInset = max(0, screen.visibleFrame.minY - screen.frame.minY)
        let imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
        if imageURL != wallpaperURL {
            wallpaperURL = imageURL
            wallpaperView.image = imageURL.flatMap { NSImage(contentsOf: $0) }
        }
        updatePageIndicator()
    }

    private func show() {
        closeSettingsPanel()
        grid.resetPointerGestures()
        if let screen = preferredScreen() { updateScreenGeometry(for: screen) }
        search.stringValue = ""
        activeFolderID = nil
        refreshGrid()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(search)
    }

    private func launch(_ app: AppEntry) {
        window.orderOut(nil)
        NSWorkspace.shared.openApplication(at: app.url,
            configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { NSLog("Could not open %@: %@", app.name, error.localizedDescription) }
            }
    }

    private func select(_ tile: DisplayTile) {
        if tile.ref.kind == "folder" {
            activeFolderID = tile.ref.id
            search.stringValue = ""
            refreshGrid()
        } else if let app = model.apps[tile.ref.id] { launch(app) }
    }

    private func drop(_ source: DisplayTile, _ target: DisplayTile?, _ makeFolder: Bool) {
        guard search.stringValue.isEmpty, !store.data.preferences.lockLayout else { return }
        if let activeFolderID, target == nil {
            model.moveOutOfFolder(source.ref.id, folderID: activeFolderID)
        } else {
            model.move(source.ref, onto: target?.ref, in: activeFolderID, createFolder: makeFolder)
        }
        refreshGrid()
    }

    @objc private func closeFolder(_ sender: Any?) {
        activeFolderID = nil
        search.stringValue = ""
        refreshGrid()
    }

    @objc private func toggleLauncher(_ sender: Any?) {
        if window.isVisible { closeSettingsPanel(); window.orderOut(nil) }
        else { show() }
    }

    @objc private func showSettings(_ sender: Any?) {
        if let settingsPanel, settingsPanel.isVisible {
            settingsPanel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 610),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = L("启动台设置")
        panel.appearance = NSAppearance(named: .aqua)
        panel.backgroundColor = .white
        panel.isOpaque = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: window.level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameOrigin(NSPoint(x: window.frame.midX - 340, y: window.frame.midY - 305))
        panel.delegate = self
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 680, height: 610))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .white
        panel.contentView?.addSubview(scroll)
        settingsPanel = panel
        settingsScrollView = scroll
        refreshSettingsPanel()
        window.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
    }

    private func refreshSettingsPanel() {
        guard let scroll = settingsScrollView else { return }
        let previousOffset = scroll.contentView.bounds.minY
        let canvas = SettingsCanvas(frame: NSRect(x: 0, y: 0, width: 660, height: 820))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor.white.cgColor
        var y: CGFloat = 22
        let ink = NSColor(calibratedWhite: 0.12, alpha: 1)

        func label(_ title: String, x: CGFloat, width: CGFloat, size: CGFloat, bold: Bool = false) {
            let field = NSTextField(labelWithString: title)
            field.frame = NSRect(x: x, y: y, width: width, height: size + 9)
            field.font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
            field.textColor = ink
            canvas.addSubview(field)
        }
        func section(_ title: String) {
            y += 12
            label(title, x: 24, width: 620, size: 15, bold: true)
            y += 32
        }
        func row(_ title: String, control: NSView) {
            label(title, x: 26, width: 300, size: 13)
            control.frame = NSRect(x: 340, y: y - 3, width: 306, height: 30)
            canvas.addSubview(control)
            y += 45
        }
        func button(_ title: String, action: Selector) -> NSButton {
            NSButton(title: title, target: self, action: action)
        }
        func check(_ title: String, state: Bool, action: Selector) -> NSButton {
            let control = NSButton(checkboxWithTitle: title, target: self, action: action)
            control.state = state ? .on : .off
            return control
        }

        label(L("设置"), x: 24, width: 620, size: 24, bold: true)
        y += 35
        label(L("调整启动台的外观、应用与启动方式"), x: 24, width: 620, size: 12)
        y += 32

        section(L("外观"))
        let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for language in LauncherLanguage.allCases {
            languagePopup.addItem(withTitle: language.title)
            languagePopup.lastItem?.representedObject = language.rawValue
        }
        languagePopup.selectItem(withTitle:
            (LauncherLanguage(rawValue: store.data.preferences.language) ?? .system).title)
        languagePopup.target = self
        languagePopup.action = #selector(changeLanguage(_:))
        row(L("语言"), control: languagePopup)

        let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for theme in LauncherTheme.allCases {
            themePopup.addItem(withTitle: theme.title)
            themePopup.lastItem?.representedObject = theme.rawValue
        }
        let selectedTheme = LauncherTheme(rawValue: store.data.preferences.theme) ?? .system
        themePopup.selectItem(withTitle: selectedTheme.title)
        themePopup.target = self
        themePopup.action = #selector(changeTheme(_:))
        row(L("主题"), control: themePopup)

        let layoutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for layout in GridLayout.presets {
            layoutPopup.addItem(withTitle: layout.rawValue)
            layoutPopup.lastItem?.representedObject = layout.rawValue
        }
        layoutPopup.addItem(withTitle: L("自定义"))
        layoutPopup.lastItem?.representedObject = "custom"
        if case .custom = grid.layout { layoutPopup.selectItem(withTitle: L("自定义")) }
        else { layoutPopup.selectItem(withTitle: grid.layout.rawValue) }
        layoutPopup.target = self
        layoutPopup.action = #selector(changeLayout(_:))
        row(L("网格布局"), control: layoutPopup)

        customRowsField = nil
        customColumnsField = nil
        if case .custom = grid.layout {
            let inputs = NSView(frame: .zero)
            let rowsLabel = NSTextField(labelWithString: L("行"))
            rowsLabel.frame = NSRect(x: 0, y: 5, width: 25, height: 20)
            inputs.addSubview(rowsLabel)
            let rowsField = NSTextField(frame: NSRect(x: 30, y: 0, width: 60, height: 27))
            rowsField.stringValue = String(grid.layout.rows)
            inputs.addSubview(rowsField)
            let columnsLabel = NSTextField(labelWithString: L("列"))
            columnsLabel.frame = NSRect(x: 100, y: 5, width: 25, height: 20)
            inputs.addSubview(columnsLabel)
            let columnsField = NSTextField(frame: NSRect(x: 130, y: 0, width: 60, height: 27))
            columnsField.stringValue = String(grid.layout.columns)
            inputs.addSubview(columnsField)
            let applyButton = button(L("应用布局"), action: #selector(applyCustomLayout(_:)))
            applyButton.frame = NSRect(x: 200, y: 0, width: 106, height: 27)
            inputs.addSubview(applyButton)
            customRowsField = rowsField
            customColumnsField = columnsField
            row(L("自定义网格（行 2–12，列 3–16）"), control: inputs)
        }

        section(L("启动与行为"))
        let loginRegistered = LoginStartup.shared.isEnabled
        if store.data.preferences.launchAtLogin != loginRegistered {
            store.updatePreferences { $0.launchAtLogin = loginRegistered }
        }
        row(L("开机自启动"), control: check(LoginStartup.shared.needsApproval ? L("需要系统允许") : L("登录时静默运行"),
                                        state: loginRegistered, action: #selector(toggleLaunchAtLogin(_:))))
        row(L("菜单栏图标"), control: check(L("显示菜单栏图标"), state: store.data.preferences.showMenuBarIcon,
                                     action: #selector(toggleMenuBarIcon(_:))))
        row(L("图标排序"), control: check(L("锁定布局"), state: store.data.preferences.lockLayout,
                                    action: #selector(toggleLayoutLock(_:))))
        row(L("搜索栏"), control: check(L("显示快速刷新按钮"), state: store.data.preferences.showQuickRefreshButton,
                                  action: #selector(toggleQuickRefreshButton(_:))))
        row(L("应用来源"), control: check(L("包含 Dock 数据库中的系统应用"),
                                    state: AppCatalog.includeDockSystemApps,
                                    action: #selector(toggleDockSystemApps(_:))))

        section(L("应用"))
        row(L("应用列表"), control: button(L("重新扫描应用"), action: #selector(rescan(_:))))
        let hiddenPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        hiddenPopup.addItem(withTitle: L("选择要恢复的应用"))
        hiddenMenuIDs = model.state.hidden.sorted { model.title(for: $0) < model.title(for: $1) }
        for id in hiddenMenuIDs {
            hiddenPopup.addItem(withTitle: model.title(for: id))
            hiddenPopup.lastItem?.representedObject = id
        }
        hiddenPopup.isEnabled = !hiddenMenuIDs.isEmpty
        hiddenPopup.target = self
        hiddenPopup.action = #selector(restoreHidden(_:))
        row(L("恢复隐藏的应用"), control: hiddenPopup)

        section(L("快捷操作"))
        row(L("全局快捷键"), control: button("\(currentShortcut.localizedLabel)…", action: #selector(configureShortcut(_:))))
        let cornerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for (value, title) in [("off", L("关闭")), ("topLeft", L("左上角")), ("topRight", L("右上角")),
                               ("bottomLeft", L("左下角")), ("bottomRight", L("右下角"))] {
            cornerPopup.addItem(withTitle: title)
            cornerPopup.lastItem?.representedObject = value
            if store.data.preferences.hotCorner == value { cornerPopup.selectItem(at: cornerPopup.numberOfItems - 1) }
        }
        cornerPopup.target = self
        cornerPopup.action = #selector(selectCorner(_:))
        row(L("触发角"), control: cornerPopup)

        section(L("系统"))
        row(L("登录项"), control: button(L("打开系统登录项设置…"), action: #selector(openLoginItemsSettings(_:))))
        row(L("应用数据"), control: button(L("打开数据文件夹"), action: #selector(openDataFolder(_:))))
        row(L("卸载"), control: button(L("完全卸载启动台…"), action: #selector(uninstallLauncher(_:))))
        y += 8
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        label(Localization.format("启动台 %@", version), x: 26, width: 300, size: 12)
        let done = button(L("完成"), action: #selector(closeSettingsAction(_:)))
        done.frame = NSRect(x: 568, y: y - 5, width: 78, height: 30)
        canvas.addSubview(done)
        y += 44

        canvas.frame.size.height = max(y, scroll.contentSize.height)
        scroll.documentView = canvas
        scroll.contentView.scroll(to: NSPoint(x: 0, y: min(previousOffset,
            max(0, canvas.frame.height - scroll.contentSize.height))))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private func scheduleSettingsPanelRefresh() {
        DispatchQueue.main.async { [weak self] in self?.refreshSettingsPanel() }
    }

    private func closeSettingsPanel() { settingsPanel?.close() }

    @objc private func closeSettingsAction(_ sender: Any?) { closeSettingsPanel() }

    @objc private func changeTheme(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              LauncherTheme(rawValue: raw) != nil else { return }
        store.updatePreferences { $0.theme = raw }
        applyTheme()
        scheduleSettingsPanelRefresh()
    }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              LauncherLanguage(rawValue: raw) != nil else { return }
        store.updatePreferences { $0.language = raw }
        applyLanguage()
        scheduleSettingsPanelRefresh()
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        if LoginStartup.shared.needsApproval {
            closeSettingsPanel()
            window.orderOut(nil)
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if LoginStartup.shared.isEnabled {
                try LoginStartup.shared.disable()
                store.updatePreferences { $0.launchAtLogin = false }
            } else {
                try LoginStartup.shared.enable(appURL: Bundle.main.bundleURL)
                store.updatePreferences { $0.launchAtLogin = true }
            }
        } catch {
            showSettingAlert(L("无法更改开机自启动"), error.localizedDescription)
        }
        scheduleSettingsPanelRefresh()
    }

    @objc private func openLoginItemsSettings(_ sender: Any?) {
        closeSettingsPanel()
        window.orderOut(nil)
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func toggleLayoutLock(_ sender: Any?) {
        let locked = !store.data.preferences.lockLayout
        store.updatePreferences { $0.lockLayout = locked }
        grid.layoutLocked = locked
        scheduleSettingsPanelRefresh()
    }

    @objc private func toggleMenuBarIcon(_ sender: NSButton) {
        store.updatePreferences { $0.showMenuBarIcon = sender.state == .on }
        updateStatusItemVisibility()
        scheduleSettingsPanelRefresh()
    }

    @objc private func toggleQuickRefreshButton(_ sender: Any?) {
        let visible = !store.data.preferences.showQuickRefreshButton
        store.updatePreferences { $0.showQuickRefreshButton = visible }
        refreshGrid()
        scheduleSettingsPanelRefresh()
    }

    @objc private func openDataFolder(_ sender: Any?) {
        closeSettingsPanel()
        window.orderOut(nil)
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    @objc private func uninstallLauncher(_ sender: Any?) {
        let appURL = Bundle.main.bundleURL.standardizedFileURL
        guard appURL.pathExtension.lowercased() == "app",
              appURL.deletingLastPathComponent().path == "/Applications" else {
            showSettingAlert(L("无法卸载"), L("请先将“启动台.app”安装到“应用程序”，再从设置中运行完整卸载。"))
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("完全卸载启动台？")
        alert.informativeText = L("将“启动台.app”移到废纸篓，并删除图标排序、文件夹、应用别名、隐藏状态和其他设置；同时移除开机自启动。此操作无法撤销。")
        alert.addButton(withTitle: L("卸载并删除数据"))
        alert.addButton(withTitle: L("取消"))
        alert.window.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try LoginStartup.shared.disable()
        } catch {
            showSettingAlert(L("无法移除登录项"), error.localizedDescription)
            return
        }

        NSWorkspace.shared.recycle([appURL]) { [weak self] moved, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.showSettingAlert(L("无法移到废纸篓"), error.localizedDescription)
                    return
                }
                guard moved[appURL] != nil else {
                    self.showSettingAlert(L("无法移到废纸篓"), L("访达没有确认移动“启动台.app”，应用数据尚未删除。"))
                    return
                }
                do {
                    try LauncherCleanup().removeLocalData()
                    self.closeSettingsPanel()
                    self.window.orderOut(nil)
                    NSApp.terminate(nil)
                } catch {
                    self.showSettingAlert(L("应用已移到废纸篓，但未清理完数据"), error.localizedDescription)
                }
            }
        }
    }

    private func showSettingAlert(_ title: String, _ details: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details
        alert.window.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
        alert.runModal()
    }

    @objc private func restoreHidden(_ sender: Any?) {
        guard let id = (sender as? NSPopUpButton)?.selectedItem?.representedObject as? String else { return }
        model.unhide(id); refreshGrid()
        scheduleSettingsPanelRefresh()
    }

    @objc private func toggleDockSystemApps(_ sender: Any?) {
        let enabled = !AppCatalog.includeDockSystemApps
        store.updatePreferences { $0.includeDockSystemApps = enabled }
        rescan(nil)
        scheduleSettingsPanelRefresh()
    }

    @objc private func rescan(_ sender: Any?) {
        scanFeedbackTimer?.invalidate()
        activeFolderID = nil
        search.stringValue = ""
        model.clearLoadedCatalog()
        grid.tiles = []
        grid.statusMessage = L("正在清理缓存并重新扫描应用…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.model.reloadCatalog()
            self.refreshGrid()
            let database = AppCatalog.lastDockDatabaseOpened
                ? Localization.format("数据库 %d 条", AppCatalog.lastDockAppCount)
                : L("数据库不可用")
            self.grid.statusMessage = Localization.format("已加载 %d 个 · /Applications %d 项 · %@",
                                                          self.model.apps.count, AppCatalog.lastApplicationsCount, database)
            self.scanFeedbackTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
                self?.grid.statusMessage = nil
            }
        }
    }

    @objc private func configureShortcut(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = L("设置全局快捷键")
        alert.informativeText = L("点击下方区域，再按下包含 Control、Option 或 Command 的组合键。")
        alert.addButton(withTitle: L("保存"))
        alert.addButton(withTitle: L("取消"))
        let recorder = ShortcutRecorder(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        recorder.shortcut = currentShortcut
        alert.accessoryView = recorder
        alert.window.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
        guard alert.runModal() == .alertFirstButtonReturn, let shortcut = recorder.shortcut else { return }
        let previous = currentShortcut
        guard hotkeyManager.register(shortcut) else {
            hotkeyManager.register(previous)
            let error = NSAlert()
            error.messageText = L("无法使用这个快捷键")
            error.informativeText = L("可能已被系统或其他应用占用，请换一个组合键。")
            error.window.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
            error.runModal()
            return
        }
        currentShortcut = shortcut
        store.updatePreferences {
            $0.hotkeyCode = Int(shortcut.keyCode)
            $0.hotkeyModifiers = Int(shortcut.modifiers)
            $0.hotkeyLabel = shortcut.label
        }
        scheduleSettingsPanelRefresh()
    }

    @objc private func selectCorner(_ sender: Any?) {
        guard let value = (sender as? NSPopUpButton)?.selectedItem?.representedObject as? String else { return }
        store.updatePreferences { $0.hotCorner = value }
        cornerEnteredAt = nil
        cornerArmed = true
        scheduleSettingsPanelRefresh()
    }

    @objc private func checkHotCorner(_ timer: Timer) {
        let selection = store.data.preferences.hotCorner
        guard selection != "off", let screen = NSScreen.main else { return }
        let frame = screen.frame
        let point = NSEvent.mouseLocation
        let atCorner: Bool
        switch selection {
        case "topLeft": atCorner = point.x <= frame.minX + 6 && point.y >= frame.maxY - 6
        case "topRight": atCorner = point.x >= frame.maxX - 6 && point.y >= frame.maxY - 6
        case "bottomLeft": atCorner = point.x <= frame.minX + 6 && point.y <= frame.minY + 6
        case "bottomRight": atCorner = point.x >= frame.maxX - 6 && point.y <= frame.minY + 6
        default: atCorner = false
        }
        if !atCorner { cornerEnteredAt = nil; cornerArmed = true; return }
        if cornerEnteredAt == nil { cornerEnteredAt = Date() }
        if cornerArmed && !window.isVisible && Date().timeIntervalSince(cornerEnteredAt!) >= 0.5 {
            cornerArmed = false
            show()
        }
    }

    private func showContextMenu(_ tile: DisplayTile, event: NSEvent) {
        contextRef = tile.ref
        let menu = NSMenu()
        if tile.ref.kind == "app" {
            menu.addItem(withTitle: L("打开"), action: #selector(contextOpen(_:)), keyEquivalent: "").target = self
            menu.addItem(withTitle: L("重命名"), action: #selector(contextRename(_:)), keyEquivalent: "").target = self
            menu.addItem(withTitle: L("隐藏应用"), action: #selector(contextHide(_:)), keyEquivalent: "").target = self
            if activeFolderID != nil {
                menu.addItem(withTitle: L("移出文件夹"), action: #selector(contextMoveOut(_:)), keyEquivalent: "").target = self
            }
            menu.addItem(.separator())
            menu.addItem(withTitle: L("在访达中显示"), action: #selector(contextReveal(_:)), keyEquivalent: "").target = self
            menu.addItem(withTitle: L("显示包内容"), action: #selector(contextShowContents(_:)), keyEquivalent: "").target = self
            if let app = model.apps[tile.ref.id], canTrash(app.url) {
                menu.addItem(withTitle: L("移到废纸篓…"), action: #selector(contextTrash(_:)), keyEquivalent: "").target = self
            }
        } else {
            menu.addItem(withTitle: L("打开文件夹"), action: #selector(contextOpen(_:)), keyEquivalent: "").target = self
            menu.addItem(withTitle: L("重命名文件夹"), action: #selector(contextRename(_:)), keyEquivalent: "").target = self
            menu.addItem(withTitle: L("解散文件夹"), action: #selector(contextUngroup(_:)), keyEquivalent: "").target = self
        }
        NSMenu.popUpContextMenu(menu, with: event, for: grid)
    }

    private func canTrash(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let userApps = NSHomeDirectory() + "/Applications/"
        return (path.hasPrefix("/Applications/") || path.hasPrefix(userApps)) &&
            FileManager.default.isWritableFile(atPath: path)
    }

    @objc private func contextOpen(_ sender: Any?) {
        guard let ref = contextRef else { return }
        if ref.kind == "folder" { activeFolderID = ref.id; refreshGrid() }
        else if let app = model.apps[ref.id] { launch(app) }
    }

    @objc private func contextRename(_ sender: Any?) {
        guard let ref = contextRef else { return }
        let oldName = ref.kind == "folder" ? model.folderTitle(for: ref.id) : model.title(for: ref.id)
        let panel = RenamePanel(title: ref.kind == "folder" ? L("重命名文件夹") : L("重命名应用"),
                                currentName: oldName, parentLevel: window.level)
        window.makeKeyAndOrderFront(nil)
        window.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.nameField)
        let response = NSApp.runModal(for: panel)
        window.removeChildWindow(panel)
        panel.orderOut(nil)
        guard response == .alertFirstButtonReturn else { return }
        if ref.kind == "folder" { model.renameFolder(ref.id, to: panel.nameField.stringValue) }
        else { model.renameApp(ref.id, to: panel.nameField.stringValue) }
        refreshGrid()
    }

    @objc private func contextHide(_ sender: Any?) {
        guard let ref = contextRef, ref.kind == "app" else { return }
        model.hide(ref.id); refreshGrid()
    }

    @objc private func contextMoveOut(_ sender: Any?) {
        guard let ref = contextRef, let folderID = activeFolderID else { return }
        model.moveOutOfFolder(ref.id, folderID: folderID); refreshGrid()
    }

    @objc private func contextReveal(_ sender: Any?) {
        guard let ref = contextRef, let app = model.apps[ref.id] else { return }
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
    }

    @objc private func contextShowContents(_ sender: Any?) {
        guard let ref = contextRef, let app = model.apps[ref.id] else { return }
        NSWorkspace.shared.open(app.url.appendingPathComponent("Contents", isDirectory: true))
    }

    @objc private func contextUngroup(_ sender: Any?) {
        guard let ref = contextRef, ref.kind == "folder" else { return }
        model.ungroup(ref.id); refreshGrid()
    }

    @objc private func contextTrash(_ sender: Any?) {
        guard let ref = contextRef, let app = model.apps[ref.id], canTrash(app.url) else { return }
        let alert = NSAlert()
        alert.messageText = Localization.format("将 %@ 移到废纸篓？", model.title(for: ref.id))
        alert.informativeText = L("这会移动应用文件，可从废纸篓恢复。")
        alert.addButton(withTitle: L("移到废纸篓"))
        alert.addButton(withTitle: L("取消"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NSWorkspace.shared.recycle([app.url]) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error { NSApp.presentError(error) }
                self?.model.reloadCatalog()
                self?.refreshGrid()
            }
        }
    }
}

@main struct Main {
    static func main() {
        if CommandLine.arguments.contains("--self-test-gestures") {
            var mouse = MousePageDragState()
            mouse.begin(at: .zero, source: nil, time: 0)
            guard mouse.direction(at: NSPoint(x: -90, y: 2), time: 0.1, layoutLocked: false) == 1,
                  mouse.direction(at: NSPoint(x: -200, y: 2), time: 0.2, layoutLocked: false) == nil else {
                fatalError("Mouse drag must turn one page per press")
            }
            mouse.begin(at: .zero, source: 0, time: 0)
            guard mouse.direction(at: NSPoint(x: 80, y: 0), time: 0.5, layoutLocked: false) == nil,
                  mouse.intent == .rearrange else { fatalError("Held icon must remain rearrangeable") }
            mouse.begin(at: .zero, source: 0, time: 0)
            guard mouse.direction(at: NSPoint(x: -80, y: 0), time: 0.1, layoutLocked: true) == 1 else {
                fatalError("Layout lock must allow page dragging")
            }
            var touch = ThreeFingerSwipeState()
            let origin: [AnyHashable: NSPoint] = [1: NSPoint(x: 0.4, y: 0.5),
                                                 2: NSPoint(x: 0.5, y: 0.5), 3: NSPoint(x: 0.6, y: 0.5)]
            let left = origin.mapValues { NSPoint(x: $0.x - 0.1, y: $0.y) }
            guard touch.direction(touches: origin) == nil, touch.direction(touches: left) == 1,
                  touch.direction(touches: left) == nil else { fatalError("Three-finger swipe repeated") }
            _ = touch.direction(touches: [:])
            let two = origin.filter { $0.key != AnyHashable(3) }
            guard touch.direction(touches: two) == nil else { fatalError("Two fingers recognized as three") }
            _ = touch.direction(touches: [:])
            _ = touch.direction(touches: origin)
            guard touch.direction(touches: origin.mapValues { NSPoint(x: $0.x, y: $0.y + 0.2) }) == nil,
                  ThreeFingerSwipeState.nativeDirection(deltaX: 1, deltaY: 0) == 1,
                  ThreeFingerSwipeState.nativeDirection(deltaX: -1, deltaY: 0) == -1 else {
                fatalError("Trackpad swipe direction or axis is incorrect")
            }
            touch.reset()
            _ = touch.direction(touches: origin)
            _ = touch.direction(touches: two)
            guard touch.direction(touches: left) == nil else { fatalError("Lifted finger caused a page jump") }
            touch.reset()
            _ = touch.direction(touches: origin)
            var replacement = left
            replacement[4] = replacement.removeValue(forKey: 3)
            guard touch.direction(touches: replacement) == nil else { fatalError("Changed touch identities caused a page jump") }
            let grid = GridView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
            grid.tiles = (0..<90).map { DisplayTile(ref: TileRef(kind: "app", id: "test.\($0)"),
                                                   title: "Test", icons: []) }
            var dismissed = 0, selected = 0, dropped = 0
            grid.onDismiss = { dismissed += 1 }
            grid.onSelect = { _ in selected += 1 }
            grid.onDrop = { _, _, _ in dropped += 1 }
            func event(_ type: NSEvent.EventType, _ point: NSPoint, _ time: TimeInterval) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: time,
                                   windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            let blank = NSPoint(x: 1600, y: 70)
            grid.mouseDown(with: event(.leftMouseDown, blank, 0))
            guard dismissed == 0 else { fatalError("Mouse down dismissed before dragging") }
            grid.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 1400, y: 70), 0.1))
            grid.mouseUp(with: event(.leftMouseUp, NSPoint(x: 1400, y: 70), 0.2))
            guard grid.page == 1, dismissed == 0, selected == 0, dropped == 0 else {
                fatalError("Background drag triggered a click or drop")
            }
            grid.mouseDown(with: event(.leftMouseDown, blank, 1))
            grid.mouseUp(with: event(.leftMouseUp, blank, 1.1))
            guard dismissed == 1 else { fatalError("Background click must still dismiss") }
            grid.goToPage(0)
            let icon = NSPoint(x: 184, y: 891)
            grid.mouseDown(with: event(.leftMouseDown, icon, 2))
            grid.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 84, y: 891), 2.1))
            grid.mouseUp(with: event(.leftMouseUp, NSPoint(x: 84, y: 891), 2.2))
            guard grid.page == 1, selected == 0, dropped == 0 else { fatalError("Icon swipe must page") }
            grid.goToPage(0)
            grid.mouseDown(with: event(.leftMouseDown, icon, 3))
            grid.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 440, y: 891), 3.5))
            grid.mouseUp(with: event(.leftMouseUp, NSPoint(x: 440, y: 891), 3.6))
            guard grid.page == 0, dropped == 1 else { fatalError("Icon hold-and-drag must rearrange") }
            print("Page gesture self-test passed")
            return
        }
        if CommandLine.arguments.contains("--self-test-language") {
            guard Localization.resolvedLanguage(selection: "system", preferredLanguages: ["zh-CN"]) == "zh-Hans",
                  Localization.resolvedLanguage(selection: "system", preferredLanguages: ["zh-Hant-TW"]) == "zh-Hant",
                  Localization.resolvedLanguage(selection: "system", preferredLanguages: ["zh-HK"]) == "zh-Hant",
                  Localization.resolvedLanguage(selection: "system", preferredLanguages: ["en-US"]) == "en",
                  Localization.resolvedLanguage(selection: "en", preferredLanguages: ["zh-CN"]) == "en",
                  Localization.text("设置", in: "en") == "Settings",
                  Localization.text("设置", in: "zh-Hant") == "設定",
                  Localization.text("设置", in: "zh-Hans") == "设置" else {
                fatalError("Language selection or translation lookup failed")
            }
            print("Language self-test passed")
            return
        }
        if CommandLine.arguments.contains("--self-test-indicator") {
            let indicator = PageIndicatorView(frame: NSRect(x: 0, y: 0, width: 1920, height: 900))
            indicator.pageCount = 3
            indicator.dotY = 100
            let middle = NSPoint(x: 960, y: 103)
            guard indicator.pageIndex(at: middle) == 1,
                  indicator.pageIndex(at: NSPoint(x: 960, y: 190)) == nil else {
                fatalError("Page indicator hit area is incorrect")
            }
            indicator.page = 2
            guard indicator.dotY == 100,
                  indicator.pageIndex(at: middle) == 1 else {
                fatalError("Page indicator moved with the selected page")
            }
            print("Page indicator self-test passed")
            return
        }
        if CommandLine.arguments.contains("--self-test-scroll") {
            var smooth = PageScrollState()
            func smoothStep(_ delta: CGFloat, _ phase: NSEvent.Phase = [],
                            _ momentum: NSEvent.Phase = [], _ time: TimeInterval) -> Int? {
                smooth.direction(delta: delta, precise: true, phase: phase,
                                 momentum: momentum, at: time)
            }
            guard smoothStep(-12, .began, [], 0) == nil,
                  smoothStep(-18, .changed, [], 0.02) == 1,
                  smoothStep(-35, .changed, [], 0.04) == nil,
                  smoothStep(-40, [], .began, 0.06) == nil,
                  smoothStep(-30, .began, [], 0.5) == 1 else {
                fatalError("Smooth scrolling must change one page per gesture")
            }
            var wheel = PageScrollState()
            guard wheel.direction(delta: -5, precise: false, phase: [], momentum: [], at: 0) == 1,
                  wheel.direction(delta: -5, precise: false, phase: [], momentum: [], at: 0.1) == nil,
                  wheel.direction(delta: -5, precise: false, phase: [], momentum: [], at: 0.31) == 1 else {
                fatalError("Mouse wheel page change debounce failed")
            }
            print("Scroll self-test passed")
            return
        }
        if CommandLine.arguments.contains("--check-safari") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("classic-launchpad-safari-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = LauncherStore(fileURL: directory.appendingPathComponent("Data.store"), legacyDefaults: nil)
            let model = LauncherModel(store: store)
            guard let safari = model.apps["com.apple.Safari"],
                  model.tiles(query: "Safari").contains(where: { $0.ref.id == safari.id }) else {
                fatalError("Safari missing from catalog or search")
            }
            print("Safari search passed: \(safari.url.path)")
            return
        }
        if CommandLine.arguments.contains("--check-catalog") {
            let entries = AppCatalog.load()
            print("Found \(entries.count) applications")
            print(AppCatalog.lastDockDatabaseOpened
                ? "Dock database: \(AppCatalog.lastDockAppCount) valid records"
                : "Dock database unavailable")
            for app in entries.prefix(5) { print("\(app.name): \(app.url.path)") }
            exit(entries.isEmpty ? 1 : 0)
        }
        if CommandLine.arguments.contains("--self-test-grid-layout") {
            guard GridLayout.presets.map(\.rawValue) == ["5×7", "6×8", "7×8", "7×9"],
                  GridLayout(rawValue: "7×7") == .custom(rows: 7, columns: 7),
                  GridLayout(rawValue: "custom:12×16") == .custom(rows: 12, columns: 16),
                  GridLayout(rawValue: "custom:13×16") == nil,
                  GridLayout(rawValue: "custom:0×0") == nil else {
                fatalError("Grid layout presets or legacy parsing failed")
            }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("classic-launchpad-grid-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory) }
            let file = directory.appendingPathComponent("Data.store")
            let store = LauncherStore(fileURL: file, legacyDefaults: nil)
            store.updatePreferences { $0.gridLayout = GridLayout.custom(rows: 9, columns: 11).rawValue }
            let reloaded = LauncherStore(fileURL: file, legacyDefaults: nil)
            guard GridLayout(rawValue: reloaded.data.preferences.gridLayout ?? "") ==
                  .custom(rows: 9, columns: 11) else { fatalError("Custom grid did not persist") }
            let grid = GridView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
            grid.tiles = (0..<120).map { DisplayTile(ref: TileRef(kind: "app", id: "test.\($0)"),
                                                   title: "Test", icons: []) }
            grid.layout = .sevenByNine
            guard grid.numberOfPages == 2 else { fatalError("7×9 pagination failed") }
            grid.layout = .custom(rows: 2, columns: 3)
            guard grid.numberOfPages == 20 else { fatalError("Custom pagination failed") }
            print("Grid layout self-test passed")
            return
        }
        if CommandLine.arguments.contains("--self-test-model") {
            let suiteName = "local.codex.classiclaunchpad.selftest.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set("7×7", forKey: "gridLayout")
            defaults.set("topLeft", forKey: "hotCorner")
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("classic-launchpad-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory) }
            let storeURL = directory.appendingPathComponent("Data.store")
            let store = LauncherStore(fileURL: storeURL, legacyDefaults: defaults)
            guard store.data.preferences.gridLayout == "7×7",
                  store.data.preferences.hotCorner == "topLeft",
                  store.data.preferences.theme == "system",
                  store.data.preferences.language == "system",
                  store.data.preferences.showMenuBarIcon,
                  FileManager.default.fileExists(atPath: storeURL.path),
                  (try? FileManager.default.attributesOfItem(atPath: storeURL.path)[.posixPermissions] as? Int) == 0o600 else {
                fatalError("Legacy preferences migration failed")
            }
            store.updatePreferences {
                $0.gridLayout = "5×7"
                $0.hotkeyCode = 37
                $0.hotkeyModifiers = 2304
                $0.launchAtLogin = true
                $0.showMenuBarIcon = false
                $0.lockLayout = true
                $0.showQuickRefreshButton = true
                $0.theme = "dark"
                $0.language = "en"
            }
            let model = LauncherModel(store: store)
            let utilityIDs = Set(model.apps.values.filter {
                $0.url.path.hasPrefix("/Applications/Utilities/") ||
                $0.url.path.hasPrefix("/System/Applications/Utilities/")
            }.map(\.id))
            guard let other = model.state.folders.first(where: { $0.value.name == "其他" }),
                  utilityIDs.count >= 2, Set(other.value.apps) == utilityIDs,
                  !model.state.tiles.contains(where: { $0.kind == "app" && utilityIDs.contains($0.id) }) else {
                fatalError("Utilities folder grouping failed")
            }
            if Locale.preferredLanguages.first?.hasPrefix("zh") == true {
                let expected = [
                    "Activity Monitor.app": "活动监视器",
                    "Disk Utility.app": "磁盘工具",
                    "Terminal.app": "终端",
                    "Screenshot.app": "截屏"
                ]
                let folderTiles = model.tiles(in: other.key)
                for (filename, name) in expected {
                    guard folderTiles.contains(where: { tile in
                        tile.title == name && model.apps[tile.ref.id]?.url.lastPathComponent == filename
                    }), model.tiles(query: name).contains(where: { $0.title == name }) else {
                        fatalError("Localized utility name missing: \(filename)")
                    }
                }
            }
            let initial = model.state.tiles.filter { $0.kind == "app" }
            guard initial.count >= 3 else { fatalError("Not enough apps to test") }
            model.move(initial[0], onto: initial[1], in: nil, createFolder: true)
            guard let folder = model.state.tiles.first(where: {
                    $0.kind == "folder" && model.state.folders[$0.id]?.name == "新建文件夹"
                  }),
                  model.state.folders[folder.id]?.apps.count == 2 else { fatalError("Folder creation failed") }
            model.renameFolder(folder.id, to: "测试文件夹")
            model.hide(initial[2].id)
            guard model.tiles().allSatisfy({ $0.ref.id != initial[2].id }) else { fatalError("Hide failed") }
            let reloadedStore = LauncherStore(fileURL: storeURL, legacyDefaults: nil)
            guard reloadedStore.data.preferences.gridLayout == "5×7",
                  reloadedStore.data.preferences.hotkeyCode == 37,
                  reloadedStore.data.preferences.hotkeyModifiers == 2304,
                  reloadedStore.data.preferences.launchAtLogin,
                  !reloadedStore.data.preferences.showMenuBarIcon,
                  reloadedStore.data.preferences.lockLayout,
                  reloadedStore.data.preferences.showQuickRefreshButton,
                  reloadedStore.data.preferences.theme == "dark",
                  reloadedStore.data.preferences.language == "en" else {
                fatalError("Data.store preferences did not persist")
            }
            let reloaded = LauncherModel(store: reloadedStore)
            guard reloaded.state.folders[folder.id]?.name == "测试文件夹",
                  reloaded.state.hidden.contains(initial[2].id) else { fatalError("Persistence failed") }
            reloaded.unhide(initial[2].id)
            reloaded.moveOutOfFolder(initial[0].id, folderID: folder.id)
            guard reloaded.state.tiles.contains(initial[0]),
                  !reloaded.state.hidden.contains(initial[2].id) else { fatalError("Restore failed") }
            let count = reloaded.apps.count
            reloaded.clearLoadedCatalog()
            guard reloaded.apps.isEmpty else { fatalError("Catalog cache did not clear") }
            reloaded.reloadCatalog()
            guard reloaded.apps.count == count else { fatalError("Catalog reload failed") }
            let movedUtility = other.value.apps[0]
            reloaded.moveOutOfFolder(movedUtility, folderID: other.key)
            reloaded.reloadCatalog()
            guard reloaded.state.tiles.contains(TileRef(kind: "app", id: movedUtility)),
                  !(reloaded.state.folders[other.key]?.apps.contains(movedUtility) ?? false) else {
                fatalError("Manual Utilities move did not persist")
            }
            let migrationSuite = "local.codex.classiclaunchpad.migration-check.\(UUID().uuidString)"
            let migrationDefaults = UserDefaults(suiteName: migrationSuite)!
            defer { migrationDefaults.removePersistentDomain(forName: migrationSuite) }
            let utilities = Array(utilityIDs).sorted()
            var oldState = LauncherState()
            oldState.tiles = [TileRef(kind: "app", id: utilities[0]),
                              TileRef(kind: "app", id: initial[0].id),
                              TileRef(kind: "folder", id: "custom")]
            oldState.folders["custom"] = FolderRecord(name: "手动整理", apps: [utilities[1]])
            migrationDefaults.set(try! JSONEncoder().encode(oldState), forKey: "launcherStateV1")
            let migrationURL = directory.appendingPathComponent("migration/Data.store")
            let migrationStore = LauncherStore(fileURL: migrationURL, legacyDefaults: migrationDefaults)
            let migrated = LauncherModel(store: migrationStore)
            guard let migratedOther = migrated.state.folders.first(where: { $0.value.name == "其他" }),
                  migratedOther.value.apps.contains(utilities[0]),
                  migrated.state.folders["custom"]?.apps == [utilities[1]],
                  migrated.state.tiles.contains(TileRef(kind: "app", id: initial[0].id)) else {
                fatalError("Existing layout migration failed")
            }
            let fakeApplications = directory.appendingPathComponent("Applications", isDirectory: true)
            let fakeApp = fakeApplications.appendingPathComponent("启动台.app", isDirectory: true)
            let fakeExecutable = fakeApp.appendingPathComponent("Contents/MacOS/ClassicLaunchpad")
            try! FileManager.default.createDirectory(at: fakeExecutable.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try! Data("test".utf8).write(to: fakeExecutable)
            try! FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeExecutable.path)
            final class FakeRegistration: LoginItemRegistration {
                var status: SMAppService.Status = .notRegistered
                func register() throws { status = .enabled }
                func unregister() throws { status = .notRegistered }
            }
            let fakeRegistration = FakeRegistration()
            let legacyAgentURL = directory.appendingPathComponent("LaunchAgents/test.plist")
            try! FileManager.default.createDirectory(at: legacyAgentURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try! Data("old agent".utf8).write(to: legacyAgentURL)
            let login = LoginStartup(agentURL: legacyAgentURL,
                                     applicationsDirectory: fakeApplications,
                                     registration: fakeRegistration)
            try! login.migrateLegacyIfNeeded(appURL: fakeApp)
            guard login.isEnabled, fakeRegistration.status == .enabled,
                  !FileManager.default.fileExists(atPath: legacyAgentURL.path) else {
                fatalError("Login item migration failed")
            }
            try! login.disable()
            guard !login.isEnabled else { fatalError("Login startup removal failed") }
            let cleanupSuite = "local.codex.classiclaunchpad.cleanup-test.\(UUID().uuidString)"
            let cleanupDefaults = UserDefaults(suiteName: cleanupSuite)!
            defer { cleanupDefaults.removePersistentDomain(forName: cleanupSuite) }
            cleanupDefaults.set(true, forKey: "leftover")
            let libraryURL = directory.appendingPathComponent("Library", isDirectory: true)
            let cleanup = LauncherCleanup(libraryURL: libraryURL,
                                          bundleIdentifier: cleanupSuite, defaults: cleanupDefaults)
            for url in cleanup.dataLocations {
                try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                         withIntermediateDirectories: true)
                if url.pathExtension == "plist" {
                    try! Data("old settings".utf8).write(to: url)
                } else {
                    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                }
            }
            let unrelated = libraryURL.appendingPathComponent("Application Support/OtherApp/Data.store")
            try! FileManager.default.createDirectory(at: unrelated.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try! Data("keep".utf8).write(to: unrelated)
            try! cleanup.removeLocalData()
            guard cleanup.dataLocations.allSatisfy({ !FileManager.default.fileExists(atPath: $0.path) }),
                  FileManager.default.fileExists(atPath: unrelated.path),
                  cleanupDefaults.object(forKey: "leftover") == nil else {
                fatalError("Complete uninstall removed the wrong files or left application data")
            }
            print("Model self-test passed")
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        if let icon = LauncherIcon.original() {
            application.applicationIconImage = LauncherIcon.dockImage(from: icon)
            application.dockTile.display()
        }
        let controller = LauncherController()
        application.delegate = controller
        let menuBar = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("退出启动台"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        menuBar.addItem(appMenuItem)
        application.mainMenu = menuBar
        application.run()
    }
}
