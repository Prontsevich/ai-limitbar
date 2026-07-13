import XCTest
@testable import AILimitBar

final class DashboardHeightPresetTests: XCTestCase {
    func testPresetsUseStableStorageValuesAndViewportHeights() {
        XCTAssertEqual(DashboardHeightPreset.compact.rawValue, "compact")
        XCTAssertEqual(DashboardHeightPreset.standard.rawValue, "standard")
        XCTAssertEqual(DashboardHeightPreset.tall.rawValue, "tall")

        XCTAssertEqual(DashboardHeightPreset.compact.maximumViewportHeight, 320)
        XCTAssertEqual(DashboardHeightPreset.standard.maximumViewportHeight, 440)
        XCTAssertEqual(DashboardHeightPreset.tall.maximumViewportHeight, 640)
    }
}
