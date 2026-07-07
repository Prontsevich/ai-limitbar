import XCTest
@testable import AILimitBarCore

final class SnapshotStorageContainerTests: XCTestCase {
    func testJSONSnapshotStoreUsesContainerDirectory() throws {
        let directory = try temporaryDirectory()
        let container = LocalSnapshotStorageContainer(snapshotsDirectory: directory)
        let store = JSONSnapshotStore(container: container)
        let snapshot = UsageSnapshot(
            providerID: "mock",
            displayName: "Mock Provider",
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .localEstimate,
            source: "Test"
        )

        try store.save([snapshot])
        let result = store.load()

        XCTAssertEqual(result.snapshots, [snapshot])
        XCTAssertNil(result.warning)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("snapshots.json").path))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
