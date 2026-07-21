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
    let displayPercent: Double
    let displayText: String
    let accessibilityLabel: String
    let toggleHelp: String
    let toggleAccessibilityHint: String
    let resetText: String?

    var accessibilityValue: String {
        displayText
    }

    init?(window: UsageLimitWindow, mode: UsageDisplayMode, now: Date, locale: Locale) {
        guard let usedPercent = window.usedPercent else { return nil }

        id = window.id
        displayName = window.displayName
        let clampedUsedPercent = min(max(usedPercent, 0), 100)
        displayPercent = mode == .used ? clampedUsedPercent : 100 - clampedUsedPercent
        displayText = Self.displayText(for: displayPercent, mode: mode, locale: locale)
        accessibilityLabel = AppStrings.Dashboard.windowUsage.formatted(locale: locale, displayName)
        let nextMode: UsageDisplayMode = mode == .used ? .left : .used
        let nextText = Self.displayText(
            for: nextMode == .used ? clampedUsedPercent : 100 - clampedUsedPercent,
            mode: nextMode,
            locale: locale
        )
        toggleHelp = AppStrings.Dashboard.meterToggleHelp.formatted(
            locale: locale,
            displayName,
            displayText,
            nextText
        )
        toggleAccessibilityHint = AppStrings.Dashboard.meterToggleHint.localized(locale: locale)
        resetText = Self.resetText(for: window.resetAt, now: now, locale: locale)
    }

    private static func displayText(for percent: Double, mode: UsageDisplayMode, locale: Locale) -> String {
        let formattedPercent = AppFormatters.percentage(percent, locale: locale)
        return switch mode {
        case .used:
            AppStrings.Dashboard.used.formatted(locale: locale, formattedPercent)
        case .left:
            AppStrings.Dashboard.left.formatted(locale: locale, formattedPercent)
        }
    }

    private static func resetText(for resetAt: Date?, now: Date, locale: Locale) -> String? {
        guard let resetAt else { return nil }

        let relativeText = AppFormatters.relativeDate(resetAt, relativeTo: now, locale: locale)
        return resetAt >= now
            ? AppStrings.Dashboard.resets.formatted(locale: locale, relativeText)
            : AppStrings.Dashboard.reset.formatted(locale: locale, relativeText)
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
        displayModeForWindow: (UsageLimitWindow) -> UsageDisplayMode = { _ in .used },
        now: Date = Date(),
        locale: Locale = Locale(identifier: "en_US")
    ) {
        accountName = row.account.displayName
        isRefreshing = row.refreshStatus == .refreshing
        canRefresh = row.account.isEnabled && !isGlobalRefresh && !isRefreshing
        refreshHelp = Self.refreshHelp(
            accountName: row.account.displayName,
            isEnabled: row.account.isEnabled,
            isGlobalRefresh: isGlobalRefresh,
            isRefreshing: isRefreshing,
            locale: locale
        )

        let snapshot = row.snapshot
        let resolvedState = Self.state(for: row, isStale: isStale)
        let visibleWindows = snapshot?.displayLimitWindows.compactMap {
            DashboardLimitWindowPresentation(
                window: $0,
                mode: displayModeForWindow($0),
                now: now,
                locale: locale
            )
        } ?? []
        state = resolvedState
        windows = switch resolvedState {
        case .manual, .unavailable, .noData:
            []
        case .normal, .refreshing, .stale, .failed, .warning:
            visibleWindows
        }
        statusText = Self.statusText(
            for: resolvedState,
            limitWindows: snapshot?.displayLimitWindows ?? [],
            locale: locale
        )
        bodyMessage = Self.bodyMessage(
            for: resolvedState,
            snapshot: snapshot,
            hasVisibleWindows: !windows.isEmpty,
            locale: locale
        )
    }

    private static func state(for row: AccountSnapshotRow, isStale: Bool) -> DashboardAccountState {
        if row.refreshIssue != nil || row.snapshot?.status == .error {
            return .failed
        }
        if (row.account.sourceMode == .manual && row.account.providerID != "mock") ||
            row.snapshot?.confidence == .manual {
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

    private static func statusText(
        for state: DashboardAccountState,
        limitWindows: [UsageLimitWindow],
        locale: Locale
    ) -> String? {
        switch state {
        case .failed:
            AppStrings.Dashboard.refreshFailed.localized(locale: locale)
        case .stale:
            AppStrings.Common.stale.localized(locale: locale)
        case .warning:
            limitWindows.contains { ($0.usedPercent ?? 0) >= 85 }
                ? nil
                : AppStrings.Common.warning.localized(locale: locale)
        case .normal, .refreshing, .manual, .unavailable, .noData:
            nil
        }
    }

    private static func bodyMessage(
        for state: DashboardAccountState,
        snapshot: UsageSnapshot?,
        hasVisibleWindows: Bool,
        locale: Locale
    ) -> String? {
        switch state {
        case .manual:
            AppStrings.Dashboard.manualSource.localized(locale: locale)
        case .unavailable:
            snapshot?.remainingLabel ?? AppStrings.Common.usageUnavailable.localized(locale: locale)
        case .noData:
            AppStrings.Dashboard.noData.localized(locale: locale)
        case .failed:
            hasVisibleWindows
                ? nil
                : snapshot?.remainingLabel ?? AppStrings.Dashboard.refreshFailedFallback.localized(locale: locale)
        case .normal, .refreshing, .stale, .warning:
            hasVisibleWindows
                ? nil
                : snapshot?.remainingLabel ?? AppStrings.Common.usageUnavailable.localized(locale: locale)
        }
    }

    private static func refreshHelp(
        accountName: String,
        isEnabled: Bool,
        isGlobalRefresh: Bool,
        isRefreshing: Bool,
        locale: Locale
    ) -> String {
        if !isEnabled {
            return AppStrings.Dashboard.accountDisabled.formatted(locale: locale, accountName)
        }
        if isGlobalRefresh {
            return AppStrings.MenuBar.refreshingAllAccounts.localized(locale: locale)
        }
        if isRefreshing {
            return AppStrings.Dashboard.refreshingAccount.formatted(locale: locale, accountName)
        }
        return AppStrings.Dashboard.refreshAccount.formatted(locale: locale, accountName)
    }
}
