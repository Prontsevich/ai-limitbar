#if DEBUG
import AILimitBarCore
import Foundation
import XCTest
@testable import AILimitBar

@MainActor
final class OpenRouterSettingsAndPresentationTests: XCTestCase {
    func testSettingsCRUDPreservesAccountsAndRecoversMissingKeychainItem() throws {
        let directory = temporaryDirectory()
        let keychain = SettingsTestKeychain()
        let model = AppModel(
            storageDirectory: directory,
            userDefaults: isolatedDefaults(),
            credentialKeychainService: keychain
        )
        let personal = try XCTUnwrap(
            model.addAccount(
                providerID: OpenRouterProviderContract.providerID,
                displayName: "Personal"
            )
        )
        let work = try XCTUnwrap(
            model.addAccount(
                providerID: OpenRouterProviderContract.providerID,
                displayName: "Work"
            )
        )

        XCTAssertEqual(
            try model.accountCredentialStore.loadContexts(
                providerID: personal.providerID,
                accountID: personal.accountID
            ).filter { $0.parentContextID == nil }.count,
            1
        )

        let personalPrimary = try model.createOpenRouterOrdinaryCredential(
            for: personal,
            displayName: "Primary",
            credentialValue: "synthetic-personal-primary"
        )
        let personalBackup = try model.createOpenRouterOrdinaryCredential(
            for: personal,
            displayName: "Backup",
            credentialValue: "synthetic-personal-backup"
        )
        _ = try model.createOpenRouterOrdinaryCredential(
            for: work,
            displayName: "Primary",
            credentialValue: "synthetic-work-primary"
        )
        _ = try model.createOpenRouterManagementCredential(
            for: personal,
            credentialValue: "synthetic-personal-management"
        )

        XCTAssertEqual(keychain.credentialCount, 4)
        XCTAssertThrowsError(
            try model.createOpenRouterOrdinaryCredential(
                for: personal,
                displayName: "primary",
                credentialValue: "synthetic-duplicate"
            )
        ) {
            XCTAssertEqual($0 as? OpenRouterSettingsError, .duplicateName)
        }
        XCTAssertThrowsError(
            try model.createOpenRouterManagementCredential(
                for: personal,
                credentialValue: "synthetic-duplicate-management"
            )
        ) {
            XCTAssertEqual(
                $0 as? OpenRouterSettingsError,
                .managementCredentialExists
            )
        }

        try model.renameOpenRouterOrdinaryCredential(
            for: personal,
            contextID: personalBackup.context.contextID,
            displayName: "Secondary"
        )
        XCTAssertEqual(
            model.openRouterCredentialContexts(for: personal)
                .first(where: {
                    $0.context.contextID == personalBackup.context.contextID
                })?.context.displayName,
            "Secondary"
        )

        try model.setOpenRouterCredentialEnabled(
            false,
            for: personal,
            slotID: personalPrimary.slot.slotID
        )
        XCTAssertFalse(
            try XCTUnwrap(
                model.openRouterCredentialContexts(for: personal)
                    .first(where: {
                        $0.slot.slotID == personalPrimary.slot.slotID
                    })
            ).slot.isEnabled
        )
        try model.setOpenRouterCredentialEnabled(
            true,
            for: personal,
            slotID: personalPrimary.slot.slotID
        )

        keychain.drop(reference: personalPrimary.slot.keychainReference)
        try model.replaceOpenRouterCredential(
            for: personal,
            slotID: personalPrimary.slot.slotID,
            credentialValue: "synthetic-personal-recovered"
        )
        let recovered = try XCTUnwrap(
            model.openRouterCredentialContexts(for: personal)
                .first(where: {
                    $0.slot.slotID == personalPrimary.slot.slotID
                })
        )
        XCTAssertTrue(keychain.contains(reference: recovered.slot.keychainReference))
        XCTAssertEqual(recovered.slot.credentialRevision, 2)

        try model.deleteOpenRouterCredential(
            for: personal,
            slotID: personalBackup.slot.slotID
        )
        XCTAssertFalse(
            model.openRouterCredentialContexts(for: personal)
                .contains(where: {
                    $0.slot.slotID == personalBackup.slot.slotID
                })
        )
        XCTAssertEqual(keychain.credentialCount, 3)

        let reloaded = AppModel(
            storageDirectory: directory,
            userDefaults: isolatedDefaults(),
            credentialKeychainService: keychain
        )
        XCTAssertEqual(
            Set(
                reloaded.providerAccounts
                    .filter {
                        $0.providerID == OpenRouterProviderContract.providerID
                    }
                    .map(\.displayName)
            ),
            ["Personal", "Work"]
        )
        XCTAssertEqual(
            reloaded.openRouterCredentialContexts(for: personal)
                .filter { $0.slot.role == .ordinary }
                .map(\.context.displayName),
            ["Primary"]
        )

        reloaded.deleteAccount(
            providerID: personal.providerID,
            accountID: personal.accountID
        )
        XCTAssertFalse(reloaded.providerAccounts.contains { $0.id == personal.id })
        XCTAssertEqual(keychain.credentialCount, 1)
    }

    func testManagementDisableImmediatelyMakesSharedCreditsUnavailable() async throws {
        let directory = temporaryDirectory()
        let keychain = SettingsTestKeychain()
        let model = AppModel(
            storageDirectory: directory,
            userDefaults: isolatedDefaults(),
            refreshCoordinator: ProviderRefreshCoordinator(
                retryPolicy: ProviderRetryPolicy(maxAttempts: 1, initialDelay: 0)
            ),
            openRouterAPIClient: SyntheticOpenRouterVerificationClient(
                failingOrdinarySlotID: "never"
            ),
            credentialKeychainService: keychain
        )
        let account = try XCTUnwrap(
            model.addAccount(
                providerID: OpenRouterProviderContract.providerID,
                displayName: "Capacity"
            )
        )
        _ = try model.createOpenRouterOrdinaryCredential(
            for: account,
            displayName: "Primary",
            credentialValue: "synthetic-primary"
        )
        let management = try model.createOpenRouterManagementCredential(
            for: account,
            credentialValue: "synthetic-management"
        )

        model.refreshAccount(
            providerID: account.providerID,
            accountID: account.accountID
        )
        await model.waitForRefreshCompletionForTesting()
        XCTAssertEqual(
            model.openRouterCapacityPresentation(
                for: account,
                locale: Locale(identifier: "en_US")
            )?.sharedCredits.state,
            .current
        )

        try model.setOpenRouterCredentialEnabled(
            false,
            for: account,
            slotID: management.slot.slotID
        )

        let presentation = try XCTUnwrap(
            model.openRouterCapacityPresentation(
                for: account,
                locale: Locale(identifier: "en_US")
            )
        )
        XCTAssertEqual(presentation.sharedCredits.state, .unavailable)
        XCTAssertEqual(presentation.sharedCredits.valueText, "Unavailable")
        XCTAssertEqual(presentation.credentials.count, 1)
        XCTAssertTrue(
            presentation.credentials[0].metrics.contains {
                $0.displayName == "Total usage"
            }
        )
    }

    func testGlobalRefreshRejectsLateFailureAfterCredentialReplaceOrDisable() async throws {
        for disablesCredential in [false, true] {
            let directory = temporaryDirectory()
            let keychain = SettingsTestKeychain()
            let client = BarrierOpenRouterClient()
            let model = AppModel(
                storageDirectory: directory,
                userDefaults: isolatedDefaults(),
                refreshCoordinator: ProviderRefreshCoordinator(
                    retryPolicy: ProviderRetryPolicy(
                        maxAttempts: 1,
                        initialDelay: 0
                    )
                ),
                openRouterAPIClient: client,
                credentialKeychainService: keychain
            )
            let account = try XCTUnwrap(
                model.addAccount(
                    providerID: OpenRouterProviderContract.providerID,
                    displayName: disablesCredential ? "Disable" : "Replace"
                )
            )
            let credential = try model.createOpenRouterOrdinaryCredential(
                for: account,
                displayName: "Primary",
                credentialValue: "synthetic-initial"
            )

            model.refreshAccount(
                providerID: account.providerID,
                accountID: account.accountID
            )
            await model.waitForRefreshCompletionForTesting()
            let successfulSnapshot = try XCTUnwrap(model.snapshot(for: account))
            let successfulAt = try XCTUnwrap(
                model.sourceRefreshStates[account.id]?.lastSuccessfulRefreshAt
            )
            XCTAssertNil(
                model.sourceRefreshStates[account.id]?.lastFailedRefreshAt
            )
            let persistedBeforeMutation = AppModel(
                storageDirectory: directory,
                userDefaults: isolatedDefaults(),
                refreshCoordinator: ProviderRefreshCoordinator(
                    retryPolicy: ProviderRetryPolicy(
                        maxAttempts: 1,
                        initialDelay: 0
                    )
                ),
                openRouterAPIClient: client,
                credentialKeychainService: keychain
            )
            let persistedSnapshotBeforeMutation = try XCTUnwrap(
                persistedBeforeMutation.snapshot(for: account)
            )
            let persistedSuccessBeforeMutation = try XCTUnwrap(
                persistedBeforeMutation.sourceRefreshStates[account.id]?
                    .lastSuccessfulRefreshAt
            )

            await client.blockNextOrdinaryRequest()
            model.refresh()
            await client.waitUntilOrdinaryRequestIsBlocked()
            do {
                if disablesCredential {
                    try model.setOpenRouterCredentialEnabled(
                        false,
                        for: account,
                        slotID: credential.slot.slotID
                    )
                } else {
                    try model.replaceOpenRouterCredential(
                        for: account,
                        slotID: credential.slot.slotID,
                        credentialValue: "synthetic-replacement"
                    )
                }
            } catch {
                await client.releaseBlockedOrdinaryRequest()
                throw error
            }
            await client.releaseBlockedOrdinaryRequest()
            await model.waitForRefreshCompletionForTesting()

            XCTAssertEqual(model.snapshot(for: account), successfulSnapshot)
            XCTAssertNil(model.accountRefreshIssues[account.id])
            XCTAssertNil(model.providerRefreshStatuses[account.id])
            XCTAssertEqual(
                model.sourceRefreshStates[account.id]?.lastSuccessfulRefreshAt,
                successfulAt
            )
            XCTAssertNil(
                model.sourceRefreshStates[account.id]?.lastFailedRefreshAt
            )
            XCTAssertTrue(
                model.openRouterCredentialDiagnostics(for: account).isEmpty
            )

            let reloaded = AppModel(
                storageDirectory: directory,
                userDefaults: isolatedDefaults(),
                refreshCoordinator: ProviderRefreshCoordinator(
                    retryPolicy: ProviderRetryPolicy(
                        maxAttempts: 1,
                        initialDelay: 0
                    )
                ),
                openRouterAPIClient: client,
                credentialKeychainService: keychain
            )
            XCTAssertEqual(
                reloaded.snapshot(for: account),
                persistedSnapshotBeforeMutation
            )
            XCTAssertNil(reloaded.accountRefreshIssues[account.id])
            XCTAssertEqual(
                reloaded.sourceRefreshStates[account.id]?.lastSuccessfulRefreshAt,
                persistedSuccessBeforeMutation
            )
            XCTAssertNil(
                reloaded.sourceRefreshStates[account.id]?.lastFailedRefreshAt
            )
            XCTAssertTrue(
                reloaded.openRouterCredentialDiagnostics(for: account).isEmpty
            )
        }
    }

    func testNativePresentationKeepsHierarchyUSDResetAndSourceStatesDistinct() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let account = ProviderAccount(
            providerID: OpenRouterProviderContract.providerID,
            accountID: "account",
            displayName: "OpenRouter",
            isEnabled: true,
            sourceMode: .openRouterAPI
        )
        let root = AccountContext(
            contextID: "root",
            kind: .personal,
            regionID: "global"
        )
        let primary = AccountContext(
            contextID: "primary",
            kind: .credential,
            displayName: "Primary",
            regionID: "global",
            parentContextID: root.contextID
        )
        let backup = AccountContext(
            contextID: "backup",
            kind: .credential,
            displayName: "Backup",
            regionID: "global",
            parentContextID: root.contextID
        )
        let snapshot = CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: OpenRouterProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [root, primary, backup],
            observedAt: now,
            metrics: [
                metric(
                    id: "account-credits",
                    contextID: root.contextID,
                    sourceID: OpenRouterProviderContract.managementSourceID,
                    values: CapacityValues(
                        consumed: CapacityValue(value: 12, origin: .reported),
                        remaining: CapacityValue(value: 88, origin: .derived),
                        limit: CapacityValue(value: 100, origin: .reported)
                    ),
                    observedAt: now
                ),
                metric(
                    id: "key-credit-limit",
                    contextID: primary.contextID,
                    values: CapacityValues(
                        remaining: CapacityValue(value: 8.75, origin: .reported),
                        limit: CapacityValue(value: 10, origin: .reported)
                    ),
                    observedAt: now,
                    window: CapacityWindow(
                        kind: .fixed,
                        nextTransition: CapacityTransition(
                            kind: .reset,
                            at: now.addingTimeInterval(3_600)
                        )
                    )
                ),
                metric(
                    id: "key-total-usage",
                    contextID: primary.contextID,
                    values: CapacityValues(
                        consumed: CapacityValue(value: 1.25, origin: .reported)
                    ),
                    observedAt: now
                ),
                metric(
                    id: "key-weekly-usage",
                    contextID: primary.contextID,
                    availability: .unknown,
                    values: nil,
                    observedAt: now
                ),
                metric(
                    id: "key-monthly-byok-usage",
                    contextID: primary.contextID,
                    availability: .unlimited,
                    values: nil,
                    observedAt: now
                ),
                metric(
                    id: "key-total-usage",
                    contextID: backup.contextID,
                    values: CapacityValues(
                        consumed: CapacityValue(value: 2, origin: .reported)
                    ),
                    observedAt: now.addingTimeInterval(-1_000)
                )
            ]
        )
        let presentation = OpenRouterCapacityPresentation(
            account: account,
            snapshot: snapshot,
            credentialContexts: [
                credential(context: primary, role: .ordinary),
                credential(context: backup, role: .ordinary),
                credential(context: root, role: .management)
            ],
            refreshStates: [],
            diagnostics: [
                CredentialContextDiagnostic(
                    providerID: account.providerID,
                    accountID: account.accountID,
                    slotID: backup.contextID,
                    code: .authentication,
                    occurredAt: now
                )
            ],
            now: now,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(presentation.state, .partial)
        XCTAssertEqual(presentation.sharedCredits.displayName, "Account credits")
        XCTAssertTrue(presentation.sharedCredits.valueText.contains("USD 88"))
        XCTAssertFalse(presentation.sharedCredits.valueText.contains("%"))
        XCTAssertEqual(presentation.credentials.map(\.displayName), ["Backup", "Primary"])
        XCTAssertEqual(presentation.credentials[0].state, .partial)
        XCTAssertEqual(
            presentation.credentials[0].statusText,
            "Credential authentication failed"
        )
        let primaryPresentation = presentation.credentials[1]
        XCTAssertTrue(
            primaryPresentation.metrics.contains {
                $0.valueText == "USD 8.75 remaining of USD 10"
                    && $0.resetText == "Resets in 1 hour"
            }
        )
        XCTAssertTrue(
            primaryPresentation.metrics.contains {
                $0.state == .unknown && $0.valueText == "Unknown"
            }
        )
        XCTAssertTrue(
            primaryPresentation.metrics.contains {
                $0.state == .unlimited && $0.valueText == "Unlimited"
            }
        )

        let russian = OpenRouterCapacityPresentation(
            account: account,
            snapshot: snapshot,
            credentialContexts: [
                credential(context: primary, role: .ordinary)
            ],
            refreshStates: [],
            diagnostics: [],
            now: now,
            locale: Locale(identifier: "ru_RU")
        )
        XCTAssertTrue(
            russian.credentials[0].metrics.contains {
                $0.valueText.contains("USD 8,75")
            }
        )
    }

    func testSharedCreditsRequireActiveEnabledManagementCredential() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let account = ProviderAccount(
            providerID: OpenRouterProviderContract.providerID,
            accountID: "account",
            displayName: "OpenRouter",
            isEnabled: true,
            sourceMode: .openRouterAPI
        )
        let root = AccountContext(
            contextID: "root",
            kind: .personal,
            regionID: "global"
        )
        let snapshot = CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: OpenRouterProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [root],
            observedAt: now,
            metrics: [
                metric(
                    id: "account-credits",
                    contextID: root.contextID,
                    sourceID: OpenRouterProviderContract.managementSourceID,
                    values: CapacityValues(
                        consumed: CapacityValue(value: 10, origin: .reported),
                        remaining: CapacityValue(value: 90, origin: .derived),
                        limit: CapacityValue(value: 100, origin: .reported)
                    ),
                    observedAt: now
                )
            ]
        )
        let oldDiagnostic = CredentialContextDiagnostic(
            providerID: account.providerID,
            accountID: account.accountID,
            slotID: root.contextID,
            code: .authentication,
            occurredAt: now
        )
        let invalidManagementVariants: [[ProviderCredentialContext]] = [
            [],
            [
                credential(
                    context: root,
                    role: .management,
                    isEnabled: false
                )
            ],
            [
                credential(
                    context: root,
                    role: .management,
                    lifecycleState: .pendingCreation
                )
            ],
            [
                credential(
                    context: root,
                    role: .management,
                    lifecycleState: .pendingDeletion
                )
            ]
        ]

        for credentials in invalidManagementVariants {
            let presentation = OpenRouterCapacityPresentation(
                account: account,
                snapshot: snapshot,
                credentialContexts: credentials,
                refreshStates: [],
                diagnostics: [oldDiagnostic],
                now: now,
                locale: Locale(identifier: "en_US")
            )

            XCTAssertEqual(presentation.sharedCredits.state, .unavailable)
            XCTAssertEqual(presentation.sharedCredits.valueText, "Unavailable")
            XCTAssertEqual(presentation.state, .unavailable)
            XCTAssertEqual(presentation.statusText, "Unavailable")
        }
    }

    func testStaleUnlimitedMetricRemainsUnlimitedButAggregatesAsStale() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let account = ProviderAccount(
            providerID: OpenRouterProviderContract.providerID,
            accountID: "account",
            displayName: "OpenRouter",
            isEnabled: true,
            sourceMode: .openRouterAPI
        )
        let root = AccountContext(
            contextID: "root",
            kind: .personal,
            regionID: "global"
        )
        let ordinary = AccountContext(
            contextID: "ordinary",
            kind: .credential,
            displayName: "Ordinary",
            regionID: "global",
            parentContextID: root.contextID
        )
        let snapshot = CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: OpenRouterProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [root, ordinary],
            observedAt: now,
            metrics: [
                metric(
                    id: "key-monthly-byok-usage",
                    contextID: ordinary.contextID,
                    availability: .unlimited,
                    values: nil,
                    observedAt: now.addingTimeInterval(
                        -TimeInterval(
                            OpenRouterProviderContract.maximumAgeSeconds + 1
                        )
                    )
                )
            ]
        )
        let presentation = OpenRouterCapacityPresentation(
            account: account,
            snapshot: snapshot,
            credentialContexts: [
                credential(context: ordinary, role: .ordinary)
            ],
            refreshStates: [],
            diagnostics: [],
            now: now,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(presentation.credentials[0].metrics[0].valueText, "Unlimited")
        XCTAssertEqual(presentation.credentials[0].metrics[0].state, .stale)
        XCTAssertEqual(presentation.credentials[0].state, .stale)
        XCTAssertEqual(presentation.state, .stale)
        XCTAssertEqual(presentation.statusText, "Stale")
    }

    func testDisabledOnlyCredentialMetricsDoNotAffectAccountState() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let account = ProviderAccount(
            providerID: OpenRouterProviderContract.providerID,
            accountID: "account",
            displayName: "OpenRouter",
            isEnabled: true,
            sourceMode: .openRouterAPI
        )
        let root = AccountContext(
            contextID: "root",
            kind: .personal,
            regionID: "global"
        )
        let ordinary = AccountContext(
            contextID: "ordinary",
            kind: .credential,
            displayName: "Disabled",
            regionID: "global",
            parentContextID: root.contextID
        )
        let metricVariants = [
            metric(
                id: "key-total-usage",
                contextID: ordinary.contextID,
                values: CapacityValues(
                    consumed: CapacityValue(value: 1, origin: .reported)
                ),
                observedAt: now
            ),
            metric(
                id: "key-monthly-byok-usage",
                contextID: ordinary.contextID,
                availability: .unlimited,
                values: nil,
                observedAt: now.addingTimeInterval(
                    -TimeInterval(
                        OpenRouterProviderContract.maximumAgeSeconds + 1
                    )
                )
            )
        ]

        for savedMetric in metricVariants {
            let snapshot = CapacitySnapshot(
                providerID: account.providerID,
                surfaceID: OpenRouterProviderContract.surfaceID,
                savedAccountID: account.accountID,
                accountContexts: [root, ordinary],
                observedAt: now,
                metrics: [savedMetric]
            )
            let presentation = OpenRouterCapacityPresentation(
                account: account,
                snapshot: snapshot,
                credentialContexts: [
                    credential(
                        context: ordinary,
                        role: .ordinary,
                        isEnabled: false
                    )
                ],
                refreshStates: [],
                diagnostics: [],
                now: now,
                locale: Locale(identifier: "en_US")
            )

            XCTAssertEqual(presentation.credentials[0].state, .disabled)
            XCTAssertFalse(presentation.credentials[0].metrics.isEmpty)
            XCTAssertEqual(presentation.state, .unavailable)
            XCTAssertEqual(presentation.statusText, "Unavailable")
        }
    }

    func testDisabledStaleSiblingDoesNotDowngradeActiveCurrentCredential() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let account = ProviderAccount(
            providerID: OpenRouterProviderContract.providerID,
            accountID: "account",
            displayName: "OpenRouter",
            isEnabled: true,
            sourceMode: .openRouterAPI
        )
        let root = AccountContext(
            contextID: "root",
            kind: .personal,
            regionID: "global"
        )
        let active = AccountContext(
            contextID: "active",
            kind: .credential,
            displayName: "Active",
            regionID: "global",
            parentContextID: root.contextID
        )
        let disabled = AccountContext(
            contextID: "disabled",
            kind: .credential,
            displayName: "Disabled",
            regionID: "global",
            parentContextID: root.contextID
        )
        let snapshot = CapacitySnapshot(
            providerID: account.providerID,
            surfaceID: OpenRouterProviderContract.surfaceID,
            savedAccountID: account.accountID,
            accountContexts: [root, active, disabled],
            observedAt: now,
            metrics: [
                metric(
                    id: "key-total-usage",
                    contextID: active.contextID,
                    values: CapacityValues(
                        consumed: CapacityValue(value: 1, origin: .reported)
                    ),
                    observedAt: now
                ),
                metric(
                    id: "key-monthly-byok-usage",
                    contextID: disabled.contextID,
                    availability: .unlimited,
                    values: nil,
                    observedAt: now.addingTimeInterval(
                        -TimeInterval(
                            OpenRouterProviderContract.maximumAgeSeconds + 1
                        )
                    )
                )
            ]
        )
        let presentation = OpenRouterCapacityPresentation(
            account: account,
            snapshot: snapshot,
            credentialContexts: [
                credential(context: active, role: .ordinary),
                credential(
                    context: disabled,
                    role: .ordinary,
                    isEnabled: false
                )
            ],
            refreshStates: [],
            diagnostics: [],
            now: now,
            locale: Locale(identifier: "en_US")
        )

        let activePresentation = presentation.credentials.first {
            $0.slotID == active.contextID
        }
        let disabledPresentation = presentation.credentials.first {
            $0.slotID == disabled.contextID
        }
        XCTAssertEqual(activePresentation?.state, .current)
        XCTAssertEqual(disabledPresentation?.state, .disabled)
        XCTAssertEqual(disabledPresentation?.metrics.first?.state, .stale)
        XCTAssertEqual(presentation.state, .current)
        XCTAssertEqual(presentation.statusText, "Current")
    }

    private func metric(
        id: String,
        contextID: String,
        sourceID: String = OpenRouterProviderContract.currentKeySourceID,
        availability: CapacityAvailability = .known,
        values: CapacityValues?,
        observedAt: Date,
        window: CapacityWindow = CapacityWindow(kind: .lifetime)
    ) -> CapacityMetric {
        CapacityMetric(
            metricID: id,
            accountContextID: contextID,
            sourceID: sourceID,
            capability: id.contains("usage") ? "spend" : "credits",
            displayName: "Synthetic",
            availability: availability,
            unit: CapacityUnit(kind: .currency, currencyCode: "USD"),
            values: values,
            window: window,
            freshness: ObservationFreshness(observedAt: observedAt),
            confidence: .live
        )
    }

    private func credential(
        context: AccountContext,
        role: ProviderCredentialRole,
        isEnabled: Bool = true,
        lifecycleState: CredentialLifecycleState = .active
    ) -> ProviderCredentialContext {
        ProviderCredentialContext(
            context: ProviderAccountContextConfiguration(
                providerID: OpenRouterProviderContract.providerID,
                accountID: "account",
                contextID: context.contextID,
                kind: context.kind,
                displayName: context.displayName,
                regionID: context.regionID,
                parentContextID: context.parentContextID
            ),
            slot: ProviderCredentialSlot(
                providerID: OpenRouterProviderContract.providerID,
                accountID: "account",
                slotID: context.contextID,
                contextID: context.contextID,
                role: role,
                isEnabled: isEnabled,
                keychainReference: "reference-\(context.contextID)",
                lifecycleState: lifecycleState
            )
        )
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "OpenRouterSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

private final class SettingsTestKeychain: KeychainService, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: CredentialSecret] = [:]

    var credentialCount: Int {
        lock.withLock { values.count }
    }

    func contains(reference: String) -> Bool {
        lock.withLock { values[reference] != nil }
    }

    func drop(reference: String) {
        _ = lock.withLock {
            values.removeValue(forKey: reference)
        }
    }

    func createCredential(
        _ credential: CredentialSecret,
        reference: String
    ) throws {
        try lock.withLock {
            guard values[reference] == nil else {
                throw KeychainServiceError.duplicateReference
            }
            values[reference] = credential
        }
    }

    func readCredential(reference: String) throws -> CredentialSecret {
        try lock.withLock {
            guard let credential = values[reference] else {
                throw KeychainServiceError.credentialNotFound
            }
            return credential
        }
    }

    func replaceCredential(
        _ credential: CredentialSecret,
        reference: String
    ) throws {
        try lock.withLock {
            guard values[reference] != nil else {
                throw KeychainServiceError.credentialNotFound
            }
            values[reference] = credential
        }
    }

    func deleteCredential(reference: String) throws {
        _ = lock.withLock {
            values.removeValue(forKey: reference)
        }
    }
}

private actor BarrierOpenRouterClient: OpenRouterAPIClient {
    private let base = SyntheticOpenRouterVerificationClient(
        failingOrdinarySlotID: "never"
    )
    private var shouldBlockNextOrdinaryRequest = false
    private var isOrdinaryRequestBlocked = false
    private var blockedWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func blockNextOrdinaryRequest() {
        shouldBlockNextOrdinaryRequest = true
    }

    func waitUntilOrdinaryRequestIsBlocked() async {
        guard !isOrdinaryRequestBlocked else { return }
        await withCheckedContinuation { continuation in
            blockedWaiters.append(continuation)
        }
    }

    func releaseBlockedOrdinaryRequest() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func fetchCurrentKeyCapacity(
        credential: OpenRouterOrdinaryCredential
    ) async throws -> OpenRouterCurrentKeyCapacity {
        guard shouldBlockNextOrdinaryRequest else {
            return try await base.fetchCurrentKeyCapacity(
                credential: credential
            )
        }
        shouldBlockNextOrdinaryRequest = false
        isOrdinaryRequestBlocked = true
        blockedWaiters.forEach { $0.resume() }
        blockedWaiters.removeAll()
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        isOrdinaryRequestBlocked = false
        throw OpenRouterAPIClientError.authenticationFailure
    }

    func fetchManagementCredits(
        credential: OpenRouterManagementCredential
    ) async throws -> OpenRouterManagementCreditsCapacity {
        try await base.fetchManagementCredits(credential: credential)
    }
}
#endif
