import Foundation

public struct SnapshotLoadResult: Sendable {
    public let snapshots: [UsageSnapshot]
    public let warning: String?

    public init(snapshots: [UsageSnapshot], warning: String? = nil) {
        self.snapshots = snapshots
        self.warning = warning
    }
}

public final class JSONSnapshotStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, filename: String = "snapshots.json") {
        self.fileURL = directory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() -> SnapshotLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return SnapshotLoadResult(snapshots: [])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let snapshots = try decoder.decode([UsageSnapshot].self, from: data)
            return SnapshotLoadResult(snapshots: snapshots)
        } catch {
            return SnapshotLoadResult(
                snapshots: [],
                warning: "Stored snapshots could not be loaded and were ignored."
            )
        }
    }

    public func save(_ snapshots: [UsageSnapshot]) throws {
        let data = try encoder.encode(snapshots)
        try data.write(to: fileURL, options: [.atomic])
    }
}
