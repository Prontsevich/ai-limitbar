import Foundation

public protocol SnapshotStorageContainer: Sendable {
    var snapshotsDirectory: URL { get }
}

public struct LocalSnapshotStorageContainer: SnapshotStorageContainer, Equatable {
    public let snapshotsDirectory: URL

    public init(snapshotsDirectory: URL) {
        self.snapshotsDirectory = snapshotsDirectory
    }
}
