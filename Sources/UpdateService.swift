import AppKit
import CryptoKit
import Foundation

struct UpdateRelease {
    let version: String
    let downloadURL: URL
    let size: Int
    let sha256: String
}

enum UpdateFailure: LocalizedError {
    case invalidResponse, missingPackage, invalidPackage, mountFailed, verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: L("无法读取 GitHub 的版本信息。")
        case .missingPackage: L("最新版本没有可用的 DMG 安装包。")
        case .invalidPackage: L("下载的安装包与 GitHub 发布信息不一致。")
        case .mountFailed: L("无法打开下载的 DMG 安装包。")
        case .verificationFailed: L("安装包中的应用未通过签名或版本校验。")
        }
    }
}

enum UpdateService {
    private static let latestURL = URL(string:
        "https://api.github.com/repos/gxh259/classiclaunch/releases/latest")!

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let assets: [GitHubAsset]
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let size: Int
        let digest: String?
        let browser_download_url: URL
    }

    static func isNewer(_ candidate: String, than installed: String) -> Bool {
        func parts(_ version: String) -> [Int]? {
            let values = version.split(separator: ".")
            guard !values.isEmpty else { return nil }
            let numbers = values.compactMap { Int($0) }
            return numbers.count == values.count ? numbers : nil
        }
        guard let candidateParts = parts(candidate), let installedParts = parts(installed) else { return false }
        for index in 0..<max(candidateParts.count, installedParts.count) {
            let left = index < candidateParts.count ? candidateParts[index] : 0
            let right = index < installedParts.count ? installedParts[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    static func check(completion: @escaping (Result<UpdateRelease, Error>) -> Void) {
        var request = URLRequest(url: latestURL)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ClassicLaunchpad", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            do {
                if let error { throw error }
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let data else { throw UpdateFailure.invalidResponse }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard release.tag_name.hasPrefix("v") else { throw UpdateFailure.invalidResponse }
                let version = String(release.tag_name.dropFirst())
                guard !version.isEmpty, version.split(separator: ".").allSatisfy({ Int($0) != nil })
                    else { throw UpdateFailure.invalidResponse }
                let expectedName = "ClassicLaunchpad-\(version)-universal.dmg"
                guard let asset = release.assets.first(where: { $0.name == expectedName }) else {
                    throw UpdateFailure.missingPackage
                }
                guard asset.size > 0, asset.browser_download_url.scheme == "https",
                      asset.browser_download_url.host == "github.com",
                      asset.browser_download_url.path.hasPrefix(
                        "/gxh259/classiclaunch/releases/download/\(release.tag_name)/"),
                      let digest = asset.digest, digest.hasPrefix("sha256:") else {
                    throw UpdateFailure.invalidPackage
                }
                let hash = String(digest.dropFirst("sha256:".count))
                guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else {
                    throw UpdateFailure.invalidPackage
                }
                completion(.success(UpdateRelease(version: version, downloadURL: asset.browser_download_url,
                                                  size: asset.size, sha256: hash.lowercased())))
            } catch { completion(.failure(error)) }
        }.resume()
    }

    static func downloadAndInstall(_ release: UpdateRelease,
                                   completion: @escaping (Result<URL, Error>) -> Void) {
        var request = URLRequest(url: release.downloadURL)
        request.timeoutInterval = 120
        request.setValue("ClassicLaunchpad", forHTTPHeaderField: "User-Agent")
        URLSession.shared.downloadTask(with: request) { temporaryDownload, response, error in
            do {
                if let error { throw error }
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let temporaryDownload else { throw UpdateFailure.invalidPackage }
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("classiclaunch-update-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: directory) }
                let dmg = directory.appendingPathComponent("update.dmg")
                try FileManager.default.moveItem(at: temporaryDownload, to: dmg)
                let attributes = try FileManager.default.attributesOfItem(atPath: dmg.path)
                guard attributes[.size] as? Int == release.size,
                      try sha256(of: dmg) == release.sha256 else { throw UpdateFailure.invalidPackage }
                let mount = directory.appendingPathComponent("mount", isDirectory: true)
                try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
                try run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-noautoopen",
                                                 "-quiet", "-mountpoint", mount.path, dmg.path],
                        failure: .mountFailed)
                defer { try? run("/usr/bin/hdiutil", ["detach", "-quiet", mount.path],
                                 failure: .mountFailed) }
                let app = mount.appendingPathComponent("启动台.app", isDirectory: true)
                let info = app.appendingPathComponent("Contents/Info.plist")
                guard let values = NSDictionary(contentsOf: info) as? [String: Any],
                      values["CFBundleIdentifier"] as? String == AppInstaller.bundleIdentifier,
                      values["CFBundleShortVersionString"] as? String == release.version else {
                    throw UpdateFailure.verificationFailed
                }
                try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path],
                        failure: .verificationFailed)
                completion(.success(try AppInstaller().install(from: app)))
            } catch { completion(.failure(error)) }
        }.resume()
    }

    private static func sha256(of url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func run(_ executable: String, _ arguments: [String],
                            failure: UpdateFailure) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw failure }
    }
}
