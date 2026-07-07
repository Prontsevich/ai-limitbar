import XCTest
@testable import AILimitBarCore

final class ProviderRefreshCoordinatorTests: XCTestCase {
    func testRefreshReturnsSnapshotsInRequestOrder() async {
        let coordinator = ProviderRefreshCoordinator()
        let requests = [
            ProviderRefreshRequest(
                adapter: TestProviderAdapter(id: "first", displayName: "First"),
                account: ProviderAccount(providerID: "first", isEnabled: true)
            ),
            ProviderRefreshRequest(
                adapter: TestProviderAdapter(id: "second", displayName: "Second"),
                account: ProviderAccount(providerID: "second", accountID: "work", displayName: "Work", isEnabled: true)
            )
        ]

        let snapshots = await coordinator.refresh(requests)

        XCTAssertEqual(snapshots.map(\.providerID), ["first", "second"])
        XCTAssertEqual(snapshots.map(\.accountID), ["default", "work"])
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
                account: ProviderAccount(providerID: "failing", accountID: "work", displayName: "Work", isEnabled: true)
            )
        ]

        let snapshots = await coordinator.refresh(requests)

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].providerID, "failing")
        XCTAssertEqual(snapshots[0].accountID, "work")
        XCTAssertEqual(snapshots[0].accountDisplayName, "Work")
        XCTAssertEqual(snapshots[0].status, .error)
        XCTAssertEqual(snapshots[0].remainingLabel, "Refresh failed")
        XCTAssertEqual(snapshots[0].confidence, .unknown)
        XCTAssertEqual(snapshots[0].warnings, ["Snapshot file is missing.", "Choose a readable JSON file."])
    }

    func testRefreshRetriesTransientErrors() async {
        let counter = FetchCounter()
        let coordinator = ProviderRefreshCoordinator(
            retryPolicy: ProviderRetryPolicy(maxAttempts: 2, initialDelay: 0)
        )
        let requests = [
            ProviderRefreshRequest(
                adapter: FlakyProviderAdapter(counter: counter),
                account: ProviderAccount(providerID: "flaky", isEnabled: true)
            )
        ]

        let snapshots = await coordinator.refresh(requests)
        let attempts = await counter.attempts

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].providerID, "flaky")
        XCTAssertEqual(snapshots[0].status, .ok)
    }

    func testRefreshDoesNotRetryPermanentErrors() async {
        let counter = FetchCounter()
        let coordinator = ProviderRefreshCoordinator(
            retryPolicy: ProviderRetryPolicy(maxAttempts: 2, initialDelay: 0)
        )
        let requests = [
            ProviderRefreshRequest(
                adapter: FailingProviderAdapter(counter: counter, isTransient: false),
                account: ProviderAccount(providerID: "permanent", isEnabled: true)
            )
        ]

        let snapshots = await coordinator.refresh(requests)
        let attempts = await counter.attempts

        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(snapshots[0].status, .error)
    }
}

private struct TestProviderAdapter: ProviderAdapter {
    let id: String
    let displayName: String
    let usageURL: URL? = nil
    let error: ProviderAdapterError?

    init(id: String, displayName: String, error: ProviderAdapterError? = nil) {
        self.id = id
        self.displayName = displayName
        self.error = error
    }

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        if let error {
            throw error
        }

        return UsageSnapshot(
            providerID: id,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: displayName,
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .localEstimate,
            source: "Test adapter"
        )
    }
}

private actor FetchCounter {
    private(set) var attempts = 0

    func increment() -> Int {
        attempts += 1
        return attempts
    }
}

private struct FlakyProviderAdapter: ProviderAdapter {
    let id = "flaky"
    let displayName = "Flaky"
    let usageURL: URL? = nil
    let counter: FetchCounter

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        let attempt = await counter.increment()
        if attempt == 1 {
            throw ProviderAdapterError(
                providerID: id,
                message: "Network timeout.",
                isTransient: true
            )
        }

        return UsageSnapshot(
            providerID: id,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: displayName,
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .localEstimate,
            source: "Flaky adapter"
        )
    }
}

private struct FailingProviderAdapter: ProviderAdapter {
    let id = "permanent"
    let displayName = "Permanent"
    let usageURL: URL? = nil
    let counter: FetchCounter
    let isTransient: Bool

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        _ = await counter.increment()
        throw ProviderAdapterError(
            providerID: id,
            message: "Configuration is missing.",
            isTransient: isTransient
        )
    }
}
