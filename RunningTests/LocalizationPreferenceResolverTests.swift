import XCTest
@testable import Running

final class LocalizationPreferenceResolverTests: XCTestCase {
    func testResolveInitialLanguagePrefersLaunchArgument() {
        let language = LocalizationPreferenceResolver.resolveInitialLanguage(
            arguments: ["-app_language", "en"],
            storedAppLanguage: "zh-Hans",
            storedSettingsLanguage: "system"
        )

        XCTAssertEqual(language, "en")
    }

    func testResolveInitialLanguagePrefersStoredSettingsOverLegacyAppLanguage() {
        let language = LocalizationPreferenceResolver.resolveInitialLanguage(
            arguments: [],
            storedAppLanguage: "en",
            storedSettingsLanguage: "system"
        )

        XCTAssertEqual(language, "system")
    }

    func testResolveInitialLanguageFallsBackToStoredSettings() {
        let language = LocalizationPreferenceResolver.resolveInitialLanguage(
            arguments: [],
            storedAppLanguage: nil,
            storedSettingsLanguage: "zh-Hans"
        )

        XCTAssertEqual(language, "zh-Hans")
    }

    func testResolveBundleLanguageMapsSystemChineseToSupportedChineseBundle() {
        let language = LocalizationPreferenceResolver.resolveBundleLanguage(
            for: "system",
            preferredLanguages: ["zh-CN", "en-CN"]
        )

        XCTAssertEqual(language, "zh-Hans")
    }

    func testResolveBundleLanguageFallsBackToEnglishForUnsupportedSystemLanguage() {
        let language = LocalizationPreferenceResolver.resolveBundleLanguage(
            for: "system",
            preferredLanguages: ["fr-FR", "de-DE"]
        )

        XCTAssertEqual(language, "en")
    }
}
