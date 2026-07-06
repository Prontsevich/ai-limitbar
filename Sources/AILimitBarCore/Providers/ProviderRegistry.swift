import Foundation

public struct ProviderRegistry: Sendable {
    public let adapters: [any ProviderAdapter]

    public init(adapters: [any ProviderAdapter] = ProviderRegistry.defaultAdapters) {
        self.adapters = adapters
    }

    public var adaptersByID: [String: any ProviderAdapter] {
        Dictionary(uniqueKeysWithValues: adapters.map { ($0.id, $0) })
    }

    public static let defaultAdapters: [any ProviderAdapter] = [
        MockProviderAdapter(),
        ManualProviderAdapter(
            id: "openai-codex",
            displayName: "OpenAI Codex",
            usageURL: URL(string: "https://chatgpt.com/codex"),
            sourceDescription: "OpenAI Codex product surfaces"
        ),
        ClaudeCodeProviderAdapter(),
        ManualProviderAdapter(
            id: "ollama-cloud",
            displayName: "Ollama Cloud",
            usageURL: URL(string: "https://ollama.com/settings"),
            sourceDescription: "Ollama account settings"
        )
    ]
}
