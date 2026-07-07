import XCTest
@testable import AILimitBarCore

final class ClaudeCodeProviderAdapterTests: XCTestCase {
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
        XCTAssertEqual(snapshot.confidence, .localEstimate)
        XCTAssertEqual(snapshot.source, "Claude Code local snapshot file")
        XCTAssertEqual(snapshot.warnings, ["Local estimate only; usage from other machines or Claude surfaces may be missing."])
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

    private func writeSnapshot(_ json: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("claude-code.json")
        try Data(json.utf8).write(to: fileURL)
        return fileURL
    }
}
