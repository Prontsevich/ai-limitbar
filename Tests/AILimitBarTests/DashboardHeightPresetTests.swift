import XCTest
@testable import AILimitBar

final class DashboardHeightPresetTests: XCTestCase {
    func testPresetsUseStableStorageValuesAndViewportHeights() {
        XCTAssertEqual(DashboardHeightPreset.compact.rawValue, "compact")
        XCTAssertEqual(DashboardHeightPreset.standard.rawValue, "standard")
        XCTAssertEqual(DashboardHeightPreset.tall.rawValue, "tall")

        XCTAssertEqual(DashboardHeightPreset.compact.viewportHeight, 320)
        XCTAssertEqual(DashboardHeightPreset.standard.viewportHeight, 460)
        XCTAssertEqual(DashboardHeightPreset.tall.viewportHeight, 640)
    }
}
