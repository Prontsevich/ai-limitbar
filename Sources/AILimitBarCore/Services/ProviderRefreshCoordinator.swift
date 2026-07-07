import Foundation

public struct ProviderRefreshRequest: Sendable {
    public let adapter: any ProviderAdapter
    public let configuration: ProviderConfiguration

    public init(adapter: any ProviderAdapter, configuration: ProviderConfiguration) {
        self.adapter = adapter
        self.configuration = configuration
    }
}

public struct ProviderRetryPolicy: Equatable, Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let backoffMultiplier: Double

    public init(maxAttempts: Int = 2, initialDelay: TimeInterval = 2, backoffMultiplier: Double = 2) {
        self.maxAttempts = max(1, maxAttempts)
        self.initialDelay = max(0, initialDelay)
        self.backoffMultiplier = max(1, backoffMultiplier)
    }
}

public struct ProviderRefreshCoordinator: Sendable {
    private let retryPolicy: ProviderRetryPolicy

    public init(retryPolicy: ProviderRetryPolicy = ProviderRetryPolicy()) {
        self.retryPolicy = retryPolicy
    }

    public func refresh(_ requests: [ProviderRefreshRequest]) async -> [UsageSnapshot] {
        var snapshots: [UsageSnapshot] = []

        for request in requests {
            let snapshot = await refresh(request)
            snapshots.append(snapshot)
        }

        return snapshots
    }

    private func refresh(_ request: ProviderRefreshRequest) async -> UsageSnapshot {
        var attempt = 1
        var delay = retryPolicy.initialDelay

        while true {
            do {
                return try await request.adapter.fetchSnapshot(configuration: request.configuration)
            } catch {
                guard shouldRetry(error, attempt: attempt) else {
                    return errorSnapshot(
                        providerID: request.adapter.id,
                        displayName: request.adapter.displayName,
                        error: error
                    )
                }

                await sleep(for: delay)
                attempt += 1
                delay *= retryPolicy.backoffMultiplier
            }
        }
    }

    private func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt < retryPolicy.maxAttempts else { return false }
        return (error as? ProviderAdapterError)?.isTransient == true
    }

    private func sleep(for delay: TimeInterval) async {
        guard delay > 0 else { return }
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    public func errorSnapshot(providerID: String, displayName: String, error: Error) -> UsageSnapshot {
        var warnings = [error.localizedDescription]
        if let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion {
            warnings.append(recoverySuggestion)
        }

        if (error as? ProviderAdapterError)?.isTransient == true {
            warnings.append(
                "Transient failure persisted after \(retryPolicy.maxAttempts) refresh attempts."
            )
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
