import Foundation

public enum ClaudeCodeStatusLineError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput
    case noRateLimitData
    case invalidPercentage(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Claude Code status line input is not valid JSON."
        case .noRateLimitData:
            return "Claude Code status line did not include subscription rate limits."
        case let .invalidPercentage(window):
            return "Claude Code status line \(window) used percentage must be between 0 and 100."
        }
    }
}

public struct ClaudeCodeStatusLinePaths: Sendable {
    public static let directoryName = "Claude Code"
    public static let snapshotFileName = "statusline.json"
    public static let helperFileName = "AILimitBarClaudeStatusLine"

    public static func snapshotURL(
        directoryResolver: ApplicationSupportDirectoryResolver = ApplicationSupportDirectoryResolver()
    ) throws -> URL {
        try directoryResolver
            .resolve()
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(snapshotFileName)
    }

    public static func helperURL(
        directoryResolver: ApplicationSupportDirectoryResolver = ApplicationSupportDirectoryResolver()
    ) throws -> URL {
        try directoryResolver
            .resolve()
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(helperFileName)
    }
}

public struct ClaudeCodeStatusLineSnapshotWriter: Sendable {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init() {
        let decoder = JSONDecoder()
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func makeSnapshot(from data: Data, now: Date = Date()) throws -> ClaudeCodeLocalSnapshot {
        let input: ClaudeCodeStatusLineInput
        do {
            input = try decoder.decode(ClaudeCodeStatusLineInput.self, from: data)
        } catch {
            throw ClaudeCodeStatusLineError.invalidInput
        }

        let windows = try input.rateLimits?.windows ?? []
        guard !windows.isEmpty else {
            throw ClaudeCodeStatusLineError.noRateLimitData
        }

        let highestUsedPercent = windows.compactMap(\.usedPercent).max()
        return ClaudeCodeLocalSnapshot(
            schemaVersion: 1,
            periodLabel: "Claude Code rate limits",
            usedPercent: highestUsedPercent,
            limitWindows: windows,
            lastUpdatedAt: now
        )
    }

    @discardableResult
    public func writeSnapshot(
        from data: Data,
        to url: URL,
        now: Date = Date()
    ) throws -> ClaudeCodeLocalSnapshot {
        let snapshot = try makeSnapshot(from: data, now: now)
        let encoded = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded.write(to: url, options: .atomic)
        return snapshot
    }
}

private struct ClaudeCodeStatusLineInput: Decodable, Sendable {
    let rateLimits: RateLimits?

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

private struct RateLimits: Decodable, Sendable {
    let fiveHour: RateLimitWindowInput?
    let sevenDay: RateLimitWindowInput?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    var windows: [UsageLimitWindow] {
        get throws {
            var result: [UsageLimitWindow] = []
            if let fiveHour {
                if let window = try fiveHour.usageWindow(id: "rolling-5-hour", displayName: "5-hour") {
                    result.append(window)
                }
            }
            if let sevenDay {
                if let window = try sevenDay.usageWindow(id: "seven-day", displayName: "7-day") {
                    result.append(window)
                }
            }
            return result
        }
    }
}

private struct RateLimitWindowInput: Decodable, Sendable {
    let usedPercent: Double?
    let resetsAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percentage"
        case resetsAt = "resets_at"
    }

    func usageWindow(id: String, displayName: String) throws -> UsageLimitWindow? {
        guard let usedPercent else { return nil }
        guard usedPercent.isFinite, (0...100).contains(usedPercent) else {
            throw ClaudeCodeStatusLineError.invalidPercentage(displayName)
        }

        let remainingPercent = max(0, min(100, 100 - usedPercent))
        return UsageLimitWindow(
            id: id,
            displayName: displayName,
            usedPercent: usedPercent,
            remainingLabel: "Approx. \(Int(remainingPercent.rounded()))% remaining",
            resetAt: resetsAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
