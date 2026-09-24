import Foundation

struct LauncherPreferences: Codable {
    var gridLayout: String?
    var includeDockSystemApps = false
    var hotkeyCode: Int?
    var hotkeyModifiers: Int?
    var hotkeyLabel: String?
    var hotCorner = "off"
    var launchAtLogin = false
    var lockLayout = false
    var showQuickRefreshButton = false
    var theme = "system"

    init() {}

    private enum CodingKeys: String, CodingKey {
        case gridLayout, includeDockSystemApps, hotkeyCode, hotkeyModifiers, hotkeyLabel, hotCorner
        case launchAtLogin, lockLayout, showQuickRefreshButton, theme
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        gridLayout = try values.decodeIfPresent(String.self, forKey: .gridLayout)
        includeDockSystemApps = try values.decodeIfPresent(Bool.self, forKey: .includeDockSystemApps) ?? false
        hotkeyCode = try values.decodeIfPresent(Int.self, forKey: .hotkeyCode)
        hotkeyModifiers = try values.decodeIfPresent(Int.self, forKey: .hotkeyModifiers)
        hotkeyLabel = try values.decodeIfPresent(String.self, forKey: .hotkeyLabel)
        hotCorner = try values.decodeIfPresent(String.self, forKey: .hotCorner) ?? "off"
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lockLayout = try values.decodeIfPresent(Bool.self, forKey: .lockLayout) ?? false
        showQuickRefreshButton = try values.decodeIfPresent(Bool.self, forKey: .showQuickRefreshButton) ?? false
        theme = try values.decodeIfPresent(String.self, forKey: .theme) ?? "system"
    }
}

struct LauncherData: Codable {
    var schemaVersion = 1
    var launcherState = LauncherState()
    var utilitiesFolderInitialized = false
    var preferences = LauncherPreferences()
}

final class LauncherStore {
    static let shared = LauncherStore()

    static var defaultURL: URL {
        if let testPath = ProcessInfo.processInfo.environment["CLASSIC_LAUNCHPAD_DATA_PATH"] {
            return URL(fileURLWithPath: testPath)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClassicLaunchpad", isDirectory: true)
            .appendingPathComponent("Data.store")
    }

    let fileURL: URL
    private(set) var data: LauncherData
    private var canWrite = true

    init(fileURL: URL = LauncherStore.defaultURL, legacyDefaults: UserDefaults? = .standard) {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                data = try JSONDecoder().decode(LauncherData.self, from: Data(contentsOf: fileURL))
            } catch {
                data = LauncherData()
                canWrite = false // Keep an unreadable store intact for recovery.
                NSLog("Could not read %@: %@", fileURL.path, error.localizedDescription)
            }
        } else {
            var migrated = LauncherData()
            if let legacyDefaults {
                if let value = legacyDefaults.data(forKey: "launcherStateV1"),
                   let state = try? JSONDecoder().decode(LauncherState.self, from: value) {
                    migrated.launcherState = state
                }
                migrated.utilitiesFolderInitialized = legacyDefaults.bool(forKey: "utilitiesFolderInitializedV1")
                migrated.preferences.gridLayout = legacyDefaults.string(forKey: "gridLayout")
                migrated.preferences.includeDockSystemApps = legacyDefaults.bool(forKey: "includeDockSystemApps")
                if legacyDefaults.object(forKey: "hotkeyCode") != nil {
                    migrated.preferences.hotkeyCode = legacyDefaults.integer(forKey: "hotkeyCode")
                }
                if legacyDefaults.object(forKey: "hotkeyModifiers") != nil {
                    migrated.preferences.hotkeyModifiers = legacyDefaults.integer(forKey: "hotkeyModifiers")
                }
                migrated.preferences.hotkeyLabel = legacyDefaults.string(forKey: "hotkeyLabel")
                migrated.preferences.hotCorner = legacyDefaults.string(forKey: "hotCorner") ?? "off"
            }
            data = migrated
            persist()
        }
    }

    func saveState(_ state: LauncherState) {
        data.launcherState = state
        persist()
    }

    func setUtilitiesFolderInitialized() {
        data.utilitiesFolderInitialized = true
        persist()
    }

    func updatePreferences(_ edit: (inout LauncherPreferences) -> Void) {
        edit(&data.preferences)
        persist()
    }

    private func persist() {
        guard canWrite else { return }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            NSLog("Could not save %@: %@", fileURL.path, error.localizedDescription)
        }
    }
}
