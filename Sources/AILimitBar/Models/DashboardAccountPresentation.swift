import AILimitBarCore
import Foundation

enum DashboardAccountState: Equatable {
    case normal
    case refreshing
    case stale
    case failed
    case warning
    case manual
    case unavailable
    case noData
}

struct DashboardLimitWindowPresentation: Identifiable, Equatable {
    let id: String
    let displayName: String
    let usedPercent: Double
    let usedText: String
    let resetText: String?

    var accessibilityLabel: String {
        "\(displayName) usage"
    }

    var accessibilityValue: String {
        usedText
    }

    init?(window: UsageLimitWindow, now: Date) {
        guard let usedPercent = window.usedPercent else { return nil }

        id = window.id
        displayName = window.displayName
        self.usedPercent = usedPercent
        usedText = "\(Int(usedPercent.rounded()))% used"
        resetText = Self.resetText(for: window.resetAt, now: now)
    }

    private static func resetText(for resetAt: Date?, now: Date) -> String? {
        guard let resetAt else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .full
        let relativeText = formatter.localizedString(for: resetAt, relativeTo: now)
        return resetAt >= now ? "resets \(relativeText)" : "reset \(relativeText)"
    }
}

struct DashboardAccountPresentation: Equatable {
    let accountName: String
    let state: DashboardAccountState
    let windows: [DashboardLimitWindowPresentation]
    let bodyMessage: String?
    let statusText: String?
    let canRefresh: Bool
    let refreshHelp: String
    let isRefreshing: Bool

    init(
        row: AccountSnapshotRow,
        isStale: Bool,
        isGlobalRefresh: Bool,
        now: Date = Date()
    ) {
        accountName = row.account.displayName
        isRefreshing = row.refreshStatus == .refreshing
        canRefresh = row.account.isEnabled && !isGlobalRefresh && !isRefreshing
        refreshHelp = Self.refreshHelp(
            accountName: row.account.displayName,
            isEnabled: row.account.isEnabled,
            isGlobalRefresh: isGlobalRefresh,
            isRefreshing: isRefreshing
        )

        let snapshot = row.snapshot
        let resolvedState = Self.state(for: row, isStale: isStale)
        let visibleWindows = snapshot?.displayLimitWindows.compactMap {
            DashboardLimitWindowPresentation(window: $0, now: now)
        } ?? []
        state = resolvedState
        windows = switch resolvedState {
        case .manual, .unavailable, .noData:
            []
        case .normal, .refreshing, .stale, .failed, .warning:
            visibleWindows
        }
        statusText = Self.statusText(for: resolvedState)
        bodyMessage = Self.bodyMessage(
            for: resolvedState,
            snapshot: snapshot,
            hasVisibleWindows: !windows.isEmpty
        )
    }

    private static func state(for row: AccountSnapshotRow, isStale: Bool) -> DashboardAccountState {
        if row.refreshIssue != nil || row.snapshot?.status == .error {
            return .failed
        }
        if row.account.sourceMode == .manual || row.snapshot?.confidence == .manual {
            return .manual
        }
        if row.snapshot?.status == .unavailable {
            return .unavailable
        }
        if row.snapshot == nil {
            return .noData
        }
        if isStale {
            return .stale
        }
        if row.snapshot?.status == .warning || hasActionableWarnings(for: row) {
            return .warning
        }
        if row.refreshStatus == .refreshing {
            return .refreshing
        }
        return .normal
    }

    private static func hasActionableWarnings(for row: AccountSnapshotRow) -> Bool {
        guard let snapshot = row.snapshot, !snapshot.warnings.isEmpty else {
            return false
        }
        return !(row.account.sourceMode.isExperimental && snapshot.status == .ok)
    }

    private static func statusText(for state: DashboardAccountState) -> String? {
        switch state {
        case .failed:
            "Refresh failed"
        case .stale:
            "Stale"
        case .warning:
            "Warning"
        case .normal, .refreshing, .manual, .unavailable, .noData:
            nil
        }
    }

    private static func bodyMessage(
        for state: DashboardAccountState,
        snapshot: UsageSnapshot?,
        hasVisibleWindows: Bool
    ) -> String? {
        switch state {
        case .manual:
            "Manual source — open provider usage"
        case .unavailable:
            snapshot?.remainingLabel ?? "Usage unavailable"
        case .noData:
            "No usage data"
        case .failed:
            hasVisibleWindows ? nil : snapshot?.remainingLabel ?? "Refresh failed"
        case .normal, .refreshing, .stale, .warning:
            hasVisibleWindows ? nil : snapshot?.remainingLabel ?? "Usage unavailable"
        }
    }

    private static func refreshHelp(
        accountName: String,
        isEnabled: Bool,
        isGlobalRefresh: Bool,
        isRefreshing: Bool
    ) -> String {
        if !isEnabled {
            return "\(accountName) is disabled."
        }
        if isGlobalRefresh {
            return "Refreshing all accounts."
        }
        if isRefreshing {
            return "Refreshing \(accountName)."
        }
        return "Refresh \(accountName)"
    }
}
