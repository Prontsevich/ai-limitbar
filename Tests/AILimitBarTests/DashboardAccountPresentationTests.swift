import AILimitBarCore
import XCTest
@testable import AILimitBar

final class DashboardAccountPresentationTests: XCTestCase {
    func testUsageWindowFormatsPercentAndRelativeResetWithoutRemainingDuplicate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = makeSnapshot(
            limitWindows: [
                UsageLimitWindow(
                    id: "five-hour",
                    displayName: "5-hour",
                    usedPercent: 41.6,
                    remainingLabel: "Approx. 58% remaining",
                    resetAt: now.addingTimeInterval(7_200)
                )
            ]
        )

        let presentation = DashboardAccountPresentation(
            row: makeRow(snapshot: snapshot),
            isStale: false,
            isGlobalRefresh: false,
            now: now
        )

        XCTAssertEqual(presentation.windows.count, 1)
        XCTAssertEqual(presentation.windows[0].usedText, "41.6% used")
        XCTAssertEqual(presentation.windows[0].resetText, "resets in 2 hours")
        XCTAssertEqual(presentation.windows[0].accessibilityValue, "41.6% used")
        XCTAssertNil(presentation.bodyMessage)
    }

    func testUsageWindowUsesRussianDecimalSeparatorAndLocalizedCopy() {
        let snapshot = makeSnapshot(
            limitWindows: [
                UsageLimitWindow(id: "weekly", displayName: "Weekly", usedPercent: 35.4)
            ]
        )

        let presentation = DashboardAccountPresentation(
            row: makeRow(snapshot: snapshot),
            isStale: false,
            isGlobalRefresh: false,
            locale: Locale(identifier: "ru_RU")
        )

        XCTAssertEqual(presentation.windows[0].displayName, "Weekly")
        XCTAssertTrue(presentation.windows[0].usedText.contains("35,4"))
        XCTAssertTrue(presentation.windows[0].usedText.hasPrefix("Ушло"))
        XCTAssertEqual(presentation.windows[0].accessibilityValue, presentation.windows[0].usedText)
    }

    func testUsageWindowOmitsFractionForWholePercentages() {
        let presentation = DashboardAccountPresentation(
            row: makeRow(snapshot: makeSnapshot()),
            isStale: false,
            isGlobalRefresh: false
        )

        XCTAssertEqual(presentation.windows[0].usedText, "42% used")
    }

    func testManualAndUnavailableAccountsDoNotInventUsageBars() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = makeSnapshot(
            status: .unavailable,
            confidence: .manual,
            limitWindows: [
                UsageLimitWindow(id: "manual", displayName: "Manual", usedPercent: 42)
            ]
        )

        let manual = DashboardAccountPresentation(
            row: makeRow(snapshot: snapshot, sourceMode: .manual),
            isStale: false,
            isGlobalRefresh: false,
            now: now
        )

        XCTAssertEqual(manual.state, .manual)
        XCTAssertTrue(manual.windows.isEmpty)
        XCTAssertEqual(manual.bodyMessage, "Manual source — open provider usage")

        let unavailableSnapshot = makeSnapshot(status: .unavailable, remainingLabel: "Open provider usage page")
        let unavailable = DashboardAccountPresentation(
            row: makeRow(snapshot: unavailableSnapshot, sourceMode: .claudeStatusLine),
            isStale: false,
            isGlobalRefresh: false,
            now: now
        )

        XCTAssertEqual(unavailable.state, .unavailable)
        XCTAssertTrue(unavailable.windows.isEmpty)
        XCTAssertEqual(unavailable.bodyMessage, "Open provider usage page")
    }

    func testMockAccountDisplaysGeneratedUsageDespiteCompatibilityManualSource() {
        let snapshot = UsageSnapshot(
            providerID: "mock",
            accountID: "work",
            accountDisplayName: "Work",
            displayName: "Mock Provider",
            status: .ok,
            limitWindows: [
                UsageLimitWindow(id: "weekly", displayName: "Weekly", usedPercent: 42)
            ],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_000_000),
            confidence: .localEstimate,
            source: "Generated mock data"
        )
        let account = ProviderAccount(
            providerID: "mock",
            accountID: "work",
            displayName: "Work",
            isEnabled: true,
            sourceMode: .manual
        )
        let presentation = DashboardAccountPresentation(
            row: AccountSnapshotRow(
                account: account,
                providerDisplayName: "Mock Provider",
                snapshot: snapshot,
                refreshStatus: .idle,
                refreshIssue: nil
            ),
            isStale: false,
            isGlobalRefresh: false
        )

        XCTAssertEqual(presentation.state, .normal)
        XCTAssertEqual(presentation.windows.count, 1)
        XCTAssertNil(presentation.bodyMessage)
    }

    func testFailedAndStaleStatesKeepLastValidUsageVisible() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = makeSnapshot(limitWindows: [
            UsageLimitWindow(id: "weekly", displayName: "7-day", usedPercent: 24)
        ])

        let stale = DashboardAccountPresentation(
            row: makeRow(snapshot: snapshot),
            isStale: true,
            isGlobalRefresh: false,
            now: now
        )
        XCTAssertEqual(stale.state, .stale)
        XCTAssertEqual(stale.statusText, "Stale")
        XCTAssertEqual(stale.windows.count, 1)

        let failed = DashboardAccountPresentation(
            row: makeRow(
                snapshot: snapshot,
                refreshIssue: AccountRefreshIssue(occurredAt: now, warnings: ["Timed out"])
            ),
            isStale: false,
            isGlobalRefresh: false,
            now: now
        )
        XCTAssertEqual(failed.state, .failed)
        XCTAssertEqual(failed.statusText, "Refresh failed")
        XCTAssertEqual(failed.windows.count, 1)
    }

    func testRefreshAvailabilityMatchesGlobalAndAccountRefreshRules() {
        let row = makeRow(snapshot: makeSnapshot())

        let ready = DashboardAccountPresentation(
            row: row,
            isStale: false,
            isGlobalRefresh: false
        )
        XCTAssertTrue(ready.canRefresh)
        XCTAssertEqual(ready.refreshHelp, "Refresh Work")

        let globalRefresh = DashboardAccountPresentation(
            row: row,
            isStale: false,
            isGlobalRefresh: true
        )
        XCTAssertFalse(globalRefresh.canRefresh)
        XCTAssertEqual(globalRefresh.refreshHelp, "Refreshing all accounts.")

        let accountRefresh = DashboardAccountPresentation(
            row: makeRow(snapshot: makeSnapshot(), refreshStatus: .refreshing),
            isStale: false,
            isGlobalRefresh: false
        )
        XCTAssertFalse(accountRefresh.canRefresh)
        XCTAssertTrue(accountRefresh.isRefreshing)
        XCTAssertEqual(accountRefresh.state, .refreshing)
    }

    func testNoDataAccountHasVisibleStateWithoutUsageValues() {
        let presentation = DashboardAccountPresentation(
            row: makeRow(snapshot: nil),
            isStale: false,
            isGlobalRefresh: false
        )

        XCTAssertEqual(presentation.state, .noData)
        XCTAssertTrue(presentation.windows.isEmpty)
        XCTAssertEqual(presentation.bodyMessage, "No usage data")
    }

    func testExperimentalCompatibilityNoteDoesNotCreateWarningState() {
        let experimental = DashboardAccountPresentation(
            row: makeRow(
                snapshot: makeSnapshot(warnings: ["Experimental compatibility note"]),
                sourceMode: .ollamaWebPage
            ),
            isStale: false,
            isGlobalRefresh: false
        )

        XCTAssertEqual(experimental.state, .normal)
        XCTAssertNil(experimental.statusText)

        let realUsageWarning = DashboardAccountPresentation(
            row: makeRow(
                snapshot: makeSnapshot(
                    status: .warning,
                    warnings: ["Experimental compatibility note"]
                ),
                sourceMode: .ollamaWebPage
            ),
            isStale: false,
            isGlobalRefresh: false
        )

        XCTAssertEqual(realUsageWarning.state, .warning)
        XCTAssertEqual(realUsageWarning.statusText, "Warning")
    }

    func testUsageThresholdDoesNotCreateDashboardStatusText() {
        let presentation = DashboardAccountPresentation(
            row: makeRow(
                snapshot: makeSnapshot(
                    status: .warning,
                    limitWindows: [
                        UsageLimitWindow(id: "five-hour", displayName: "5-hour", usedPercent: 100)
                    ]
                )
            ),
            isStale: false,
            isGlobalRefresh: false
        )

        XCTAssertEqual(presentation.windows.first?.usedText, "100% used")
        XCTAssertNil(presentation.statusText)
    }

    private func makeRow(
        snapshot: UsageSnapshot?,
        providerID: String = "test",
        sourceMode: ProviderSourceMode = .claudeStatusLine,
        refreshStatus: ProviderRefreshStatus = .idle,
        refreshIssue: AccountRefreshIssue? = nil
    ) -> AccountSnapshotRow {
        let account = ProviderAccount(
            providerID: providerID,
            accountID: "work",
            displayName: "Work",
            isEnabled: true,
            sourceMode: sourceMode
        )
        return AccountSnapshotRow(
            account: account,
            providerDisplayName: "Test Provider",
            snapshot: snapshot,
            refreshStatus: refreshStatus,
            refreshIssue: refreshIssue
        )
    }

    private func makeSnapshot(
        status: UsageStatus = .ok,
        confidence: ConfidenceLevel = .live,
        remainingLabel: String? = nil,
        warnings: [String] = [],
        limitWindows: [UsageLimitWindow] = [
            UsageLimitWindow(id: "weekly", displayName: "7-day", usedPercent: 42)
        ]
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerID: "test",
            accountID: "work",
            accountDisplayName: "Work",
            displayName: "Test Provider",
            status: status,
            remainingLabel: remainingLabel,
            limitWindows: limitWindows,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_000_000),
            confidence: confidence,
            source: "Test source",
            warnings: warnings
        )
    }
}
