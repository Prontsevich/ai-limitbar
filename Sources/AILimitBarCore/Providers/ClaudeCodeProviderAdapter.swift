import Foundation

public struct ClaudeCodeProviderAdapter: ProviderAdapter {
    public let id = "claude-code"
    public let displayName = "Claude Code"
    public let defaultEnabled = false
    public let usageURL: URL? = URL(string: "https://claude.ai/settings/usage")

    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchSnapshot(configuration: ProviderConfiguration) async throws -> UsageSnapshot {
        switch configuration.sourceMode {
        case .manual:
            return manualSnapshot()
        case .localSnapshot:
            return try localSnapshot(configuration: configuration)
        }
    }

    private func manualSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            providerID: id,
            displayName: displayName,
            status: .unavailable,
            remainingLabel: "Open provider usage page",
            lastUpdatedAt: Date(),
            confidence: .manual,
            source: "Claude account usage page",
            warnings: ["No verified machine-readable usage source is configured yet."]
        )
    }

    private func localSnapshot(configuration: ProviderConfiguration) throws -> UsageSnapshot {
        guard let path = configuration.localSnapshotPath, !path.isEmpty else {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot path is not configured.",
                recoverySuggestion: "Select a JSON snapshot file in Settings."
            )
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)

        do {
            let data = try Data(contentsOf: fileURL)
            let payload = try decoder.decode(ClaudeCodeLocalSnapshot.self, from: data)
            try validate(payload)
            return makeUsageSnapshot(from: payload)
        } catch let error as ProviderAdapterError {
            throw error
        } catch {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot could not be loaded.",
                recoverySuggestion: "Verify the configured JSON file exists and matches the AI Limitbar snapshot schema."
            )
        }
    }

    private func validate(_ payload: ClaudeCodeLocalSnapshot) throws {
        guard payload.schemaVersion == 1 else {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot schema version is unsupported.",
                recoverySuggestion: "Use schemaVersion 1 for Claude Code local snapshots."
            )
        }

        if let usedPercent = payload.usedPercent, !(0...100).contains(usedPercent) {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot usedPercent must be between 0 and 100.",
                recoverySuggestion: "Write usedPercent as a numeric percentage from 0 through 100."
            )
        }
    }

    private func makeUsageSnapshot(from payload: ClaudeCodeLocalSnapshot) -> UsageSnapshot {
        let usedPercent = payload.usedPercent
        let status: UsageStatus
        if let usedPercent, usedPercent >= 85 {
            status = .warning
        } else if usedPercent != nil || payload.remainingLabel != nil {
            status = .ok
        } else {
            status = .unavailable
        }

        return UsageSnapshot(
            providerID: id,
            displayName: displayName,
            status: status,
            planName: payload.planName,
            periodLabel: payload.periodLabel,
            usedPercent: usedPercent,
            remainingLabel: payload.remainingLabel,
            resetAt: payload.resetAt,
            lastUpdatedAt: payload.lastUpdatedAt,
            confidence: .localEstimate,
            source: "Claude Code local snapshot file",
            warnings: ["Local estimate only; usage from other machines or Claude surfaces may be missing."]
        )
    }
}

public struct ClaudeCodeLocalSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let planName: String?
    public let periodLabel: String?
    public let usedPercent: Double?
    public let remainingLabel: String?
    public let resetAt: Date?
    public let lastUpdatedAt: Date

    public init(
        schemaVersion: Int,
        planName: String? = nil,
        periodLabel: String? = nil,
        usedPercent: Double? = nil,
        remainingLabel: String? = nil,
        resetAt: Date? = nil,
        lastUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.planName = planName
        self.periodLabel = periodLabel
        self.usedPercent = usedPercent
        self.remainingLabel = remainingLabel
        self.resetAt = resetAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}
