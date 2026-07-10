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

    public convenience init(container: any SnapshotStorageContainer, filename: String = "snapshots.json") {
        self.init(directory: container.snapshotsDirectory, filename: filename)
    }

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
            if let document = try? decoder.decode(UsageSnapshotDocument.self, from: data) {
                guard document.formatVersion == UsageSnapshotDocument.currentFormatVersion else {
                    return SnapshotLoadResult(
                        snapshots: [],
                        warning: "Stored snapshots use an unsupported format version. The original file will be backed up before replacement."
                    )
                }
                return SnapshotLoadResult(snapshots: document.snapshots)
            }

            return SnapshotLoadResult(
                snapshots: [],
                warning: "Stored snapshots could not be loaded. The original file will be backed up before replacement."
            )
        } catch {
            return SnapshotLoadResult(
                snapshots: [],
                warning: "Stored snapshots could not be loaded. The original file will be backed up before replacement."
            )
        }
    }

    public func save(_ snapshots: [UsageSnapshot]) throws {
        try preserveUnsupportedDocumentIfNeeded()
        let document = UsageSnapshotDocument(snapshots: snapshots)
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func preserveUnsupportedDocumentIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let existingData = try Data(contentsOf: fileURL)
        if let document = try? decoder.decode(UsageSnapshotDocument.self, from: existingData),
           document.formatVersion == UsageSnapshotDocument.currentFormatVersion {
            return
        }

        try FileManager.default.copyItem(at: fileURL, to: nextBackupURL())
    }

    private func nextBackupURL() -> URL {
        let baseURL = fileURL.appendingPathExtension("backup")
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return baseURL
        }

        var index = 2
        while true {
            let candidate = fileURL.appendingPathExtension("backup-\(index)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
