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
        claudeUsageCLIClient: any ClaudeUsageCLIClient = ProcessClaudeUsageCLIClient(),
        claudeSnapshotStore: (any CurrentSnapshotStore)? = nil,
        openRouterRefreshCoordinator: any OpenRouterAccountRefreshing =
            UnavailableOpenRouterRefreshCoordinator()
    ) {
        self.init(
            adapters: Self.adapters(
                ollamaWebPageClient: ollamaWebPageClient,
                codexAppServerClient: codexAppServerClient,
                claudeUsageCLIClient: claudeUsageCLIClient,
                claudeSnapshotStore: claudeSnapshotStore,
                openRouterRefreshCoordinator: openRouterRefreshCoordinator
            )
        )
    }

    public static let defaultAdapters: [any ProviderAdapter] =
        adapters(
            ollamaWebPageClient: UnavailableOllamaWebPageClient(),
            codexAppServerClient: ProcessCodexAppServerClient(),
            claudeUsageCLIClient: ProcessClaudeUsageCLIClient(),
            claudeSnapshotStore: nil,
            openRouterRefreshCoordinator: UnavailableOpenRouterRefreshCoordinator()
        )

    private static func adapters(
        ollamaWebPageClient: any OllamaWebPageClient,
        codexAppServerClient: any CodexAppServerClient,
        claudeUsageCLIClient: any ClaudeUsageCLIClient,
        claudeSnapshotStore: (any CurrentSnapshotStore)?,
        openRouterRefreshCoordinator: any OpenRouterAccountRefreshing
    ) -> [any ProviderAdapter] {
        [
            MockProviderAdapter(),
            CodexAppServerProviderAdapter(client: codexAppServerClient),
            ClaudeCodeProviderAdapter(
                snapshotStore: claudeSnapshotStore,
                usageCLIClient: claudeUsageCLIClient
            ),
            OllamaCloudProviderAdapter(client: ollamaWebPageClient),
            OpenRouterProviderAdapter(
                refreshCoordinator: openRouterRefreshCoordinator
            )
        ]
    }
}
