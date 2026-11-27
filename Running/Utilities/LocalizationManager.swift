import Foundation
import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String {
        didSet {
            persistLanguagePreference()
            refreshLocalization()
        }
    }

    @Published var locale: Locale
    private var currentBundle: Bundle?
    private var localeDidChangeObserver: NSObjectProtocol?

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        let preferredLanguage = LocalizationPreferenceResolver.resolveInitialLanguage(
            arguments: arguments,
            storedAppLanguage: UserDefaults.standard.string(forKey: "app_language"),
            storedSettingsLanguage: StorageManager.shared.loadSettings().language
        )
        self.currentLanguage = preferredLanguage
        self.locale = LocalizationPreferenceResolver.resolveLocale(for: preferredLanguage)
        self.currentBundle = LocalizationManager.getBundle(from: preferredLanguage)
        registerSystemLocaleObserver()
    }

    private static func getBundle(from language: String) -> Bundle? {
        let langCode = LocalizationPreferenceResolver.resolveBundleLanguage(for: language)
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj") {
            return Bundle(path: path)
        }
        return nil
    }

    private func registerSystemLocaleObserver() {
        localeDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshSystemLocalizationIfNeeded()
        }
    }

    private func persistLanguagePreference() {
        UserDefaults.standard.set(currentLanguage, forKey: "app_language")
        var settings = StorageManager.shared.loadSettings()
        if settings.language != currentLanguage {
            settings.language = currentLanguage
            StorageManager.shared.saveSettings(settings)
        }
    }

    private func refreshLocalization() {
        locale = LocalizationPreferenceResolver.resolveLocale(for: currentLanguage)
        currentBundle = LocalizationManager.getBundle(from: currentLanguage)
    }

    private func refreshSystemLocalizationIfNeeded() {
        guard currentLanguage == "system" else { return }
        refreshLocalization()
    }

    func setLanguage(_ language: String) {
        let resolvedLanguage = LocalizationPreferenceResolver.resolveInitialLanguage(
            arguments: [],
            storedAppLanguage: language,
            storedSettingsLanguage: nil
        )
        guard currentLanguage != resolvedLanguage else {
            if resolvedLanguage == "system" {
                refreshLocalization()
            }
            return
        }
        currentLanguage = resolvedLanguage
    }

    func synchronizeWithSettingsLanguage(_ language: String) {
        let resolvedLanguage = LocalizationPreferenceResolver.resolveInitialLanguage(
            arguments: ProcessInfo.processInfo.arguments,
            storedAppLanguage: nil,
            storedSettingsLanguage: language
        )
        guard currentLanguage != resolvedLanguage else { return }
        currentLanguage = resolvedLanguage
    }

    var isSystemLanguage: Bool { currentLanguage == "system" }

    var displayLanguageName: String {
        switch currentLanguage {
        case "en": return "english".localized
        case "zh-Hans": return "chinese".localized
        case "system": return "follow_system".localized
        default: return "chinese".localized
        }
    }
    
    func localized(_ key: String) -> String {
        if let bundle = currentBundle {
            return bundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return NSLocalizedString(key, comment: "")
    }
}

extension String {
    var localized: String {
        LocalizationManager.shared.localized(self)
    }

    func localized(with arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}
