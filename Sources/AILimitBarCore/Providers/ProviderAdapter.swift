import Foundation

public struct ProviderAdapterError: Error, LocalizedError, Equatable, Sendable {
    public let providerID: String
    public let message: String
    public let recoverySuggestion: String?

    public var errorDescription: String? { message }

    public init(providerID: String, message: String, recoverySuggestion: String? = nil) {
        self.providerID = providerID
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}

public protocol ProviderAdapter: Sendable {
    var id: String { get }
    var displayName: String { get }
    var defaultEnabled: Bool { get }
    var usageURL: URL? { get }

    func fetchSnapshot() async throws -> UsageSnapshot
}
