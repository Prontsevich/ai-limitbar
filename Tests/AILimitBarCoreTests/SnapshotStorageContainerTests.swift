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
        let data = try Data(contentsOf: directory.appendingPathComponent("snapshots.json"))
        let document = try JSONDecoder.iso8601.decode(UsageSnapshotDocument.self, from: data)

        XCTAssertEqual(result.snapshots, [snapshot])
        XCTAssertNil(result.warning)
        XCTAssertEqual(document.formatVersion, UsageSnapshotDocument.currentFormatVersion)
        XCTAssertEqual(document.snapshots, [snapshot])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("snapshots.json").path))
    }

    func testJSONSnapshotStoreLoadsLegacySnapshotArray() throws {
        let directory = try temporaryDirectory()
        let snapshot = UsageSnapshot(
            providerID: "legacy",
            displayName: "Legacy",
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .manual,
            source: "Legacy test"
        )
        let data = try JSONEncoder.iso8601.encode([snapshot])
        try data.write(to: directory.appendingPathComponent("snapshots.json"))

        let store = JSONSnapshotStore(container: LocalSnapshotStorageContainer(snapshotsDirectory: directory))
        let result = store.load()

        XCTAssertEqual(result.snapshots, [snapshot])
        XCTAssertNil(result.warning)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
