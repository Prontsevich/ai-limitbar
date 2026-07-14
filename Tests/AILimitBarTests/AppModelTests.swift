import AILimitBarCore
import CoreGraphics
import XCTest
@testable import AILimitBar

final class AppModelTests: XCTestCase {
    @MainActor
    func testDeletingAccountDiscardsInFlightRefreshResult() async throws {
        let directory = try temporaryDirectory()
        let gate = AdapterGate()
        let adapter = SuspendedProviderAdapter(gate: gate)
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.testConnection(providerID: account.providerID, accountID: account.accountID)
        while !(await gate.hasStarted) {
            await Task.yield()
        }
        model.deleteAccount(providerID: account.providerID, accountID: account.accountID)
        await gate.release()
        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertTrue(model.providerAccounts.isEmpty)
        XCTAssertTrue(model.snapshots.isEmpty)
        XCTAssertTrue(model.providerRefreshStatuses.isEmpty)
        XCTAssertTrue(model.accountRefreshIssues.isEmpty)
        XCTAssertTrue(DatabaseSnapshotStore(database: try AppDatabase(directory: directory)).load().snapshots.isEmpty)
    }

    @MainActor
    func testDeletingAccountDiscardsInFlightGlobalRefreshResult() async throws {
        let directory = try temporaryDirectory()
        let gate = AdapterGate()
        let adapter = SuspendedProviderAdapter(gate: gate)
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.refresh()
        while !(await gate.hasStarted) {
            await Task.yield()
        }
        model.deleteAccount(providerID: account.providerID, accountID: account.accountID)
        await gate.release()
        while model.isRefreshing {
            await Task.yield()
        }

        XCTAssertTrue(model.providerAccounts.isEmpty)
        XCTAssertTrue(model.snapshots.isEmpty)
        XCTAssertTrue(model.providerRefreshStatuses.isEmpty)
        XCTAssertTrue(DatabaseSnapshotStore(database: try AppDatabase(directory: directory)).load().snapshots.isEmpty)
    }

    @MainActor
    func testMismatchedAdapterResultFailsRequestedAccountWithoutStuckRefresh() async throws {
        let directory = try temporaryDirectory()
        let adapter = MismatchedImmediateAdapter()
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.testConnection(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }

        XCTAssertEqual(model.refreshStatus(for: account), .failed(model.snapshots[0].lastUpdatedAt))
        XCTAssertNotNil(model.accountRefreshIssues[account.id])
        XCTAssertEqual(model.snapshots.map(\.id), [account.id])
        XCTAssertFalse(model.hasActiveProviderRefresh)
    }

    @MainActor
    func testRefreshDiagnosticsPersistAcrossLaunchAndClearAfterSuccess() async throws {
        let directory = try temporaryDirectory()
        let failingAdapter = MismatchedImmediateAdapter()
        let model = AppModel(
            registry: ProviderRegistry(adapters: [failingAdapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: failingAdapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.testConnection(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [ImmediateProviderAdapter(id: failingAdapter.id)]),
            storageDirectory: directory
        )
        XCTAssertNotNil(reloaded.accountRefreshIssues[account.id])
        XCTAssertNil(reloaded.sourceRefreshStates[account.id]?.lastSuccessfulRefreshAt)
        XCTAssertEqual(
            reloaded.sourceRefreshStates[account.id]?.lastFailedRefreshAt,
            reloaded.sourceRefreshStates[account.id]?.lastAttemptAt
        )

        reloaded.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while reloaded.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }
        XCTAssertNil(reloaded.accountRefreshIssues[account.id])
        XCTAssertNotNil(reloaded.sourceRefreshStates[account.id]?.lastSuccessfulRefreshAt)

        let cleared = AppModel(
            registry: ProviderRegistry(adapters: [ImmediateProviderAdapter(id: failingAdapter.id)]),
            storageDirectory: directory
        )
        XCTAssertNil(cleared.accountRefreshIssues[account.id])
        XCTAssertNotNil(cleared.sourceRefreshStates[account.id]?.lastSuccessfulRefreshAt)
    }

    @MainActor
    func testDeletingFailedAccountClearsDiagnosticsAndMenuBarStateAcrossLaunch() async throws {
        let directory = try temporaryDirectory()
        let failingAdapter = MismatchedImmediateAdapter()
        let model = AppModel(
            registry: ProviderRegistry(adapters: [failingAdapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: failingAdapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.testConnection(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }
        XCTAssertFalse(model.accountRefreshIssues.isEmpty)
        XCTAssertEqual(model.menuBarSystemImage, "exclamationmark.triangle")

        model.deleteAccount(providerID: account.providerID, accountID: account.accountID)

        XCTAssertTrue(model.accountRefreshIssues.isEmpty)
        XCTAssertEqual(model.menuBarSystemImage, "gauge.with.dots.needle.33percent")
        let database = try AppDatabase(directory: directory)
        XCTAssertTrue(DatabaseSourceDiagnosticStore(database: database).load().isEmpty)

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [ImmediateProviderAdapter(id: failingAdapter.id)]),
            storageDirectory: directory
        )
        XCTAssertTrue(reloaded.accountRefreshIssues.isEmpty)
        XCTAssertEqual(reloaded.menuBarSystemImage, "gauge.with.dots.needle.33percent")
    }

    @MainActor
    func testLateFailedOllamaConnectionResultDoesNotRestoreDeletedAccountState() throws {
        let directory = try temporaryDirectory()
        let adapter = OllamaCloudProviderAdapter()
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(
            providerID: adapter.id,
            displayName: "Ollama Work",
            sourceMode: .ollamaWebPage
        )
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.deleteAccount(providerID: account.providerID, accountID: account.accountID)
        model.acceptOllamaUsagePayload(
            OllamaUsagePagePayload(session: nil, weekly: nil),
            for: account
        )

        XCTAssertTrue(model.providerAccounts.isEmpty)
        XCTAssertTrue(model.snapshots.isEmpty)
        XCTAssertTrue(model.providerRefreshStatuses.isEmpty)
        XCTAssertTrue(model.accountRefreshIssues.isEmpty)
        let database = try AppDatabase(directory: directory)
        XCTAssertTrue(DatabaseSourceDiagnosticStore(database: database).load().isEmpty)
    }

    @MainActor
    func testFailedConfigurationSaveRollsBackAccountMutation() throws {
        let root = try temporaryDirectory()
        let invalidDirectory = root.appendingPathComponent("not-a-directory")
        try Data("file".utf8).write(to: invalidDirectory)
        let adapter = ImmediateProviderAdapter(id: "test")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: invalidDirectory
        )

        model.addAccount(providerID: adapter.id, displayName: "Unsaved")

        XCTAssertTrue(model.providerAccounts.isEmpty)
        XCTAssertEqual(model.storageWarning, "Provider settings could not be saved.")
    }

    @MainActor
    func testMenuBarSummaryLoadsPersistedAccountState() throws {
        let directory = try temporaryDirectory()
        let account = ProviderAccount(
            providerID: "summary",
            accountID: "work",
            displayName: "Work",
            isEnabled: true
        )
        let database = try AppDatabase(directory: directory)
        try DatabaseProviderConfigurationStore(database: database).save([account])
        try DatabaseSnapshotStore(database: database).save([
            UsageSnapshot(
                providerID: account.providerID,
                accountID: account.accountID,
                accountDisplayName: account.displayName,
                displayName: "Summary",
                status: .warning,
                usedPercent: 88,
                lastUpdatedAt: Date(timeIntervalSince1970: 1_200),
                confidence: .localEstimate,
                source: "Test"
            )
        ])

        let model = AppModel(
            registry: ProviderRegistry(adapters: [ImmediateProviderAdapter(id: "summary")]),
            storageDirectory: directory
        )

        XCTAssertEqual(model.menuBarTitle, "AI 88%")
        XCTAssertEqual(model.menuBarSystemImage, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(model.menuBarAccessibilityValue, "Highest usage is 88 percent")
    }

    @MainActor
    func testAccountOrderingMatchesDashboardRows() throws {
        let directory = try temporaryDirectory()
        let firstAdapter = ImmediateProviderAdapter(id: "first")
        let secondAdapter = ImmediateProviderAdapter(id: "second")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [firstAdapter, secondAdapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: firstAdapter.id, displayName: "First")
        model.addAccount(providerID: secondAdapter.id, displayName: "Second")
        let first = try XCTUnwrap(model.providerAccounts.first)

        model.moveAccountDown(providerID: first.providerID, accountID: first.accountID)

        XCTAssertEqual(model.providerAccounts.map(\.displayName), ["Second", "First"])
        XCTAssertEqual(model.enabledAccountRows.map(\.account.displayName), ["Second", "First"])
    }

    @MainActor
    func testAccountSettingsMutationsPersistAndReload() throws {
        let directory = try temporaryDirectory()
        let adapter = ImmediateProviderAdapter(
            id: "claude-code",
            usageURL: URL(string: "https://example.com/usage")
        )
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.setAccountDisplayName(adapter.id, accountID: account.accountID, displayName: "Renamed")
        model.setAccountSourceMode(adapter.id, accountID: account.accountID, sourceMode: .claudeStatusLine)
        model.setAccount(adapter.id, accountID: account.accountID, enabled: false)
        model.setAccount(adapter.id, accountID: account.accountID, enabled: true)
        model.setRefreshInterval(.fifteenMinutes)

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        let reloadedAccount = try XCTUnwrap(reloaded.providerAccounts.first)
        XCTAssertEqual(reloadedAccount.displayName, "Renamed")
        XCTAssertEqual(reloadedAccount.sourceMode, .claudeStatusLine)
        XCTAssertTrue(reloadedAccount.isEnabled)
        XCTAssertEqual(reloaded.refreshSettings.interval, .fifteenMinutes)
        XCTAssertEqual(reloaded.usageURL(providerID: adapter.id, accountID: account.accountID), adapter.usageURL)
        XCTAssertNil(reloaded.usageURL(providerID: adapter.id, accountID: "missing"))
    }

    @MainActor
    func testAtomicAccountEditPersistsAllEditableFields() throws {
        let directory = try temporaryDirectory()
        let adapter = ImmediateProviderAdapter(id: "claude-code")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "Personal")
        let account = try XCTUnwrap(model.providerAccounts.first)

        XCTAssertTrue(model.updateAccount(
            providerID: account.providerID,
            accountID: account.accountID,
            displayName: "  Work  ",
            sourceMode: .claudeStatusLine
        ))

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        let reloadedAccount = try XCTUnwrap(reloaded.providerAccounts.first)
        XCTAssertEqual(reloadedAccount.displayName, "Work")
        XCTAssertEqual(reloadedAccount.sourceMode, .claudeStatusLine)
    }

    @MainActor
    func testCodexAppServerConfigurationPersistsAndAllowsOnlyOneAccount() throws {
        let directory = try temporaryDirectory()
        let adapter = ImmediateProviderAdapter(id: "openai-codex")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )

        let firstAccount = try XCTUnwrap(model.addAccount(
            providerID: adapter.id,
            displayName: "Personal",
            sourceMode: .appServer,
            executablePath: "  ~/.local/bin/codex  "
        ))
        XCTAssertNil(model.addAccount(
            providerID: adapter.id,
            displayName: "Duplicate",
            sourceMode: .appServer
        ))
        XCTAssertNil(model.addAccount(
            providerID: adapter.id,
            displayName: "Work",
            sourceMode: .manual
        ))
        XCTAssertFalse(model.canAddAccount(providerID: adapter.id))

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        let persisted = try XCTUnwrap(reloaded.account(
            providerID: firstAccount.providerID,
            accountID: firstAccount.accountID
        ))
        XCTAssertEqual(persisted.sourceMode, .appServer)
        XCTAssertEqual(persisted.executablePath, "~/.local/bin/codex")
    }

    @MainActor
    func testClaudeUsageCLIConfigurationAllowsOnlyOneSavedAccountIncludingDisabledAccounts() throws {
        let directory = try temporaryDirectory()
        let adapter = ImmediateProviderAdapter(id: "claude-code")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        let first = try XCTUnwrap(model.addAccount(providerID: adapter.id, displayName: "Personal"))
        let second = try XCTUnwrap(model.addAccount(providerID: adapter.id, displayName: "Work"))

        XCTAssertTrue(model.updateAccount(
            providerID: first.providerID,
            accountID: first.accountID,
            displayName: first.displayName,
            sourceMode: .claudeUsageCLI,
            executablePath: "  ~/.local/bin/claude  "
        ))
        model.setAccount(first.providerID, accountID: first.accountID, enabled: false)

        XCTAssertFalse(model.updateAccount(
            providerID: second.providerID,
            accountID: second.accountID,
            displayName: second.displayName,
            sourceMode: .claudeUsageCLI
        ))
        XCTAssertTrue(model.hasClaudeUsageCLIConflict(
            providerID: second.providerID,
            accountID: second.accountID,
            sourceMode: .claudeUsageCLI
        ))

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        XCTAssertEqual(
            reloaded.account(providerID: first.providerID, accountID: first.accountID)?.executablePath,
            "~/.local/bin/claude"
        )
    }

    @MainActor
    func testMovingMultipleAccountsPreservesDashboardOrder() throws {
        let directory = try temporaryDirectory()
        let adapter = ImmediateProviderAdapter(id: "test")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "First")
        model.addAccount(providerID: adapter.id, displayName: "Second")
        model.addAccount(providerID: adapter.id, displayName: "Third")

        model.moveAccounts(fromOffsets: IndexSet([0, 1]), toOffset: 3)

        XCTAssertEqual(model.providerAccounts.map(\.displayName), ["Third", "First", "Second"])
        XCTAssertEqual(model.enabledAccountRows.map(\.account.displayName), ["Third", "First", "Second"])
    }

    func testAccountEditorDraftIgnoresPersistenceEquivalentWhitespace() {
        let original = AccountEditorDraft(
            providerID: "claude-code",
            displayName: "Work",
            sourceMode: .claudeStatusLine
        )
        let equivalent = AccountEditorDraft(
            providerID: "claude-code",
            displayName: "  Work  ",
            sourceMode: .claudeStatusLine
        )

        XCTAssertFalse(equivalent.hasChanges(comparedTo: original))
    }

    func testAccountEditorDraftTracksMeaningfulChanges() {
        let original = AccountEditorDraft(providerID: "claude-code")
        XCTAssertFalse(original.hasChanges(comparedTo: original))

        var changed = original
        changed.displayName = "Work"
        changed.sourceMode = .claudeStatusLine

        XCTAssertTrue(changed.hasChanges(comparedTo: original))
    }

    func testAccountEditorSessionDiscardPreservesSelectionAndResetClearsIt() {
        var session = AccountEditorSession(
            selectedAccountID: "account-1",
            mode: .editing,
            isDirty: true
        )

        session.discardEditor()
        XCTAssertEqual(session.selectedAccountID, "account-1")
        XCTAssertNil(session.mode)
        XCTAssertFalse(session.isDirty)

        session.reset()
        XCTAssertNil(session.selectedAccountID)
        XCTAssertNil(session.mode)
        XCTAssertFalse(session.isDirty)
    }

    func testSettingsWorkspaceResetRestoresCleanAccountsState() {
        var workspace = SettingsWorkspaceState()
        workspace.selection = .providerSetup
        workspace.editorSession = AccountEditorSession(
            selectedAccountID: "account-1",
            mode: .editing,
            isDirty: true
        )
        workspace.pendingNavigation = .account("account-2")
        workspace.isShowingDiscardConfirmation = true

        workspace.reset()

        XCTAssertEqual(workspace.selection, .accounts)
        XCTAssertNil(workspace.editorSession.selectedAccountID)
        XCTAssertNil(workspace.editorSession.mode)
        XCTAssertFalse(workspace.editorSession.isDirty)
        XCTAssertNil(workspace.pendingNavigation)
        XCTAssertFalse(workspace.isShowingDiscardConfirmation)
    }

    func testSettingsWindowDefaultSizeUsesPreferredSizeWhenItFits() {
        let size = SettingsWindowConfiguration.defaultSize(
            contentSize: CGSize(width: 840, height: 560),
            visibleRect: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(size, CGSize(width: 840, height: 560))
    }

    func testSettingsWindowDefaultSizeClampsToVisibleDisplay() {
        let size = SettingsWindowConfiguration.defaultSize(
            contentSize: CGSize(width: 840, height: 560),
            visibleRect: CGRect(x: 0, y: 0, width: 700, height: 480)
        )

        XCTAssertEqual(size, CGSize(width: 700, height: 480))
    }

    func testSettingsWindowDefaultPlacementCentersOnRequestedDisplay() {
        let placement = SettingsWindowConfiguration.defaultPlacement(
            contentSize: CGSize(width: 840, height: 560),
            visibleRect: CGRect(x: -2_560, y: 25, width: 2_560, height: 1_415)
        )

        XCTAssertEqual(placement.size, CGSize(width: 840, height: 560))
        XCTAssertEqual(placement.position, CGPoint(x: -1_700, y: 452.5))
    }

    func testSettingsWindowDefaultPlacementKeepsClampedWindowInsideDisplay() {
        let placement = SettingsWindowConfiguration.defaultPlacement(
            contentSize: CGSize(width: 840, height: 560),
            visibleRect: CGRect(x: 100, y: 40, width: 700, height: 480)
        )

        XCTAssertEqual(placement.size, CGSize(width: 700, height: 480))
        XCTAssertEqual(placement.position, CGPoint(x: 100, y: 40))
    }

    func testSettingsWindowFrameCentersUsingActualWindowFrame() {
        let frame = SettingsWindowConfiguration.centeredWindowFrame(
            CGRect(x: 0, y: 0, width: 840, height: 588),
            in: CGRect(x: -2_560, y: 25, width: 2_560, height: 1_415)
        )

        XCTAssertEqual(frame, CGRect(x: -1_700, y: 438.5, width: 840, height: 588))
    }

    @MainActor
    func testSuccessfulRefreshUpdatesSnapshotStatusAndStaleness() async throws {
        let directory = try temporaryDirectory()
        let adapter = ImmediateProviderAdapter(id: "refreshable")
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(providerID: adapter.id, displayName: "Work")
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }

        let snapshot = try XCTUnwrap(model.snapshot(for: account))
        XCTAssertEqual(snapshot.usedPercent, 42)
        XCTAssertEqual(model.refreshStatus(for: account), .succeeded(snapshot.lastUpdatedAt))
        XCTAssertFalse(model.isSnapshotStale(snapshot, now: snapshot.lastUpdatedAt))
        XCTAssertTrue(model.isSnapshotStale(
            snapshot,
            now: snapshot.lastUpdatedAt.addingTimeInterval(model.refreshSettings.interval.staleAfter + 1)
        ))
    }

    @MainActor
    func testInvalidClaudeStatusLineInputPreservesPreviousUsageData() async throws {
        let directory = try temporaryDirectory()
        let model = AppModel(storageDirectory: directory)
        model.addAccount(
            providerID: "claude-code",
            displayName: "Work",
            sourceMode: .claudeStatusLine
        )
        let account = try XCTUnwrap(model.providerAccounts.first)
        _ = try ClaudeCodeStatusLineDatabaseWriter(directory: directory).writeSnapshot(
            from: Data("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":42}}}".utf8),
            accountID: account.accountID
        )

        model.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }
        let previousSnapshot = try XCTUnwrap(model.snapshot(for: account))

        XCTAssertThrowsError(
            try ClaudeCodeStatusLineDatabaseWriter(directory: directory).writeSnapshot(
                from: Data("{invalid".utf8),
                accountID: account.accountID
            )
        )

        XCTAssertEqual(model.snapshot(for: account), previousSnapshot)
        XCTAssertNil(model.accountRefreshIssues[account.id])
    }

    @MainActor
    func testOllamaRefreshFailurePreservesPreviousUsageData() async throws {
        let directory = try temporaryDirectory()
        let adapter = OllamaCloudProviderAdapter(client: FailingOllamaClient())
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(
            providerID: adapter.id,
            displayName: "Ollama Work",
            sourceMode: .ollamaWebPage
        )
        let account = try XCTUnwrap(model.providerAccounts.first)
        model.providerAccounts[0].webDataStoreID = UUID()

        let previousSnapshot = UsageSnapshot(
            providerID: account.providerID,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: adapter.displayName,
            status: .ok,
            limitWindows: [
                UsageLimitWindow(id: "session", displayName: "Session", usedPercent: 24)
            ],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: .live,
            source: OllamaUsagePageParser.sourceDescription,
            warnings: [OllamaUsagePageParser.compatibilityWarning]
        )
        model.snapshots = [previousSnapshot]

        model.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }

        XCTAssertEqual(model.snapshot(for: account), previousSnapshot)
        XCTAssertNotNil(model.accountRefreshIssues[account.id])
        if case .failed = model.refreshStatus(for: account) {
            // Expected: the failed refresh is tracked separately from the last good snapshot.
        } else {
            XCTFail("Expected the Ollama refresh to be marked as failed.")
        }
    }

    @MainActor
    func testClaudeUsageCLIFailurePreservesPreviousUsageData() async throws {
        let directory = try temporaryDirectory()
        let adapter = ClaudeCodeProviderAdapter(usageCLIClient: FailingClaudeUsageCLIClient())
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory,
            refreshCoordinator: ProviderRefreshCoordinator(
                retryPolicy: ProviderRetryPolicy(maxAttempts: 1, initialDelay: 0)
            )
        )
        model.addAccount(
            providerID: adapter.id,
            displayName: "Claude Work",
            sourceMode: .claudeUsageCLI
        )
        let account = try XCTUnwrap(model.providerAccounts.first)
        let previousSnapshot = UsageSnapshot(
            providerID: account.providerID,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: adapter.displayName,
            status: .ok,
            limitWindows: [
                UsageLimitWindow(id: "weekly-all", displayName: "Current week (all models)", usedPercent: 24)
            ],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: .live,
            source: ClaudeCodeSnapshotSource.usageCLI,
            warnings: [ClaudeCodeSnapshotSource.usageCLICompatibilityNotice]
        )
        model.snapshots = [previousSnapshot]

        model.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }

        XCTAssertEqual(model.snapshot(for: account), previousSnapshot)
        XCTAssertNotNil(model.accountRefreshIssues[account.id])
        if case .failed = model.refreshStatus(for: account) {
            // Expected.
        } else {
            XCTFail("Expected the Claude /usage refresh to be marked as failed.")
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private actor AdapterGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var hasStarted = false

    func wait() async {
        hasStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private struct SuspendedProviderAdapter: ProviderAdapter {
    let id = "suspended"
    let displayName = "Suspended"
    let usageURL: URL? = nil
    let gate: AdapterGate

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        await gate.wait()
        return UsageSnapshot(
            providerID: id,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: displayName,
            status: .ok,
            usedPercent: 42,
            lastUpdatedAt: Date(),
            confidence: .localEstimate,
            source: "Test"
        )
    }
}

private struct ImmediateProviderAdapter: ProviderAdapter {
    let id: String
    let usageURL: URL?
    var displayName: String { id.capitalized }

    init(id: String, usageURL: URL? = nil) {
        self.id = id
        self.usageURL = usageURL
    }

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        UsageSnapshot(
            providerID: id,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: displayName,
            status: .ok,
            usedPercent: 42,
            lastUpdatedAt: Date(),
            confidence: .localEstimate,
            source: "Test"
        )
    }
}

private struct MismatchedImmediateAdapter: ProviderAdapter {
    let id = "expected"
    let displayName = "Expected"
    let usageURL: URL? = nil

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        UsageSnapshot(
            providerID: "other",
            accountID: "other",
            accountDisplayName: "Other",
            displayName: displayName,
            status: .ok,
            lastUpdatedAt: Date(),
            confidence: .localEstimate,
            source: "Broken test adapter"
        )
    }
}

private struct FailingOllamaClient: OllamaWebPageClient {
    func fetchUsage(account: ProviderAccount) async throws -> OllamaUsagePagePayload {
        throw ProviderAdapterError(
            providerID: "ollama-cloud",
            message: "Ollama settings page is unavailable.",
            recoverySuggestion: "Reconnect Ollama.",
            isTransient: false
        )
    }
}

private struct FailingClaudeUsageCLIClient: ClaudeUsageCLIClient {
    func fetchUsage(executablePath: String?) async throws -> ClaudeUsageCLIEnvelope {
        throw ClaudeUsageCLIClientError.timedOut
    }
}
