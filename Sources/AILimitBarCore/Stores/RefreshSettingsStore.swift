import Foundation

public struct RefreshSettingsLoadResult: Sendable {
    public let settings: RefreshSettings
    public let warning: String?

    public init(settings: RefreshSettings, warning: String? = nil) {
        self.settings = settings
        self.warning = warning
    }
}

public final class RefreshSettingsStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, filename: String = "refresh-settings.json") {
        self.fileURL = directory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func load(defaults: RefreshSettings = RefreshSettings()) -> RefreshSettingsLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return RefreshSettingsLoadResult(settings: defaults)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let settings = try decoder.decode(RefreshSettings.self, from: data)
            return RefreshSettingsLoadResult(settings: settings)
        } catch {
            return RefreshSettingsLoadResult(
                settings: defaults,
                warning: "Refresh settings could not be loaded and defaults were used."
            )
        }
    }

    public func save(_ settings: RefreshSettings) throws {
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: [.atomic])
    }
}
