import XCTest
@testable import AILimitBarCore

final class UsageSnapshotTests: XCTestCase {
    func testUsageSnapshotRoundTripsThroughJSON() throws {
        let snapshot = UsageSnapshot(
            providerID: "mock",
            displayName: "Mock Provider",
            status: .ok,
            planName: "Development",
            periodLabel: "Rolling mock window",
            usedPercent: 42,
            remainingLabel: "Approx. 58% remaining",
            resetAt: Date(timeIntervalSince1970: 1_800),
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .localEstimate,
            source: "Generated mock data",
            warnings: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }
}
