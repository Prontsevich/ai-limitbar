import Foundation

public enum UsageStatus: String, Codable, CaseIterable, Sendable {
    case ok
    case warning
    case error
    case unavailable

    public var displayName: String {
        switch self {
        case .ok: "OK"
        case .warning: "Warning"
        case .error: "Error"
        case .unavailable: "Unavailable"
        }
    }
}

public enum ConfidenceLevel: String, Codable, CaseIterable, Sendable {
    case live
    case delayed
    case localEstimate = "local-estimate"
    case manual
    case unknown

    public var displayName: String {
        switch self {
        case .live: "Live"
        case .delayed: "Delayed"
        case .localEstimate: "Local estimate"
        case .manual: "Manual"
        case .unknown: "Unknown"
        }
    }
}

public struct UsageSnapshot: Codable, Identifiable, Equatable, Sendable {
    public var id: String { providerID }

    public let providerID: String
    public let displayName: String
    public let status: UsageStatus
    public let planName: String?
    public let periodLabel: String?
    public let usedPercent: Double?
    public let remainingLabel: String?
    public let resetAt: Date?
    public let lastUpdatedAt: Date
    public let confidence: ConfidenceLevel
    public let source: String
    public let warnings: [String]

    public init(
        providerID: String,
        displayName: String,
        status: UsageStatus,
        planName: String? = nil,
        periodLabel: String? = nil,
        usedPercent: Double? = nil,
        remainingLabel: String? = nil,
        resetAt: Date? = nil,
        lastUpdatedAt: Date,
        confidence: ConfidenceLevel,
        source: String,
        warnings: [String] = []
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.status = status
        self.planName = planName
        self.periodLabel = periodLabel
        self.usedPercent = usedPercent
        self.remainingLabel = remainingLabel
        self.resetAt = resetAt
        self.lastUpdatedAt = lastUpdatedAt
        self.confidence = confidence
        self.source = source
        self.warnings = warnings
    }
}
