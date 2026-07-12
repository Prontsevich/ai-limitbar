import AILimitBarCore
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
        XCTAssertTrue(JSONSnapshotStore(directory: directory).load().snapshots.isEmpty)
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
        XCTAssertTrue(JSONSnapshotStore(directory: directory).load().snapshots.isEmpty)
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
        try ProviderConfigurationStore(directory: directory).save([account])
        try JSONSnapshotStore(directory: directory).save([
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
        model.setAccountSourceMode(adapter.id, accountID: account.accountID, sourceMode: .localSnapshot)
        model.setAccountLocalSnapshotPath(adapter.id, accountID: account.accountID, path: "  ~/usage.json  ")
        model.setAccount(adapter.id, accountID: account.accountID, enabled: false)
        model.setAccount(adapter.id, accountID: account.accountID, enabled: true)
        model.setRefreshInterval(.fifteenMinutes)

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        let reloadedAccount = try XCTUnwrap(reloaded.providerAccounts.first)
        XCTAssertEqual(reloadedAccount.displayName, "Renamed")
        XCTAssertEqual(reloadedAccount.sourceMode, .localSnapshot)
        XCTAssertEqual(reloadedAccount.localSnapshotPath, "~/usage.json")
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
            sourceMode: .localSnapshot,
            localSnapshotPath: "  ~/usage.json  "
        ))

        let reloaded = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        let reloadedAccount = try XCTUnwrap(reloaded.providerAccounts.first)
        XCTAssertEqual(reloadedAccount.displayName, "Work")
        XCTAssertEqual(reloadedAccount.sourceMode, .localSnapshot)
        XCTAssertEqual(reloadedAccount.localSnapshotPath, "~/usage.json")
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
            sourceMode: .localSnapshot,
            localSnapshotPath: "~/usage.json"
        )
        let equivalent = AccountEditorDraft(
            providerID: "claude-code",
            displayName: "  Work  ",
            sourceMode: .localSnapshot,
            localSnapshotPath: "  ~/usage.json  "
        )

        XCTAssertFalse(equivalent.hasChanges(comparedTo: original))
    }

    func testAccountEditorDraftTracksMeaningfulChanges() {
        let original = AccountEditorDraft(providerID: "claude-code")
        XCTAssertFalse(original.hasChanges(comparedTo: original))

        var changed = original
        changed.displayName = "Work"
        changed.sourceMode = .localSnapshot
        changed.localSnapshotPath = "~/usage.json"

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
    func testInvalidClaudeSnapshotPreservesPreviousUsageData() async throws {
        let directory = try temporaryDirectory()
        let snapshotURL = directory.appendingPathComponent("claude-code.json")
        try Data(
            """
            {
              "schemaVersion": 1,
              "limitWindows": [
                { "id": "rolling-5-hour", "displayName": "5-hour", "usedPercent": 42 }
              ],
              "lastUpdatedAt": "2026-07-12T09:00:00Z"
            }
            """.utf8
        ).write(to: snapshotURL)

        let adapter = ClaudeCodeProviderAdapter()
        let model = AppModel(
            registry: ProviderRegistry(adapters: [adapter]),
            storageDirectory: directory
        )
        model.addAccount(
            providerID: adapter.id,
            displayName: "Work",
            sourceMode: .localSnapshot,
            localSnapshotPath: snapshotURL.path
        )
        let account = try XCTUnwrap(model.providerAccounts.first)

        model.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }
        let previousSnapshot = try XCTUnwrap(model.snapshot(for: account))

        try Data("{invalid".utf8).write(to: snapshotURL)
        model.refreshAccount(providerID: account.providerID, accountID: account.accountID)
        while model.refreshStatus(for: account) == .refreshing {
            await Task.yield()
        }

        XCTAssertEqual(model.snapshot(for: account), previousSnapshot)
        XCTAssertNotNil(model.accountRefreshIssues[account.id])
        if case .failed = model.refreshStatus(for: account) {
            // Expected: the failed refresh is tracked separately from the last good snapshot.
        } else {
            XCTFail("Expected the invalid helper output to mark the refresh as failed.")
        }
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
