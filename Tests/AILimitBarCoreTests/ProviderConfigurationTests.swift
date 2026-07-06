import XCTest
@testable import AILimitBarCore

final class ProviderConfigurationTests: XCTestCase {
    func testProviderConfigurationDecodesLegacyJSONAsManualMode() throws {
        let json = """
        {
          "providerID": "claude-code",
          "isEnabled": true
        }
        """

        let configuration = try JSONDecoder().decode(ProviderConfiguration.self, from: Data(json.utf8))

        XCTAssertEqual(configuration.providerID, "claude-code")
        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.sourceMode, .manual)
        XCTAssertNil(configuration.localSnapshotPath)
    }

    func testProviderConfigurationRoundTripsLocalSnapshotSettings() throws {
        let configuration = ProviderConfiguration(
            providerID: "claude-code",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: "/Users/example/Library/Application Support/AI Limitbar/claude-code.json"
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(ProviderConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
    }
}
