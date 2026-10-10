import AppKit
import Foundation

enum AppInstallationError: LocalizedError {
    case invalidSource
    case differentInstalledApp
    case runningVersionCouldNotQuit

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return NSLocalizedString("启动台应用不完整，无法安装。", comment: "")
        case .differentInstalledApp:
            return NSLocalizedString("“应用程序”中的“启动台.app”属于其他软件，未进行替换。", comment: "")
        case .runningVersionCouldNotQuit:
            return NSLocalizedString("旧版启动台仍在运行，未进行替换。请退出旧版后重试。", comment: "")
        }
    }
}

struct AppInstaller {
    static let bundleIdentifier = "local.codex.classiclaunchpad"
    let applicationsDirectory: URL

    init(applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)) {
        self.applicationsDirectory = applicationsDirectory
    }

    private func hasLauncherIdentifier(_ appURL: URL) -> Bool {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data,
                                                                     format: nil) as? [String: Any] else {
            return false
        }
        return info["CFBundleIdentifier"] as? String == Self.bundleIdentifier
    }

    private func isInstallable(_ appURL: URL) -> Bool {
        hasLauncherIdentifier(appURL) && FileManager.default.isExecutableFile(atPath:
            appURL.appendingPathComponent("Contents/MacOS/ClassicLaunchpad").path)
    }

    private func quitRunningVersions() throws {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        func previousVersions() -> [NSRunningApplication] {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier)
                .filter { $0.processIdentifier != ownPID && !$0.isTerminated }
        }

        for application in previousVersions() { application.terminate() }
        let gracefulDeadline = Date().addingTimeInterval(5)
        while !previousVersions().isEmpty && Date() < gracefulDeadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        for application in previousVersions() { application.forceTerminate() }
        let forcedDeadline = Date().addingTimeInterval(3)
        while !previousVersions().isEmpty && Date() < forcedDeadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard previousVersions().isEmpty else { throw AppInstallationError.runningVersionCouldNotQuit }
    }

    @discardableResult
    func install(from source: URL, quitRunning: Bool = true) throws -> URL {
        let fileManager = FileManager.default
        let source = source.standardizedFileURL
        guard isInstallable(source) else { throw AppInstallationError.invalidSource }
        let destination = applicationsDirectory.appendingPathComponent("启动台.app", isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) && !hasLauncherIdentifier(destination) {
            throw AppInstallationError.differentInstalledApp
        }

        let staging = applicationsDirectory.appendingPathComponent(
            ".启动台-安装中-\(UUID().uuidString).app", isDirectory: true)
        let backup = applicationsDirectory.appendingPathComponent(
            ".启动台-旧版-\(UUID().uuidString).app", isDirectory: true)
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: source, to: staging)
        guard isInstallable(staging) else { throw AppInstallationError.invalidSource }

        if quitRunning { try quitRunningVersions() }
        let replacing = fileManager.fileExists(atPath: destination.path)
        if replacing { try fileManager.moveItem(at: destination, to: backup) }
        do {
            try fileManager.moveItem(at: staging, to: destination)
            guard isInstallable(destination) else { throw AppInstallationError.invalidSource }
        } catch {
            try? fileManager.removeItem(at: destination)
            if replacing { try? fileManager.moveItem(at: backup, to: destination) }
            throw error
        }
        if replacing { try fileManager.removeItem(at: backup) }
        return destination
    }
}
