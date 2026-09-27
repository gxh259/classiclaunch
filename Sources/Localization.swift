import Foundation

enum LauncherLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var title: String {
        switch self {
        case .system: L("跟随系统")
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        }
    }
}

enum Localization {
    static func resolvedLanguage(selection: String,
                                 preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if ["zh-Hans", "zh-Hant", "en"].contains(selection) { return selection }
        for language in preferredLanguages {
            let code = language.lowercased().replacingOccurrences(of: "_", with: "-")
            if code == "zh" || code.hasPrefix("zh-") {
                if code.contains("hant") || code.contains("-tw") ||
                    code.contains("-hk") || code.contains("-mo") { return "zh-Hant" }
                return "zh-Hans"
            }
            if code == "en" || code.hasPrefix("en-") { return "en" }
        }
        return "en"
    }

    static var activeLanguage: String {
        resolvedLanguage(selection: LauncherStore.shared.data.preferences.language)
    }

    private static let bundles: [String: Bundle] = {
        var result: [String: Bundle] = [:]
        for language in ["zh-Hant", "en"] {
            if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) { result[language] = bundle }
        }
        return result
    }()

    static func text(_ key: String, in language: String) -> String {
        guard let bundle = bundles[language] else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func text(_ key: String) -> String { text(key, in: activeLanguage) }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: activeLanguage), arguments: arguments)
    }
}

func L(_ key: String) -> String { Localization.text(key) }
