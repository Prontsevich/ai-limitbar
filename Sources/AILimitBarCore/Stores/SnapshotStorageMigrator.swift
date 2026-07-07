import Foundation

public struct SnapshotStorageMigrationResult: Equatable, Sendable {
    public let didMigrate: Bool
    public let warning: String?

    public init(didMigrate: Bool, warning: String? = nil) {
        self.didMigrate = didMigrate
        self.warning = warning
    }
}

public struct SnapshotStorageMigrator: Sendable {
    private let filename: String

    public init(filename: String = "snapshots.json") {
        self.filename = filename
    }

    public func migrateIfNeeded(
        from source: any SnapshotStorageContainer,
        to destination: any SnapshotStorageContainer
    ) -> SnapshotStorageMigrationResult {
        let sourceFile = source.snapshotsDirectory.appendingPathComponent(filename)
        let destinationFile = destination.snapshotsDirectory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: sourceFile.path) else {
            return SnapshotStorageMigrationResult(didMigrate: false)
        }

        guard !FileManager.default.fileExists(atPath: destinationFile.path) else {
            return SnapshotStorageMigrationResult(didMigrate: false)
        }

        let sourceStore = JSONSnapshotStore(container: source, filename: filename)
        let loadResult = sourceStore.load()
        if let warning = loadResult.warning {
            return SnapshotStorageMigrationResult(didMigrate: false, warning: warning)
        }

        do {
            try FileManager.default.createDirectory(
                at: destination.snapshotsDirectory,
                withIntermediateDirectories: true
            )
            let destinationStore = JSONSnapshotStore(container: destination, filename: filename)
            try destinationStore.save(loadResult.snapshots)
            return SnapshotStorageMigrationResult(didMigrate: true)
        } catch {
            return SnapshotStorageMigrationResult(
                didMigrate: false,
                warning: "Stored snapshots could not be migrated to the selected container."
            )
        }
    }
}
