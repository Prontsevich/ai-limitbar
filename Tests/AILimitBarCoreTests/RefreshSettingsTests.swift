import XCTest
@testable import AILimitBarCore

final class RefreshSettingsTests: XCTestCase {
    func testRefreshIntervalDisplayNamesAndDurations() {
        XCTAssertEqual(RefreshInterval.manualOnly.displayName, "Manual only")
        XCTAssertNil(RefreshInterval.manualOnly.timeInterval)

        XCTAssertEqual(RefreshInterval.fifteenMinutes.displayName, "15 min")
        XCTAssertEqual(RefreshInterval.fifteenMinutes.timeInterval, 15 * 60)

        XCTAssertEqual(RefreshInterval.thirtyMinutes.displayName, "30 min")
        XCTAssertEqual(RefreshInterval.thirtyMinutes.timeInterval, 30 * 60)

        XCTAssertEqual(RefreshInterval.oneHour.displayName, "1 hr")
        XCTAssertEqual(RefreshInterval.oneHour.timeInterval, 60 * 60)
    }

    func testRefreshSettingsStoreLoadsDefaultsWhenMissing() throws {
        let store = RefreshSettingsStore(directory: try temporaryDirectory())

        let result = store.load()

        XCTAssertEqual(result.settings, RefreshSettings())
        XCTAssertNil(result.warning)
    }

    func testRefreshSettingsStoreRoundTripsSettings() throws {
        let store = RefreshSettingsStore(directory: try temporaryDirectory())
        let settings = RefreshSettings(interval: .thirtyMinutes)

        try store.save(settings)
        let result = store.load()

        XCTAssertEqual(result.settings, settings)
        XCTAssertNil(result.warning)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
