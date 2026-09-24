import Foundation
import ServiceManagement

protocol LoginItemRegistration {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct MainAppRegistration: LoginItemRegistration {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

final class LoginStartup {
    static let shared = LoginStartup()

    // Older versions installed this LaunchAgent. Remove it after the app login item is active.
    let agentURL: URL
    private let applicationsDirectory: URL
    private let registration: LoginItemRegistration

    init(agentURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/local.codex.classiclaunchpad.login.plist"),
         applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true),
         registration: LoginItemRegistration = MainAppRegistration()) {
        self.agentURL = agentURL
        self.applicationsDirectory = applicationsDirectory
        self.registration = registration
    }

    private var hasLegacyAgent: Bool { FileManager.default.fileExists(atPath: agentURL.path) }
    var isEnabled: Bool { registration.status == .enabled || hasLegacyAgent }
    var needsApproval: Bool { registration.status == .requiresApproval }

    func migrateLegacyIfNeeded(appURL: URL) throws {
        guard hasLegacyAgent else { return }
        try enable(appURL: appURL)
    }

    func enable(appURL: URL) throws {
        let executable = appURL.appendingPathComponent("Contents/MacOS/ClassicLaunchpad").path
        guard appURL.standardizedFileURL.deletingLastPathComponent().path == applicationsDirectory.standardizedFileURL.path,
              FileManager.default.isExecutableFile(atPath: executable) else {
            throw NSError(domain: "ClassicLaunchpad", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "请先将“启动台.app”安装到“应用程序”文件夹。"])
        }
        if registration.status != .enabled && registration.status != .requiresApproval {
            try registration.register()
        }
        if registration.status == .enabled {
            if hasLegacyAgent { try FileManager.default.removeItem(at: agentURL) }
        } else if registration.status == .requiresApproval {
            throw NSError(domain: "ClassicLaunchpad", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "请在系统设置的“登录项”中允许启动台，随后再次打开启动台以完成旧登录项迁移。"])
        } else {
            throw NSError(domain: "ClassicLaunchpad", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "系统未确认开机自启动，请重新尝试或在系统登录项设置中检查。"])
        }
    }

    func disable() throws {
        if registration.status == .enabled || registration.status == .requiresApproval {
            try registration.unregister()
        }
        if hasLegacyAgent { try FileManager.default.removeItem(at: agentURL) }
    }
}
