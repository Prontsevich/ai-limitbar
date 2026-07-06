import Foundation

public struct MockProviderAdapter: ProviderAdapter {
    public let id = "mock"
    public let displayName = "Mock Provider"
    public let defaultEnabled = true
    public let usageURL: URL? = nil

    public init() {}

    public func fetchSnapshot() async throws -> UsageSnapshot {
        let now = Date()
        let minute = Calendar.current.component(.minute, from: now)
        let second = Calendar.current.component(.second, from: now)
        let usedPercent = Double((minute * 60 + second) % 100)
        let remainingPercent = max(0, 100 - Int(usedPercent.rounded()))

        return UsageSnapshot(
            providerID: id,
            displayName: displayName,
            status: usedPercent >= 85 ? .warning : .ok,
            planName: "Development",
            periodLabel: "Rolling mock window",
            usedPercent: usedPercent,
            remainingLabel: "Approx. \(remainingPercent)% remaining",
            resetAt: Calendar.current.date(byAdding: .hour, value: 1, to: now),
            lastUpdatedAt: now,
            confidence: .localEstimate,
            source: "Generated mock data",
            warnings: usedPercent >= 85 ? ["Mock usage is close to the limit."] : []
        )
    }
}
