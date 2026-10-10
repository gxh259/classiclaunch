import Foundation

enum DockIconCleanupError: LocalizedError {
    case preferencesCouldNotBeSaved
    case dockCouldNotRestart

    var errorDescription: String? {
        switch self {
        case .preferencesCouldNotBeSaved:
            L("无法保存 Dock 配置，请手动从 Dock 移除启动台图标。")
        case .dockCouldNotRestart:
            L("Dock 配置已更新，但无法刷新 Dock。请退出登录并重新登录。")
        }
    }
}

struct DockIconCleanup {
    private let defaults: UserDefaults
    private let restartDock: () throws -> Void

    init(defaults: UserDefaults = UserDefaults(suiteName: "com.apple.dock")!,
         restartDock: @escaping () throws -> Void = DockIconCleanup.reloadDock) {
        self.defaults = defaults
        self.restartDock = restartDock
    }

    @discardableResult
    func removeLauncher(at appURL: URL,
                        bundleIdentifier: String = LauncherCleanup.bundleIdentifier) throws -> Int {
        var removed = 0
        for key in ["persistent-apps", "recent-apps"] {
            guard let tiles = defaults.array(forKey: key) as? [[String: Any]] else { continue }
            let kept = tiles.filter { !Self.matchesLauncher($0, appURL: appURL,
                                                             bundleIdentifier: bundleIdentifier) }
            guard kept.count != tiles.count else { continue }
            defaults.set(kept, forKey: key)
            removed += tiles.count - kept.count
        }
        guard removed > 0 else { return 0 }
        guard defaults.synchronize() else { throw DockIconCleanupError.preferencesCouldNotBeSaved }
        do { try restartDock() }
        catch { throw DockIconCleanupError.dockCouldNotRestart }
        return removed
    }

    private static func matchesLauncher(_ tile: [String: Any], appURL: URL,
                                        bundleIdentifier: String) -> Bool {
        guard let data = tile["tile-data"] as? [String: Any] else { return false }
        if data["bundle-identifier"] as? String == bundleIdentifier { return true }
        guard let fileData = data["file-data"] as? [String: Any],
              let path = fileData["_CFURLString"] as? String else { return false }
        let tileURL = path.hasPrefix("file:") ? URL(string: path) : URL(fileURLWithPath: path)
        return tileURL?.standardizedFileURL.path == appURL.standardizedFileURL.path
    }

    private static func reloadDock() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw DockIconCleanupError.dockCouldNotRestart }
    }
}
