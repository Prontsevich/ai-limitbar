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

        migrator.registerMigration("v2-provider-neutral-executable-path") { db in
            let hasExecutablePath = try db.columns(in: "provider_accounts").contains {
                $0.name == "executable_path"
            }
            if !hasExecutablePath {
                try db.execute(sql: "ALTER TABLE provider_accounts ADD COLUMN executable_path TEXT")
            }
            try db.execute(sql: """
                UPDATE provider_accounts
                SET executable_path = codex_executable_path
                WHERE executable_path IS NULL
                  AND codex_executable_path IS NOT NULL
                """)
        }

        migrator.registerMigration("v3-account-diagnostic-lifecycle") { db in
            try db.execute(sql: """
                CREATE TABLE source_diagnostics_v3 (
                    id INTEGER PRIMARY KEY,
                    provider_id TEXT,
                    account_id TEXT,
                    code TEXT NOT NULL,
                    message TEXT NOT NULL,
                    occurred_at REAL NOT NULL,
                    FOREIGN KEY (provider_id, account_id)
                        REFERENCES provider_accounts(provider_id, account_id)
                        ON DELETE CASCADE
                )
                """)
            try db.execute(sql: """
                INSERT INTO source_diagnostics_v3 (
                    id, provider_id, account_id, code, message, occurred_at
                )
                SELECT
                    diagnostic.id,
                    diagnostic.provider_id,
                    diagnostic.account_id,
                    diagnostic.code,
                    diagnostic.message,
                    diagnostic.occurred_at
                FROM source_diagnostics AS diagnostic
                WHERE diagnostic.provider_id IS NULL
                   OR diagnostic.account_id IS NULL
                   OR EXISTS (
                       SELECT 1
                       FROM provider_accounts AS account
                       WHERE account.provider_id = diagnostic.provider_id
                         AND account.account_id = diagnostic.account_id
                   )
                """)
            try db.execute(sql: "DROP TABLE source_diagnostics")
            try db.execute(sql: "ALTER TABLE source_diagnostics_v3 RENAME TO source_diagnostics")
            try db.execute(sql: """
                CREATE INDEX source_diagnostics_account
                ON source_diagnostics(provider_id, account_id, occurred_at)
                """)
        }

        migrator.registerMigration("v4-refresh-state-diagnostics") { db in
            try db.execute(sql: """
                CREATE TABLE source_refresh_state (
                    provider_id TEXT NOT NULL,
                    account_id TEXT NOT NULL,
                    last_attempt_at REAL,
                    last_successful_refresh_at REAL,
                    last_failed_refresh_at REAL,
                    PRIMARY KEY (provider_id, account_id),
                    FOREIGN KEY (provider_id, account_id)
                        REFERENCES provider_accounts(provider_id, account_id)
                        ON DELETE CASCADE
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
