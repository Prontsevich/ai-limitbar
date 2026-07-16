import Foundation
import XCTest
@testable import AILimitBar

@MainActor
final class AppLanguageTests: XCTestCase {
    func testLanguagesUseStableStorageValues() {
        XCTAssertEqual(AppLanguage.storageKey, "app-language")
        XCTAssertEqual(AppLanguage.systemDefault.rawValue, "system")
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.russian.rawValue, "ru")
    }

    func testSystemDefaultUsesProvidedSystemLocaleAndExplicitChoicesUseTheirLanguage() {
        let systemLocale = Locale(identifier: "ru_BY")

        XCTAssertEqual(
            AppLanguage.systemDefault.resolvedLocale(systemLocale: systemLocale).identifier,
            "ru_BY"
        )
        XCTAssertEqual(
            AppLanguage.english.resolvedLocale(systemLocale: systemLocale).identifier,
            "en"
        )
        XCTAssertEqual(
            AppLanguage.russian.resolvedLocale(systemLocale: systemLocale).identifier,
            "ru"
        )
    }

    func testPreferenceFallsBackToSystemDefaultAndPersistsSelection() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        userDefaults.set("unsupported", forKey: AppLanguage.storageKey)
        let preference = AppLanguagePreference(
            userDefaults: userDefaults,
            systemLocaleProvider: { Locale(identifier: "en_US") }
        )
        XCTAssertEqual(preference.language, .systemDefault)
        XCTAssertEqual(preference.effectiveLocale.identifier, "en_US")

        preference.select(.russian)
        let restoredPreference = AppLanguagePreference(
            userDefaults: userDefaults,
            systemLocaleProvider: { Locale(identifier: "en_US") }
        )

        XCTAssertEqual(restoredPreference.language, .russian)
        XCTAssertEqual(restoredPreference.effectiveLocale.identifier, "ru")
    }

    func testSystemDefaultRefreshesItsEffectiveLocale() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        var systemLocale = Locale(identifier: "ru_RU")
        let preference = AppLanguagePreference(
            userDefaults: userDefaults,
            systemLocaleProvider: { systemLocale }
        )

        systemLocale = Locale(identifier: "en_GB")
        preference.refreshSystemLocale()

        XCTAssertEqual(preference.effectiveLocale.identifier, "en_GB")
    }

    func testSelectionImmediatelyChangesLocalizedPresentation() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let preference = AppLanguagePreference(
            userDefaults: userDefaults,
            systemLocaleProvider: { Locale(identifier: "en_US") }
        )
        XCTAssertEqual(
            AppStrings.MenuBar.settings.localized(locale: preference.effectiveLocale),
            "Settings"
        )

        preference.select(.russian)

        XCTAssertEqual(
            AppStrings.MenuBar.settings.localized(locale: preference.effectiveLocale),
            "Настройки"
        )
        XCTAssertEqual(
            AppStrings.Settings.Language.title.localized(locale: preference.effectiveLocale),
            "ЯЗЫК"
        )
    }

    private func makeUserDefaults() -> (UserDefaults, String) {
        let suiteName = "AppLanguageTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated test user defaults")
        }
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
    }
}
