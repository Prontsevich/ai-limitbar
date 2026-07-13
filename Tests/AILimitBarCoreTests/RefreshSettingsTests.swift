import XCTest
@testable import AILimitBarCore

final class RefreshSettingsTests: XCTestCase {
    func testRefreshIntervalDisplayNamesAndDurations() {
        XCTAssertEqual(RefreshInterval.manualOnly.displayName, "Manual only")
        XCTAssertNil(RefreshInterval.manualOnly.timeInterval)
        XCTAssertEqual(RefreshInterval.manualOnly.staleAfter, 24 * 60 * 60)

        XCTAssertEqual(RefreshInterval.fifteenMinutes.displayName, "15 min")
        XCTAssertEqual(RefreshInterval.fifteenMinutes.timeInterval, 15 * 60)
        XCTAssertEqual(RefreshInterval.fifteenMinutes.staleAfter, 30 * 60)

        XCTAssertEqual(RefreshInterval.thirtyMinutes.displayName, "30 min")
        XCTAssertEqual(RefreshInterval.thirtyMinutes.timeInterval, 30 * 60)
        XCTAssertEqual(RefreshInterval.thirtyMinutes.staleAfter, 60 * 60)

        XCTAssertEqual(RefreshInterval.oneHour.displayName, "1 hr")
        XCTAssertEqual(RefreshInterval.oneHour.timeInterval, 60 * 60)
        XCTAssertEqual(RefreshInterval.oneHour.staleAfter, 2 * 60 * 60)
    }

    func testDatabaseRefreshSettingsStoreLoadsDefaultsWhenMissing() throws {
        let store = DatabaseRefreshSettingsStore(database: try database())

        let result = store.load(defaults: RefreshSettings())

        XCTAssertEqual(result.settings, RefreshSettings())
        XCTAssertNil(result.warning)
    }

    func testDatabaseRefreshSettingsStoreRoundTripsSettings() throws {
        let store = DatabaseRefreshSettingsStore(database: try database())
        let settings = RefreshSettings(interval: .thirtyMinutes)

        try store.save(settings)
        let result = store.load(defaults: RefreshSettings())

        XCTAssertEqual(result.settings, settings)
        XCTAssertNil(result.warning)
    }

    private func database() throws -> AppDatabase {
        try AppDatabase(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    }
}
