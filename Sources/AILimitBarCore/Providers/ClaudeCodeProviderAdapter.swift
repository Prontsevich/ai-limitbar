import Foundation

public struct ClaudeCodeProviderAdapter: ProviderAdapter {
    public let id = "claude-code"
    public let displayName = "Claude Code"
    public let usageURL: URL? = URL(string: "https://claude.ai/settings/usage")

    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        switch account.sourceMode {
        case .manual:
            return manualSnapshot(account: account)
        case .localSnapshot:
            return try localSnapshot(account: account)
        case .ollamaWebPage:
            return manualSnapshot(account: account)
        }
    }

    private func manualSnapshot(account: ProviderAccount) -> UsageSnapshot {
        UsageSnapshot(
            providerID: id,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: displayName,
            status: .unavailable,
            remainingLabel: "Open provider usage page",
            lastUpdatedAt: Date(),
            confidence: .manual,
            source: "Claude account usage page",
            warnings: ["No verified machine-readable usage source is configured yet."]
        )
    }

    private func localSnapshot(account: ProviderAccount) throws -> UsageSnapshot {
        guard let path = account.localSnapshotPath, !path.isEmpty else {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot path is not configured.",
                recoverySuggestion: "Select a JSON snapshot file in Settings."
            )
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot file was not found.",
                recoverySuggestion: "Run the AI Limitbar statusLine helper or select an existing JSON snapshot file in Settings."
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot file could not be read.",
                recoverySuggestion: "Check that the configured file is readable and is still produced by the statusLine helper."
            )
        }

        let payload: ClaudeCodeLocalSnapshot
        do {
            payload = try decoder.decode(ClaudeCodeLocalSnapshot.self, from: data)
        } catch {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot JSON is invalid.",
                recoverySuggestion: "Verify the file contains schemaVersion 1 and an ISO 8601 lastUpdatedAt value."
            )
        }

        try validate(payload)
        return makeUsageSnapshot(from: payload, account: account)
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

        if let invalidWindow = payload.limitWindows.first(where: { window in
            guard let usedPercent = window.usedPercent else { return false }
            return !(0...100).contains(usedPercent)
        }) {
            throw ProviderAdapterError(
                providerID: id,
                message: "Claude Code local snapshot limit window '\(invalidWindow.displayName)' usedPercent must be between 0 and 100.",
                recoverySuggestion: "Write every limit window usedPercent as a numeric percentage from 0 through 100."
            )
        }
    }

    private func makeUsageSnapshot(from payload: ClaudeCodeLocalSnapshot, account: ProviderAccount) -> UsageSnapshot {
        let usedPercent = payload.usedPercent
        let highestWindowPercent = payload.limitWindows.compactMap(\.usedPercent).max()
        let highestKnownPercent = [usedPercent, highestWindowPercent].compactMap { $0 }.max()
        let status: UsageStatus
        if let highestKnownPercent, highestKnownPercent >= 85 {
            status = .warning
        } else if highestKnownPercent != nil || payload.remainingLabel != nil || !payload.limitWindows.isEmpty {
            status = .ok
        } else {
            status = .unavailable
        }

        return UsageSnapshot(
            providerID: id,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: displayName,
            status: status,
            planName: payload.planName,
            periodLabel: payload.periodLabel,
            usedPercent: usedPercent,
            remainingLabel: payload.remainingLabel,
            resetAt: payload.resetAt,
            limitWindows: payload.limitWindows,
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
    public let limitWindows: [UsageLimitWindow]
    public let lastUpdatedAt: Date

    public init(
        schemaVersion: Int,
        planName: String? = nil,
        periodLabel: String? = nil,
        usedPercent: Double? = nil,
        remainingLabel: String? = nil,
        resetAt: Date? = nil,
        limitWindows: [UsageLimitWindow] = [],
        lastUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.planName = planName
        self.periodLabel = periodLabel
        self.usedPercent = usedPercent
        self.remainingLabel = remainingLabel
        self.resetAt = resetAt
        self.limitWindows = limitWindows
        self.lastUpdatedAt = lastUpdatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        planName = try container.decodeIfPresent(String.self, forKey: .planName)
        periodLabel = try container.decodeIfPresent(String.self, forKey: .periodLabel)
        usedPercent = try container.decodeIfPresent(Double.self, forKey: .usedPercent)
        remainingLabel = try container.decodeIfPresent(String.self, forKey: .remainingLabel)
        resetAt = try container.decodeIfPresent(Date.self, forKey: .resetAt)
        limitWindows = try container.decodeIfPresent([UsageLimitWindow].self, forKey: .limitWindows) ?? []
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
    }
}
