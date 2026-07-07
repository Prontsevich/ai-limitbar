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

    public func load(knownProviderIDs: Set<String>) -> ProviderAccountLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ProviderAccountLoadResult(accounts: [])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try decoder.decode([ProviderAccount].self, from: data)
            let knownAccounts = stored.filter { knownProviderIDs.contains($0.providerID) }
            return ProviderAccountLoadResult(accounts: deduplicate(knownAccounts))
        } catch {
            return ProviderAccountLoadResult(
                accounts: [],
                warning: "Provider account settings could not be loaded."
            )
        }
    }

    public func save(_ accounts: [ProviderAccount]) throws {
        let data = try encoder.encode(accounts)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func deduplicate(_ accounts: [ProviderAccount]) -> [ProviderAccount] {
        var seen = Set<String>()
        var unique: [ProviderAccount] = []

        for account in accounts {
            guard !seen.contains(account.accountID) else { continue }
            seen.insert(account.accountID)
            unique.append(account)
        }

        return unique
    }
}

public struct ProviderAccountLoadResult: Sendable {
    public let accounts: [ProviderAccount]
    public let warning: String?

    public init(accounts: [ProviderAccount], warning: String? = nil) {
        self.accounts = accounts
        self.warning = warning
    }
}
