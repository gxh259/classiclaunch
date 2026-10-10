import AppKit

final class InstallerController: NSObject, NSApplicationDelegate {
    private var progressWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let installerURL = Bundle.main.bundleURL
        let sourceURL = installerURL.deletingLastPathComponent()
            .appendingPathComponent("启动台.app", isDirectory: true)
        let destinationURL = URL(fileURLWithPath: "/Applications/启动台.app", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            showError(AppInstallationError.invalidSource)
            return
        }

        let updating = FileManager.default.fileExists(atPath: destinationURL.path)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(updating ? "更新启动台" : "安装启动台", comment: "")
        alert.informativeText = NSLocalizedString(
            updating
                ? "将先退出正在运行的旧版启动台，再替换“应用程序”中的应用。图标排序和设置会保留。"
                : "将启动台安装到“应用程序”。图标排序和设置会保留。",
            comment: "")
        alert.addButton(withTitle: NSLocalizedString(
            updating ? "退出旧版并更新" : "安装到应用程序", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.terminate(nil)
            return
        }

        showProgress()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try AppInstaller().install(from: sourceURL) }
            DispatchQueue.main.async {
                self.progressWindow?.close()
                self.progressWindow = nil
                switch result {
                case .success(let installedURL):
                    self.showSuccess(installedURL)
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    private func showProgress() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 112),
                            styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = NSLocalizedString("安装启动台", comment: "")
        panel.center()
        panel.isReleasedWhenClosed = false
        let spinner = NSProgressIndicator(frame: NSRect(x: 28, y: 39, width: 30, height: 30))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        let label = NSTextField(labelWithString: NSLocalizedString("正在退出旧版并安装启动台…", comment: ""))
        label.frame = NSRect(x: 72, y: 41, width: 270, height: 25)
        panel.contentView?.addSubview(spinner)
        panel.contentView?.addSubview(label)
        panel.makeKeyAndOrderFront(nil)
        progressWindow = panel
    }

    private func showSuccess(_ installedURL: URL) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("启动台已安装", comment: "")
        alert.informativeText = NSLocalizedString(
            "新版已安装到“应用程序”，原有图标排序和设置已保留。", comment: "")
        alert.addButton(withTitle: NSLocalizedString("打开新版", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("完成", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", installedURL.path]
            do { try process.run() }
            catch { showError(error); return }
        }
        NSApp.terminate(nil)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("无法安装启动台", comment: "")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: NSLocalizedString("在访达中显示", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("关闭", comment: ""))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
        NSApp.terminate(nil)
    }
}

@main struct InstallerMain {
    private static let controller = InstallerController()

    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.delegate = controller
        application.run()
    }
}
