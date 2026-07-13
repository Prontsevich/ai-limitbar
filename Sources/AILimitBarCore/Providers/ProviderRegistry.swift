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
        codexAppServerClient: any CodexAppServerClient = ProcessCodexAppServerClient()
    ) {
        self.init(
            adapters: Self.adapters(
                ollamaWebPageClient: ollamaWebPageClient,
                codexAppServerClient: codexAppServerClient
            )
        )
    }

    public static let defaultAdapters: [any ProviderAdapter] =
        adapters(
            ollamaWebPageClient: UnavailableOllamaWebPageClient(),
            codexAppServerClient: ProcessCodexAppServerClient()
        )

    private static func adapters(
        ollamaWebPageClient: any OllamaWebPageClient,
        codexAppServerClient: any CodexAppServerClient
    ) -> [any ProviderAdapter] {
        [
            MockProviderAdapter(),
            CodexAppServerProviderAdapter(client: codexAppServerClient),
            ClaudeCodeProviderAdapter(),
            OllamaCloudProviderAdapter(client: ollamaWebPageClient)
        ]
    }
}
