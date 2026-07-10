import Foundation
import OSLog

enum AppTelemetry {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.local.AILimitBar"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let refresh = Logger(subsystem: subsystem, category: "refresh")
    static let storage = Logger(subsystem: subsystem, category: "storage")
}
