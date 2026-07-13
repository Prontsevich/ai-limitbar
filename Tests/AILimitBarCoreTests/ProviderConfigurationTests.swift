import XCTest
@testable import AILimitBarCore

final class ProviderConfigurationTests: XCTestCase {
    func testProviderDefaultsUseTheConfiguredSourceForRealProviders() {
        XCTAssertEqual(ProviderSourceMode.defaultMode(for: "claude-code"), .claudeStatusLine)
        XCTAssertEqual(ProviderSourceMode.defaultMode(for: "ollama-cloud"), .ollamaWebPage)
        XCTAssertEqual(ProviderSourceMode.defaultMode(for: "openai-codex"), .appServer)
        XCTAssertEqual(ProviderSourceMode.defaultMode(for: "mock"), .manual)
    }

    func testProviderAccountWithoutSourceUsesProviderDefault() {
        XCTAssertEqual(
            ProviderAccount(providerID: "openai-codex", isEnabled: true).sourceMode,
            .appServer
        )
    }

    func testProviderAccountRejectsManualSourceForRealProviders() {
        XCTAssertEqual(
            ProviderAccount(
                providerID: "ollama-cloud",
                isEnabled: true,
                sourceMode: .manual
            ).sourceMode,
            .ollamaWebPage
        )
    }

    func testProviderAccountDecodesLegacyLocalSnapshotAsManagedStatusLine() throws {
        let account = try JSONDecoder().decode(
            ProviderAccount.self,
            from: Data(
                """
                {
                  "providerID": "claude-code",
                  "accountID": "work",
                  "displayName": "Work",
                  "isEnabled": true,
                  "sourceMode": "local-snapshot",
                  "localSnapshotPath": "/tmp/legacy.json"
                }
                """.utf8
            )
        )

        XCTAssertEqual(account.sourceMode, .claudeStatusLine)
        XCTAssertEqual(account.localSnapshotPath, "/tmp/legacy.json")
    }

    func testDatabaseStoreRoundTripsAccountsAndOrdering() throws {
        let database = try AppDatabase(directory: temporaryDirectory())
        let accounts = [
            ProviderAccount(providerID: "claude-code", accountID: "work", displayName: "Work", isEnabled: true),
            ProviderAccount(providerID: "mock", accountID: "demo", displayName: "Demo", isEnabled: true)
        ]
        let store = DatabaseProviderConfigurationStore(database: database)

        try store.save(accounts)
        let result = store.load(knownProviderIDs: ["mock", "claude-code"])

        XCTAssertEqual(result.accounts.map(\.id), accounts.map(\.id))
        XCTAssertNil(result.warning)
    }

    func testDatabaseStoreRejectsGloballyDuplicateNormalizedDisplayNames() throws {
        let database = try AppDatabase(directory: temporaryDirectory())
        let store = DatabaseProviderConfigurationStore(database: database)

        XCTAssertThrowsError(
            try store.save([
                ProviderAccount(providerID: "mock", accountID: "one", displayName: " Work ", isEnabled: true),
                ProviderAccount(providerID: "claude-code", accountID: "two", displayName: "work", isEnabled: false)
            ])
        ) { error in
            XCTAssertEqual(error as? StorageValidationError, .duplicateDisplayName)
        }
    }

    func testDatabaseStoreDeletesSnapshotsWhenAccountIsRemoved() throws {
        let database = try AppDatabase(directory: temporaryDirectory())
        let account = ProviderAccount(providerID: "mock", accountID: "one", displayName: "One", isEnabled: true)
        let accounts = DatabaseProviderConfigurationStore(database: database)
        let snapshots = DatabaseSnapshotStore(database: database)
        try accounts.save([account])
        try snapshots.save([
            UsageSnapshot(
                providerID: account.providerID,
                accountID: account.accountID,
                accountDisplayName: account.displayName,
                displayName: "Mock",
                status: .ok,
                lastUpdatedAt: Date(),
                confidence: .live,
                source: "Test"
            )
        ])

        try accounts.save([])

        XCTAssertTrue(snapshots.load().snapshots.isEmpty)
    }

    func testDatabaseSourceDiagnosticsRoundTripAndClear() throws {
        let database = try AppDatabase(directory: temporaryDirectory())
        let store = DatabaseSourceDiagnosticStore(database: database)
        let occurredAt = Date(timeIntervalSince1970: 1_000)

        try store.replaceRefreshDiagnostics(
            providerID: "mock",
            accountID: "one",
            occurredAt: occurredAt,
            messages: ["Refresh failed", "Retry later"]
        )
        try store.recordGlobal(code: "legacy-warning", message: "Legacy data needs attention", occurredAt: occurredAt)

        XCTAssertEqual(store.load().filter { $0.providerID == "mock" }.map(\.message), ["Refresh failed", "Retry later"])
        XCTAssertEqual(store.load().first { $0.code == "legacy-warning" }?.message, "Legacy data needs attention")

        try store.clearRefreshDiagnostics(providerID: "mock", accountID: "one")
        XCTAssertFalse(store.load().contains { $0.providerID == "mock" })
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
