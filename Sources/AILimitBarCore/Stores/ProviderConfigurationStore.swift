import Foundation

public final class ProviderConfigurationStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, filename: String = "providers.json") {
        self.fileURL = directory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func load(defaults: [ProviderConfiguration]) -> SnapshotLoadResultWithConfigurations {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return SnapshotLoadResultWithConfigurations(configurations: defaults)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try decoder.decode([ProviderConfiguration].self, from: data)
            let merged = merge(stored: stored, defaults: defaults)
            return SnapshotLoadResultWithConfigurations(configurations: merged)
        } catch {
            return SnapshotLoadResultWithConfigurations(
                configurations: defaults,
                warning: "Provider settings could not be loaded and defaults were used."
            )
        }
    }

    public func save(_ configurations: [ProviderConfiguration]) throws {
        let data = try encoder.encode(configurations)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func merge(
        stored: [ProviderConfiguration],
        defaults: [ProviderConfiguration]
    ) -> [ProviderConfiguration] {
        let storedByID = Dictionary(uniqueKeysWithValues: stored.map { ($0.providerID, $0) })
        return defaults.map { storedByID[$0.providerID] ?? $0 }
    }
}

public struct SnapshotLoadResultWithConfigurations: Sendable {
    public let configurations: [ProviderConfiguration]
    public let warning: String?

    public init(configurations: [ProviderConfiguration], warning: String? = nil) {
        self.configurations = configurations
        self.warning = warning
    }
}
