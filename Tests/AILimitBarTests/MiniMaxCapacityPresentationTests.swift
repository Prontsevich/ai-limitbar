import AILimitBarCore
import Foundation
import XCTest
@testable import AILimitBar

final class MiniMaxCapacityPresentationTests: XCTestCase {
    func testReviewedQuotaCategoriesPresentNormalizedCapacityWithoutRawMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = makeAccount()
        let presentation = try XCTUnwrap(
            MiniMaxCapacityPresentation(
                account: account,
                snapshot: makeSnapshot(anchor: now),
                now: now,
                locale: Locale(identifier: "en_US")
            )
        )

        XCTAssertEqual(
            presentation.categories.map(\.displayName),
            [
                "Token Plan quota category A",
                "Token Plan quota category B",
            ]
        )
        XCTAssertEqual(presentation.categories.map(\.windows.count), [2, 2])

        let current = try XCTUnwrap(presentation.categories.first?.windows.first)
        XCTAssertEqual(current.id, "quota-category-a.current")
        XCTAssertEqual(current.displayName, "Current window")
        XCTAssertEqual(current.capacityText, "Used 25 · Remaining 75 · Total 100")
        XCTAssertEqual(current.percentageText, "25% used")
        XCTAssertEqual(current.displayPercent, 25)
        XCTAssertEqual(current.meterPresentation?.displayPercent, 25)
        XCTAssertEqual(current.resetText, "resets in 1 hour")
        XCTAssertTrue(current.accessibilityValue.contains(current.capacityText))
        XCTAssertTrue(current.accessibilityValue.contains("25% used"))

        let visibleText = presentation.categories.flatMap { category in
            [
                category.displayName,
                category.accessibilityIdentifier,
                category.accessibilityValue,
            ] + category.windows.flatMap { window in
                [
                    window.displayName,
                    window.capacityText,
                    window.percentageText ?? "",
                    window.resetText ?? "",
                    window.accessibilityLabel,
                    window.accessibilityValue,
                    window.meterPresentation?.toggleHelp ?? "",
                ]
            }
        }.joined(separator: " ").lowercased()
        XCTAssertFalse(visibleText.contains("general"))
        XCTAssertFalse(visibleText.contains("video"))
        XCTAssertFalse(visibleText.contains("provider metadata marker"))
    }

    func testRussianQuotaCategoryCopyAndLeftModeRemainPrivacySafe() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let presentation = try XCTUnwrap(
            MiniMaxCapacityPresentation(
                account: makeAccount(),
                snapshot: makeSnapshot(anchor: now),
                displayModeForWindow: { _ in .left },
                now: now,
                locale: Locale(identifier: "ru_RU")
            )
        )

        XCTAssertEqual(
            presentation.categories.map(\.displayName),
            [
                "Категория квоты Token Plan A",
                "Категория квоты Token Plan B",
            ]
        )
        let current = try XCTUnwrap(presentation.categories.first?.windows.first)
        XCTAssertEqual(current.displayName, "Текущее окно")
        XCTAssertEqual(
            current.capacityText,
            "Использовано 25 · Осталось 75 · Всего 100"
        )
        XCTAssertTrue(current.percentageText?.contains("75") == true)
        XCTAssertTrue(current.percentageText?.contains("Ещё") == true)
        XCTAssertEqual(current.displayPercent, 25)
        XCTAssertEqual(current.meterPresentation?.displayPercent, 75)
        XCTAssertTrue(current.accessibilityLabel.contains("Категория квоты"))
        XCTAssertFalse(current.accessibilityValue.lowercased().contains("general"))
        XCTAssertFalse(current.accessibilityValue.lowercased().contains("video"))
    }

    func testOnlyReviewedSafeMetricIdentitiesAreProjected() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = makeAccount()
        let context = makeContext()
        let snapshot = CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: MiniMaxProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [context],
            observedAt: now,
            metrics: [
                makeMetric(
                    id: "unreviewed-category.current",
                    contextID: context.contextID,
                    displayName: "general video provider metadata marker",
                    consumed: 99,
                    remaining: 1,
                    limit: 100,
                    resetAt: now.addingTimeInterval(3_600),
                    observedAt: now
                ),
                makeMetric(
                    id: "quota-category-a.current",
                    contextID: context.contextID,
                    sourceID: "unreviewed-source",
                    displayName: "general video provider metadata marker",
                    consumed: 99,
                    remaining: 1,
                    limit: 100,
                    resetAt: now.addingTimeInterval(3_600),
                    observedAt: now
                ),
            ]
        )
        let presentation = try XCTUnwrap(
            MiniMaxCapacityPresentation(
                account: account,
                snapshot: snapshot,
                now: now,
                locale: Locale(identifier: "en_US")
            )
        )

        XCTAssertEqual(presentation.categories.count, 2)
        XCTAssertTrue(
            presentation.categories
                .flatMap(\.windows)
                .allSatisfy { $0.capacityText == "Unavailable" }
        )
        XCTAssertTrue(
            presentation.categories
                .flatMap(\.windows)
                .allSatisfy { $0.meterPresentation == nil }
        )
    }

    func testUnlimitedWindowKeepsSafeResetInformationWithoutMeter() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = makeAccount()
        let context = makeContext()
        let snapshot = CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: MiniMaxProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [context],
            observedAt: now,
            metrics: [
                makeMetric(
                    id: "quota-category-a.current",
                    contextID: context.contextID,
                    displayName: "general provider metadata marker",
                    consumed: 3,
                    remaining: 0,
                    limit: 0,
                    resetAt: now.addingTimeInterval(3_600),
                    observedAt: now,
                    availability: .unlimited
                )
            ]
        )
        let presentation = try XCTUnwrap(
            MiniMaxCapacityPresentation(
                account: account,
                snapshot: snapshot,
                now: now,
                locale: Locale(identifier: "en_US")
            )
        )
        let current = try XCTUnwrap(presentation.categories.first?.windows.first)

        XCTAssertEqual(current.capacityText, "Unlimited")
        XCTAssertNil(current.percentageText)
        XCTAssertNil(current.meterPresentation)
        XCTAssertEqual(current.resetText, "resets in 1 hour")
        XCTAssertTrue(current.accessibilityValue.contains("resets in 1 hour"))
    }

    func testUnavailableSubscriptionStatusIsIncludedAlongsideNativeCapacityRows() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let account = makeAccount()
        let nativeCapacity = try XCTUnwrap(
            MiniMaxCapacityPresentation(
                account: account,
                snapshot: makeSnapshot(anchor: now),
                now: now,
                locale: Locale(identifier: "en_US")
            )
        )
        let issue = AccountRefreshIssue(
            occurredAt: now,
            warnings: [MiniMaxProviderContract.unavailableSubscriptionWarning]
        )
        let row = AccountSnapshotRow(
            account: account,
            providerDisplayName: "MiniMax",
            snapshot: nil,
            refreshStatus: .failed(now),
            refreshIssue: issue
        )
        let dashboardPresentation = DashboardAccountPresentation(
            row: row,
            isStale: false,
            isGlobalRefresh: false,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertFalse(nativeCapacity.categories.isEmpty)
        XCTAssertEqual(
            MiniMaxCapacityRefreshStatusPresentation.text(
                for: row,
                dashboardPresentation: dashboardPresentation
            ),
            "MiniMax Token Plan subscription is unavailable or expired"
        )
        XCTAssertNil(dashboardPresentation.bodyMessage)
    }

    private func makeAccount() -> ProviderAccount {
        ProviderAccount(
            providerID: MiniMaxProviderContract.providerID,
            accountID: "presentation-account",
            displayName: "MiniMax Presentation",
            isEnabled: true,
            sourceMode: .miniMaxTokenPlan
        )
    }

    private func makeContext() -> AccountContext {
        AccountContext(
            contextID: "presentation-team",
            kind: .team,
            displayName: "general video provider metadata marker",
            regionID: "global"
        )
    }

    private func makeSnapshot(anchor: Date) -> CapacitySnapshot {
        let account = makeAccount()
        let context = makeContext()
        return CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: MiniMaxProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [context],
            observedAt: anchor,
            metrics: [
                makeMetric(
                    id: "quota-category-a.current",
                    contextID: context.contextID,
                    displayName: "general provider metadata marker",
                    consumed: 25,
                    remaining: 75,
                    limit: 100,
                    resetAt: anchor.addingTimeInterval(3_600),
                    observedAt: anchor
                ),
                makeMetric(
                    id: "quota-category-a.weekly",
                    contextID: context.contextID,
                    displayName: "general provider weekly marker",
                    consumed: 50,
                    remaining: 150,
                    limit: 200,
                    resetAt: anchor.addingTimeInterval(3 * 24 * 3_600),
                    observedAt: anchor
                ),
                makeMetric(
                    id: "quota-category-b.current",
                    contextID: context.contextID,
                    displayName: "video provider metadata marker",
                    consumed: 2,
                    remaining: 8,
                    limit: 10,
                    resetAt: anchor.addingTimeInterval(2 * 3_600),
                    observedAt: anchor
                ),
                makeMetric(
                    id: "quota-category-b.weekly",
                    contextID: context.contextID,
                    displayName: "video provider weekly marker",
                    consumed: 8,
                    remaining: 32,
                    limit: 40,
                    resetAt: anchor.addingTimeInterval(5 * 24 * 3_600),
                    observedAt: anchor
                ),
            ]
        )
    }

    private func makeMetric(
        id: String,
        contextID: String,
        sourceID: String = MiniMaxProviderContract.sourceID,
        displayName: String,
        consumed: Decimal,
        remaining: Decimal,
        limit: Decimal,
        resetAt: Date,
        observedAt: Date,
        availability: CapacityAvailability = .known
    ) -> CapacityMetric {
        CapacityMetric(
            metricID: id,
            accountContextID: contextID,
            sourceID: sourceID,
            capability: "quota-windows",
            displayName: displayName,
            availability: availability,
            unit: CapacityUnit(
                kind: .providerDefined,
                providerUnitID: MiniMaxProviderContract.providerUnitID
            ),
            values: CapacityValues(
                consumed: CapacityValue(value: consumed, origin: .reported),
                remaining: CapacityValue(value: remaining, origin: .derived),
                limit: CapacityValue(value: limit, origin: .reported)
            ),
            window: CapacityWindow(
                kind: id.hasSuffix(".weekly") ? .fixed : .rolling,
                nextTransition: CapacityTransition(kind: .reset, at: resetAt)
            ),
            freshness: ObservationFreshness(observedAt: observedAt),
            confidence: .live
        )
    }
}
