import Foundation

public enum RefreshInterval: String, Codable, CaseIterable, Identifiable, Sendable {
    case manualOnly = "manual-only"
    case fifteenMinutes = "15-minutes"
    case thirtyMinutes = "30-minutes"
    case oneHour = "1-hour"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .manualOnly: "Manual only"
        case .fifteenMinutes: "15 min"
        case .thirtyMinutes: "30 min"
        case .oneHour: "1 hr"
        }
    }

    public var timeInterval: TimeInterval? {
        switch self {
        case .manualOnly: nil
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        }
    }
}

public struct RefreshSettings: Codable, Equatable, Sendable {
    public var interval: RefreshInterval

    public init(interval: RefreshInterval = .manualOnly) {
        self.interval = interval
    }
}
