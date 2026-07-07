import Foundation

public struct ProviderRefreshRequest: Sendable {
    public let adapter: any ProviderAdapter
    public let configuration: ProviderConfiguration

    public init(adapter: any ProviderAdapter, configuration: ProviderConfiguration) {
        self.adapter = adapter
        self.configuration = configuration
    }
}

public struct ProviderRefreshCoordinator: Sendable {
    public init() {}

    public func refresh(_ requests: [ProviderRefreshRequest]) async -> [UsageSnapshot] {
        var snapshots: [UsageSnapshot] = []

        for request in requests {
            do {
                let snapshot = try await request.adapter.fetchSnapshot(configuration: request.configuration)
                snapshots.append(snapshot)
            } catch {
                snapshots.append(
                    errorSnapshot(
                        providerID: request.adapter.id,
                        displayName: request.adapter.displayName,
                        error: error
                    )
                )
            }
        }

        return snapshots
    }

    public func errorSnapshot(providerID: String, displayName: String, error: Error) -> UsageSnapshot {
        var warnings = [error.localizedDescription]
        if let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion {
            warnings.append(recoverySuggestion)
        }

        return UsageSnapshot(
            providerID: providerID,
            displayName: displayName,
            status: .error,
            remainingLabel: "Refresh failed",
            lastUpdatedAt: Date(),
            confidence: .unknown,
            source: "Provider adapter error",
            warnings: warnings
        )
    }
}
