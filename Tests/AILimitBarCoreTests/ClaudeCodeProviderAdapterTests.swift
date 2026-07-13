import XCTest
@testable import AILimitBarCore

final class ClaudeCodeProviderAdapterTests: XCTestCase {
    func testStatusLineWriterBuildsRateLimitWindows() throws {
        let writer = ClaudeCodeStatusLineSnapshotWriter()
        let now = Date(timeIntervalSince1970: 1_751_880_000)

        let snapshot = try writer.makeSnapshot(
            from: Data(
                """
                {
                  "rate_limits": {
                    "five_hour": { "used_percentage": 23.5, "resets_at": 1751883600 },
                    "seven_day": { "used_percentage": 41.2, "resets_at": 1752320000 }
                  }
                }
                """.utf8
            ),
            now: now
        )

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.usedPercent, 41.2)
        XCTAssertEqual(snapshot.lastUpdatedAt, now)
        XCTAssertEqual(snapshot.limitWindows.map(\.id), ["rolling-5-hour", "seven-day"])
    }

    func testStatusLineWriterRejectsInvalidInputBeforeDatabaseWrite() throws {
        let directory = try temporaryDirectory()
        let database = try AppDatabase(directory: directory)
        let account = claudeAccount()
        try DatabaseProviderConfigurationStore(database: database).save([account])
        let writer = ClaudeCodeStatusLineDatabaseWriter(directory: directory)

        XCTAssertThrowsError(
            try writer.writeSnapshot(from: Data("{}".utf8), accountID: account.accountID)
        ) { error in
            XCTAssertEqual(error as? ClaudeCodeStatusLineError, .noRateLimitData)
        }
        XCTAssertTrue(DatabaseSnapshotStore(database: database).load().snapshots.isEmpty)
    }

    func testManagedStatusLineWriterPersistsNormalizedSnapshot() throws {
        let directory = try temporaryDirectory()
        let database = try AppDatabase(directory: directory)
        let account = claudeAccount()
        try DatabaseProviderConfigurationStore(database: database).save([account])

        let snapshot = try ClaudeCodeStatusLineDatabaseWriter(directory: directory).writeSnapshot(
            from: Data(
                """
                { "rate_limits": { "five_hour": { "used_percentage": 64 } } }
                """.utf8
            ),
            accountID: account.accountID,
            now: Date(timeIntervalSince1970: 1_751_880_000)
        )

        XCTAssertEqual(snapshot.status, .ok)
        XCTAssertEqual(snapshot.confidence, .localEstimate)
        XCTAssertEqual(snapshot.source, "Claude Code managed statusLine")
        XCTAssertEqual(snapshot.limitWindows.map(\.id), ["rolling-5-hour"])
        XCTAssertEqual(
            try DatabaseSnapshotStore(database: database).snapshot(
                providerID: account.providerID,
                accountID: account.accountID
            ),
            snapshot
        )
    }

    func testManagedStatusLineWriterRejectsWrongAccountWithoutReplacingLastSnapshot() throws {
        let directory = try temporaryDirectory()
        let database = try AppDatabase(directory: directory)
        let account = claudeAccount()
        try DatabaseProviderConfigurationStore(database: database).save([account])
        let writer = ClaudeCodeStatusLineDatabaseWriter(directory: directory)
        let first = try writer.writeSnapshot(
            from: Data("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":24}}}".utf8),
            accountID: account.accountID,
            now: Date(timeIntervalSince1970: 1)
        )

        XCTAssertThrowsError(
            try writer.writeSnapshot(
                from: Data("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":80}}}".utf8),
                accountID: "missing"
            )
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .missingClaudeCodeAccount)
        }
        XCTAssertEqual(
            try DatabaseSnapshotStore(database: database).snapshot(
                providerID: account.providerID,
                accountID: account.accountID
            ),
            first
        )
    }

    func testManagedStatusLineAdapterReadsDatabaseSnapshot() async throws {
        let directory = try temporaryDirectory()
        let database = try AppDatabase(directory: directory)
        let account = claudeAccount()
        try DatabaseProviderConfigurationStore(database: database).save([account])
        _ = try ClaudeCodeStatusLineDatabaseWriter(directory: directory).writeSnapshot(
            from: Data("{\"rate_limits\":{\"seven_day\":{\"used_percentage\":41}}}".utf8),
            accountID: account.accountID
        )

        let adapter = ClaudeCodeProviderAdapter(snapshotStore: DatabaseSnapshotStore(database: database))
        let snapshot = try await adapter.fetchSnapshot(account: account)

        XCTAssertEqual(snapshot.accountDisplayName, "Work")
        XCTAssertEqual(snapshot.limitWindows.map(\.id), ["seven-day"])
    }

    func testManagedStatusLineAdapterReportsMissingSnapshot() async throws {
        let directory = try temporaryDirectory()
        let database = try AppDatabase(directory: directory)
        let account = claudeAccount()
        try DatabaseProviderConfigurationStore(database: database).save([account])
        let adapter = ClaudeCodeProviderAdapter(snapshotStore: DatabaseSnapshotStore(database: database))

        do {
            _ = try await adapter.fetchSnapshot(account: account)
            XCTFail("Expected managed statusLine setup error.")
        } catch let error as ProviderAdapterError {
            XCTAssertEqual(error.message, "Claude Code has not written a managed statusLine snapshot yet.")
        }
    }

    private func claudeAccount() -> ProviderAccount {
        ProviderAccount(
            providerID: "claude-code",
            accountID: "work",
            displayName: "Work",
            isEnabled: true,
            sourceMode: .claudeStatusLine
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
