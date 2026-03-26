import Foundation

// Localization support for watchOS.
// Simplified version — Watch uses the system locale directly.

class WatchLocalizationManager {
    static let shared = WatchLocalizationManager()

    private var currentBundle: Bundle?

    private init() {
        let lang = resolveLanguage()
        currentBundle = WatchLocalizationManager.getBundle(from: lang)
    }

    private static func getBundle(from language: String) -> Bundle? {
        let langCode: String
        switch language {
        case "zh-Hans": langCode = "zh-Hans"
        case "en": langCode = "en"
        default:
            // Follow system
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh") { langCode = "zh-Hans" }
            else { langCode = "en" }
        }
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj") {
            return Bundle(path: path)
        }
        return nil
    }

    private func resolveLanguage() -> String {
        // On Watch, we use whatever was synced from iPhone or system default
        if let synced = UserDefaults.standard.string(forKey: "app_language") {
            return synced
        }
        return "system"
    }

    func localized(_ key: String) -> String {
        if let bundle = currentBundle {
            return bundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return NSLocalizedString(key, comment: "")
    }

    func refresh() {
        let lang = resolveLanguage()
        currentBundle = WatchLocalizationManager.getBundle(from: lang)
    }
}

extension String {
    var localized: String {
        WatchLocalizationManager.shared.localized(self)
    }

    func localized(with arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}
