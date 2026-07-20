import Foundation
import XCTest
@testable import AILimitBar

final class AppLocalizationTests: XCTestCase {
    func testMenuBarResourcesResolveInEnglishAndRussian() {
        XCTAssertEqual(
            AppStrings.MenuBar.noEnabledAccounts.localized(locale: Locale(identifier: "en")),
            "No enabled accounts."
        )
        XCTAssertEqual(
            AppStrings.MenuBar.noEnabledAccounts.localized(locale: Locale(identifier: "ru")),
            "Нет включённых аккаунтов."
        )
    }

    func testMissingRussianTranslationUsesReadableEnglishDefault() {
        let string = AppString(
            "localization.test.missing_russian_translation",
            defaultValue: "Readable English fallback",
            comment: "Test-only missing Russian translation"
        )

        XCTAssertEqual(
            string.localized(locale: Locale(identifier: "ru")),
            "Readable English fallback"
        )
    }

    func testResourceBundleDeclaresBothSupportedLocalizations() {
        XCTAssertTrue(AppLocalization.resourceBundle.localizations.contains("en"))
        XCTAssertTrue(AppLocalization.resourceBundle.localizations.contains("ru"))
    }

    func testPercentageFormatterKeepsOneProviderFractionDigit() {
        XCTAssertEqual(
            AppFormatters.percentage(35.4, locale: Locale(identifier: "en_US")),
            "35.4%"
        )
        XCTAssertEqual(
            AppFormatters.percentage(42, locale: Locale(identifier: "en_US")),
            "42%"
        )

        let russianPercentage = AppFormatters.percentage(35.4, locale: Locale(identifier: "ru_RU"))
        XCTAssertTrue(russianPercentage.contains("35,4"))
        XCTAssertTrue(russianPercentage.contains("%"))
    }

    func testPresentationStringsResolveInRussian() {
        let locale = Locale(identifier: "ru")
        XCTAssertEqual(AppStrings.Settings.Navigation.general.localized(locale: locale), "Основные")
        XCTAssertEqual(AppStrings.Dashboard.used.formatted(locale: locale, "35,4 %"), "Ушло 35,4 %")
        XCTAssertEqual(AppStrings.Window.settingsTitle.localized(locale: locale), "Настройки AI Limitbar")
    }
}
