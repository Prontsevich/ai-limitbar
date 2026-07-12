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
        XCTAssertEqual(snapshot.periodLabel, "Claude Code rate limits")
        XCTAssertEqual(snapshot.usedPercent, 41.2)
        XCTAssertEqual(snapshot.lastUpdatedAt, now)
        XCTAssertEqual(snapshot.limitWindows.map(\.id), ["rolling-5-hour", "seven-day"])
        XCTAssertEqual(snapshot.limitWindows[0].remainingLabel, "Approx. 77% remaining")
        XCTAssertEqual(snapshot.limitWindows[1].resetAt, Date(timeIntervalSince1970: 1752320000))
    }

    func testStatusLineWriterSkipsWindowWithoutPercentage() throws {
        let writer = ClaudeCodeStatusLineSnapshotWriter()
        let snapshot = try writer.makeSnapshot(
            from: Data(
                """
                {
                  "rate_limits": {
                    "five_hour": {},
                    "seven_day": { "used_percentage": 12 }
                  }
                }
                """.utf8
            )
        )

        XCTAssertEqual(snapshot.limitWindows.map(\.id), ["seven-day"])
    }

    func testStatusLineWriterRejectsInvalidPercentage() {
        let writer = ClaudeCodeStatusLineSnapshotWriter()

        XCTAssertThrowsError(
            try writer.makeSnapshot(
                from: Data(
                    "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":101}}}".utf8
                )
            )
        ) { error in
            XCTAssertEqual(error as? ClaudeCodeStatusLineError, .invalidPercentage("5-hour"))
        }
    }

    func testStatusLineWriterRejectsMissingRateLimitsWithoutWriting() throws {
        let writer = ClaudeCodeStatusLineSnapshotWriter()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("statusline.json")

        XCTAssertThrowsError(
            try writer.writeSnapshot(from: Data("{}".utf8), to: fileURL)
        ) { error in
            XCTAssertEqual(error as? ClaudeCodeStatusLineError, .noRateLimitData)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testLocalSnapshotModeReportsMissingFile() async {
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: "/tmp/ai-limitbar-missing-\(UUID().uuidString).json"
        )

        do {
            _ = try await adapter.fetchSnapshot(account: account)
            XCTFail("Expected missing local snapshot file to throw.")
        } catch let error as ProviderAdapterError {
            XCTAssertEqual(error.message, "Claude Code local snapshot file was not found.")
        } catch {
            XCTFail("Expected ProviderAdapterError, got \(error).")
        }
    }

    func testLocalSnapshotModeReportsInvalidJSON() async throws {
        let fileURL = try writeSnapshot("{invalid")
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: fileURL.path
        )

        do {
            _ = try await adapter.fetchSnapshot(account: account)
            XCTFail("Expected invalid JSON to throw.")
        } catch let error as ProviderAdapterError {
            XCTAssertEqual(error.message, "Claude Code local snapshot JSON is invalid.")
        } catch {
            XCTFail("Expected ProviderAdapterError, got \(error).")
        }
    }

    func testLocalSnapshotModeReportsUnsupportedSchema() async throws {
        let fileURL = try writeSnapshot(
            """
            {
              "schemaVersion": 2,
              "lastUpdatedAt": "2026-07-12T10:00:00Z"
            }
            """
        )
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: fileURL.path
        )

        do {
            _ = try await adapter.fetchSnapshot(account: account)
            XCTFail("Expected unsupported schema to throw.")
        } catch let error as ProviderAdapterError {
            XCTAssertEqual(error.message, "Claude Code local snapshot schema version is unsupported.")
        } catch {
            XCTFail("Expected ProviderAdapterError, got \(error).")
        }
    }

    func testManualModeReturnsManualSnapshot() async throws {
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(providerID: "claude-code", accountID: "work", displayName: "Work", isEnabled: true)

        let snapshot = try await adapter.fetchSnapshot(account: account)

        XCTAssertEqual(snapshot.providerID, "claude-code")
        XCTAssertEqual(snapshot.accountID, "work")
        XCTAssertEqual(snapshot.accountDisplayName, "Work")
        XCTAssertEqual(snapshot.confidence, .manual)
        XCTAssertEqual(snapshot.status, .unavailable)
    }

    func testLocalSnapshotModeLoadsConfiguredJSONFile() async throws {
        let fileURL = try writeSnapshot(
            """
            {
              "schemaVersion": 1,
              "planName": "Max",
              "periodLabel": "5-hour window",
              "usedPercent": 64,
              "remainingLabel": "Approx. 36% remaining",
              "resetAt": "2026-07-07T18:00:00Z",
              "lastUpdatedAt": "2026-07-07T10:15:00Z"
            }
            """
        )
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            accountID: "work",
            displayName: "Work",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: fileURL.path
        )

        let snapshot = try await adapter.fetchSnapshot(account: account)

        XCTAssertEqual(snapshot.providerID, "claude-code")
        XCTAssertEqual(snapshot.accountID, "work")
        XCTAssertEqual(snapshot.accountDisplayName, "Work")
        XCTAssertEqual(snapshot.displayName, "Claude Code")
        XCTAssertEqual(snapshot.status, .ok)
        XCTAssertEqual(snapshot.planName, "Max")
        XCTAssertEqual(snapshot.periodLabel, "5-hour window")
        XCTAssertEqual(snapshot.usedPercent, 64)
        XCTAssertEqual(snapshot.remainingLabel, "Approx. 36% remaining")
        XCTAssertEqual(snapshot.displayLimitWindows.count, 1)
        XCTAssertEqual(snapshot.displayLimitWindows[0].id, "primary")
        XCTAssertEqual(snapshot.confidence, .localEstimate)
        XCTAssertEqual(snapshot.source, "Claude Code local snapshot file")
        XCTAssertEqual(snapshot.warnings, ["Local estimate only; usage from other machines or Claude surfaces may be missing."])
    }

    func testLocalSnapshotModeLoadsLimitWindows() async throws {
        let fileURL = try writeSnapshot(
            """
            {
              "schemaVersion": 1,
              "planName": "Max",
              "limitWindows": [
                {
                  "id": "weekly",
                  "displayName": "Weekly",
                  "usedPercent": 52,
                  "remainingLabel": "Approx. 48% remaining",
                  "resetAt": "2026-07-14T00:00:00Z"
                },
                {
                  "id": "rolling-5-hour",
                  "displayName": "5-hour",
                  "usedPercent": 87,
                  "remainingLabel": "Approx. 13% remaining",
                  "resetAt": "2026-07-07T18:00:00Z"
                }
              ],
              "lastUpdatedAt": "2026-07-07T10:15:00Z"
            }
            """
        )
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            accountID: "work",
            displayName: "Work",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: fileURL.path
        )

        let snapshot = try await adapter.fetchSnapshot(account: account)

        XCTAssertEqual(snapshot.status, .warning)
        XCTAssertEqual(snapshot.limitWindows.count, 2)
        XCTAssertEqual(snapshot.limitWindows[0].id, "weekly")
        XCTAssertEqual(snapshot.limitWindows[1].displayName, "5-hour")
        XCTAssertEqual(snapshot.limitWindows[1].usedPercent, 87)
    }

    func testLocalSnapshotModeRequiresConfiguredPath() async {
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            isEnabled: true,
            sourceMode: .localSnapshot
        )

        do {
            _ = try await adapter.fetchSnapshot(account: account)
            XCTFail("Expected missing local snapshot path to throw.")
        } catch let error as ProviderAdapterError {
            XCTAssertEqual(error.providerID, "claude-code")
            XCTAssertEqual(error.message, "Claude Code local snapshot path is not configured.")
        } catch {
            XCTFail("Expected ProviderAdapterError, got \(error).")
        }
    }

    func testLocalSnapshotModeRejectsInvalidLimitWindowPercentage() async throws {
        let fileURL = try writeSnapshot(
            """
            {
              "schemaVersion": 1,
              "limitWindows": [
                {
                  "id": "weekly",
                  "displayName": "Weekly",
                  "usedPercent": 120
                }
              ],
              "lastUpdatedAt": "2026-07-07T10:15:00Z"
            }
            """
        )
        let adapter = ClaudeCodeProviderAdapter()
        let account = ProviderAccount(
            providerID: "claude-code",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: fileURL.path
        )

        do {
            _ = try await adapter.fetchSnapshot(account: account)
            XCTFail("Expected invalid limit window percentage to throw.")
        } catch let error as ProviderAdapterError {
            XCTAssertEqual(error.providerID, "claude-code")
            XCTAssertEqual(error.message, "Claude Code local snapshot limit window 'Weekly' usedPercent must be between 0 and 100.")
        } catch {
            XCTFail("Expected ProviderAdapterError, got \(error).")
        }
    }

    private func writeSnapshot(_ json: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("claude-code.json")
        try Data(json.utf8).write(to: fileURL)
        return fileURL
    }
}
