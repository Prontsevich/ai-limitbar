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
}
