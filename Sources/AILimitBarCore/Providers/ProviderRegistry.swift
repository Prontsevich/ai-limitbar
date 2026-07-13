import Foundation

public struct ProviderRegistry: Sendable {
    public let adapters: [any ProviderAdapter]

    public init(adapters: [any ProviderAdapter] = ProviderRegistry.defaultAdapters) {
        self.adapters = adapters
    }

    public var adaptersByID: [String: any ProviderAdapter] {
        Dictionary(uniqueKeysWithValues: adapters.map { ($0.id, $0) })
    }

    public init(
        ollamaWebPageClient: any OllamaWebPageClient,
        codexAppServerClient: any CodexAppServerClient = ProcessCodexAppServerClient(),
        claudeSnapshotStore: (any CurrentSnapshotStore)? = nil
    ) {
        self.init(
            adapters: Self.adapters(
                ollamaWebPageClient: ollamaWebPageClient,
                codexAppServerClient: codexAppServerClient,
                claudeSnapshotStore: claudeSnapshotStore
            )
        )
    }

    public static let defaultAdapters: [any ProviderAdapter] =
        adapters(
            ollamaWebPageClient: UnavailableOllamaWebPageClient(),
            codexAppServerClient: ProcessCodexAppServerClient(),
            claudeSnapshotStore: nil
        )

    private static func adapters(
        ollamaWebPageClient: any OllamaWebPageClient,
        codexAppServerClient: any CodexAppServerClient,
        claudeSnapshotStore: (any CurrentSnapshotStore)?
    ) -> [any ProviderAdapter] {
        [
            MockProviderAdapter(),
            CodexAppServerProviderAdapter(client: codexAppServerClient),
            ClaudeCodeProviderAdapter(snapshotStore: claudeSnapshotStore),
            OllamaCloudProviderAdapter(client: ollamaWebPageClient)
        ]
    }
}
