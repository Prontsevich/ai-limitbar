import XCTest
@testable import AILimitBarCore

final class SnapshotStorageMigratorTests: XCTestCase {
    func testMigratesLegacyLocalSnapshotArrayIntoVersionedDestinationDocument() throws {
        let source = LocalSnapshotStorageContainer(snapshotsDirectory: try temporaryDirectory())
        let destination = LocalSnapshotStorageContainer(snapshotsDirectory: try temporaryDirectory())
        let snapshot = UsageSnapshot(
            providerID: "legacy",
            displayName: "Legacy",
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .manual,
            source: "Legacy test"
        )
        let sourceData = try JSONEncoder.iso8601.encode([snapshot])
        try sourceData.write(to: source.snapshotsDirectory.appendingPathComponent("snapshots.json"))

        let result = SnapshotStorageMigrator().migrateIfNeeded(from: source, to: destination)
        let destinationData = try Data(contentsOf: destination.snapshotsDirectory.appendingPathComponent("snapshots.json"))
        let document = try JSONDecoder.iso8601.decode(UsageSnapshotDocument.self, from: destinationData)

        XCTAssertTrue(result.didMigrate)
        XCTAssertNil(result.warning)
        XCTAssertEqual(document.formatVersion, UsageSnapshotDocument.currentFormatVersion)
        XCTAssertEqual(document.snapshots, [snapshot])
    }

    func testMigrationDoesNotOverwriteExistingDestinationSnapshotFile() throws {
        let source = LocalSnapshotStorageContainer(snapshotsDirectory: try temporaryDirectory())
        let destination = LocalSnapshotStorageContainer(snapshotsDirectory: try temporaryDirectory())
        let sourceSnapshot = UsageSnapshot(
            providerID: "source",
            displayName: "Source",
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
            confidence: .manual,
            source: "Source test"
        )
        let destinationSnapshot = UsageSnapshot(
            providerID: "destination",
            displayName: "Destination",
            status: .ok,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_300),
            confidence: .manual,
            source: "Destination test"
        )
        try JSONSnapshotStore(container: source).save([sourceSnapshot])
        try JSONSnapshotStore(container: destination).save([destinationSnapshot])

        let result = SnapshotStorageMigrator().migrateIfNeeded(from: source, to: destination)
        let destinationResult = JSONSnapshotStore(container: destination).load()

        XCTAssertFalse(result.didMigrate)
        XCTAssertNil(result.warning)
        XCTAssertEqual(destinationResult.snapshots, [destinationSnapshot])
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
