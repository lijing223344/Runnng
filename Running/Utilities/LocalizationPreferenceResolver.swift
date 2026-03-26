import Foundation

enum LocalizationPreferenceResolver {
    static func resolveInitialLanguage(
        arguments: [String],
        storedAppLanguage: String?,
        storedSettingsLanguage: String?
    ) -> String {
        if let index = arguments.firstIndex(of: "-app_language"), index + 1 < arguments.count {
            return sanitize(arguments[index + 1])
        }
        if let storedSettingsLanguage, !storedSettingsLanguage.isEmpty {
            return sanitize(storedSettingsLanguage)
        }
        if let storedAppLanguage, !storedAppLanguage.isEmpty {
            return sanitize(storedAppLanguage)
        }
        return "system"
    }

    static func resolveBundleLanguage(
        for selectedLanguage: String,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        switch sanitize(selectedLanguage) {
        case "en":
            return "en"
        case "zh-Hans":
            return "zh-Hans"
        case "system":
            return resolveSupportedSystemLanguage(preferredLanguages)
        default:
            return "zh-Hans"
        }
    }

    static func resolveLocale(
        for selectedLanguage: String,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        switch sanitize(selectedLanguage) {
        case "system":
            return .autoupdatingCurrent
        default:
            return Locale(identifier: resolveBundleLanguage(for: selectedLanguage, preferredLanguages: preferredLanguages))
        }
    }

    private static func resolveSupportedSystemLanguage(_ preferredLanguages: [String]) -> String {
        for language in preferredLanguages {
            if language.hasPrefix("zh") {
                return "zh-Hans"
            }
            if language.hasPrefix("en") {
                return "en"
            }
        }
        return "en"
    }

    private static func sanitize(_ language: String) -> String {
        switch language {
        case "en":
            return "en"
        case "zh-Hans", "zh":
            return "zh-Hans"
        case "system":
            return "system"
        default:
            return language
        }
    }
}
