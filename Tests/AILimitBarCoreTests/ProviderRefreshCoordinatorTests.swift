import XCTest
@testable import AILimitBarCore

final class ProviderRefreshCoordinatorTests: XCTestCase {
    func testRefreshReturnsSnapshotsInRequestOrder() async {
        let coordinator = ProviderRefreshCoordinator()
        let requests = [
            ProviderRefreshRequest(
                adapter: TestProviderAdapter(id: "first", displayName: "First"),
                configuration: ProviderConfiguration(providerID: "first", isEnabled: true)
            ),
            ProviderRefreshRequest(
                adapter: TestProviderAdapter(id: "second", displayName: "Second"),
                configuration: ProviderConfiguration(providerID: "second", isEnabled: true)
            )
        ]

        let snapshots = await coordinator.refresh(requests)

        XCTAssertEqual(snapshots.map(\.providerID), ["first", "second"])
        XCTAssertEqual(snapshots.map(\.status), [.ok, .ok])
    }

    func testRefreshConvertsAdapterErrorsToSnapshots() async {
        let coordinator = ProviderRefreshCoordinator()
        let requests = [
            ProviderRefreshRequest(
                adapter: TestProviderAdapter(
                    id: "failing",
                    displayName: "Failing",
                    error: ProviderAdapterError(
                        providerID: "failing",
                        message: "Snapshot file is missing.",
                        recoverySuggestion: "Choose a readable JSON file."
                    )
                ),
                configuration: ProviderConfiguration(providerID: "failing", isEnabled: true)
            )
        ]

        let snapshots = await coordinator.refresh(requests)

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].providerID, "failing")
        XCTAssertEqual(snapshots[0].status, .error)
        XCTAssertEqual(snapshots[0].remainingLabel, "Refresh failed")
        XCTAssertEqual(snapshots[0].confidence, .unknown)
        XCTAssertEqual(snapshots[0].warnings, ["Snapshot file is missing.", "Choose a readable JSON file."])
    }
}

private struct TestProviderAdapter: ProviderAdapter {
    let id: String
    let displayName: String
    let defaultEnabled = false
    let usageURL: URL? = nil
    let error: ProviderAdapterError?

    init(id: String, displayName: String, error: ProviderAdapterError? = nil) {
        self.id = id
        self.displayName = displayName
        self.error = error
    }

    func fetchSnapshot(configuration: ProviderConfiguration) async throws -> UsageSnapshot {
        if let error {
            throw error
        }

        return UsageSnapshot(
            providerID: id,
            displayName: displayName,
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .localEstimate,
            source: "Test adapter"
        )
    }
}
