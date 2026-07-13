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

    func testClaudeCodeAllowsExplicitSourceSelectionWithoutChangingDefault() {
        XCTAssertEqual(
            ProviderAccount(providerID: "claude-code", isEnabled: true).sourceMode,
            .claudeStatusLine
        )
        XCTAssertEqual(
            ProviderAccount(
                providerID: "claude-code",
                isEnabled: true,
                sourceMode: .manual
            ).sourceMode,
            .manual
        )
        XCTAssertEqual(
            ProviderAccount(
                providerID: "claude-code",
                isEnabled: true,
                sourceMode: .claudeUsageCLI
            ).sourceMode,
            .claudeUsageCLI
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

    func testProviderAccountDecodesLegacyCodexExecutablePathAndEncodesNeutralKey() throws {
        let account = try JSONDecoder().decode(
            ProviderAccount.self,
            from: Data(
                """
                {
                  "providerID": "openai-codex",
                  "accountID": "work",
                  "displayName": "Work",
                  "isEnabled": true,
                  "sourceMode": "app-server",
                  "codexExecutablePath": "~/.local/bin/codex"
                }
                """.utf8
            )
        )

        XCTAssertEqual(account.executablePath, "~/.local/bin/codex")
        let encoded = try JSONEncoder().encode(account)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["executablePath"] as? String, "~/.local/bin/codex")
        XCTAssertNil(object["codexExecutablePath"])
    }

    func testDatabaseMigrationCopiesLegacyCodexExecutablePath() throws {
        let directory = temporaryDirectory()
        var database: AppDatabase? = try AppDatabase(directory: directory)
        try database?.pool.write { db in
            try db.execute(sql: """
                INSERT INTO provider_accounts (
                    provider_id, account_id, display_name, display_name_key,
                    is_enabled, source_mode, web_data_store_id,
                    codex_executable_path, executable_path, sort_index
                ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, NULL, ?)
                """, arguments: [
                    "openai-codex", "work", "Work", "work", true,
                    "app-server", "~/.local/bin/codex", 0
                ])
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
                arguments: ["v2-provider-neutral-executable-path"]
            )
        }
        database = nil

        let migratedDatabase = try AppDatabase(directory: directory)
        let result = DatabaseProviderConfigurationStore(database: migratedDatabase).load(
            knownProviderIDs: ["openai-codex"]
        )

        XCTAssertEqual(result.accounts.first?.executablePath, "~/.local/bin/codex")
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
