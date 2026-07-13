import Foundation
import GRDB

public final class AppDatabase: @unchecked Sendable {
    public static let filename = "AI Limitbar.sqlite"

    public let url: URL
    let pool: DatabasePool

    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(Self.filename)

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.busyMode = .timeout(2)
        pool = try DatabasePool(path: url.path, configuration: configuration)
        try pool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        try makeMigrator().migrate(pool)
    }

    private func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE provider_accounts (
                    provider_id TEXT NOT NULL,
                    account_id TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    display_name_key TEXT NOT NULL UNIQUE,
                    is_enabled INTEGER NOT NULL,
                    source_mode TEXT NOT NULL,
                    web_data_store_id TEXT,
                    codex_executable_path TEXT,
                    sort_index INTEGER NOT NULL,
                    PRIMARY KEY (provider_id, account_id)
                )
                """)

            try db.execute(sql: """
                CREATE TABLE current_snapshots (
                    provider_id TEXT NOT NULL,
                    account_id TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    status TEXT NOT NULL,
                    plan_name TEXT,
                    period_label TEXT,
                    used_percent REAL,
                    remaining_label TEXT,
                    reset_at REAL,
                    last_updated_at REAL NOT NULL,
                    confidence TEXT NOT NULL,
                    source TEXT NOT NULL,
                    PRIMARY KEY (provider_id, account_id),
                    FOREIGN KEY (provider_id, account_id)
                        REFERENCES provider_accounts(provider_id, account_id)
                        ON DELETE CASCADE
                )
                """)

            try db.execute(sql: """
                CREATE TABLE snapshot_limit_windows (
                    provider_id TEXT NOT NULL,
                    account_id TEXT NOT NULL,
                    position INTEGER NOT NULL,
                    window_id TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    used_percent REAL,
                    remaining_label TEXT,
                    reset_at REAL,
                    PRIMARY KEY (provider_id, account_id, position),
                    FOREIGN KEY (provider_id, account_id)
                        REFERENCES current_snapshots(provider_id, account_id)
                        ON DELETE CASCADE
                )
                """)

            try db.execute(sql: """
                CREATE TABLE snapshot_warnings (
                    provider_id TEXT NOT NULL,
                    account_id TEXT NOT NULL,
                    position INTEGER NOT NULL,
                    message TEXT NOT NULL,
                    PRIMARY KEY (provider_id, account_id, position),
                    FOREIGN KEY (provider_id, account_id)
                        REFERENCES current_snapshots(provider_id, account_id)
                        ON DELETE CASCADE
                )
                """)

            try db.execute(sql: """
                CREATE TABLE refresh_settings (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    interval TEXT NOT NULL
                )
                """)

            try db.execute(sql: """
                CREATE TABLE source_diagnostics (
                    id INTEGER PRIMARY KEY,
                    provider_id TEXT,
                    account_id TEXT,
                    code TEXT NOT NULL,
                    message TEXT NOT NULL,
                    occurred_at REAL NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE INDEX source_diagnostics_account
                ON source_diagnostics(provider_id, account_id, occurred_at)
                """)

            try db.execute(sql: """
                CREATE TABLE legacy_import_state (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    version INTEGER NOT NULL,
                    completed_at REAL NOT NULL
                )
                """)
        }
        return migrator
    }
}

public enum AppDatabaseError: LocalizedError, Equatable, Sendable {
    case unavailable
    case missingClaudeCodeAccount

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "AI Limitbar storage is unavailable."
        case .missingClaudeCodeAccount:
            "The selected Claude Code account is not configured for the managed statusLine source."
        }
    }
}
