import Foundation
import XCTest
@testable import AILimitBarCore

final class CodexAppServerClientTests: XCTestCase {
    func testAutomaticCandidatesUsePathBeforeStandardLocationsAndDeduplicate() {
        let home = URL(fileURLWithPath: "/tmp/codex-home")

        let candidates = CodexExecutableLocator.automaticCandidates(
            path: "/custom/bin:/opt/homebrew/bin:/custom/bin",
            homeDirectory: home
        )

        XCTAssertEqual(candidates.map(\.path), [
            "/custom/bin/codex",
            "/opt/homebrew/bin/codex",
            "/tmp/codex-home/.local/bin/codex",
            "/tmp/codex-home/.local/share/mise/shims/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ])
    }

    func testConfiguredExecutableTakesPrecedence() throws {
        let executableURL = try temporaryExecutable(
            body: "#!/bin/sh\nexit 0\n",
            filename: "codex"
        )

        let located = try CodexExecutableLocator().locate(executablePath: executableURL.path)

        XCTAssertEqual(located, executableURL)
    }

    func testConfiguredMissingExecutableDoesNotFallbackToAutomaticDiscovery() {
        XCTAssertThrowsError(
            try CodexExecutableLocator().locate(executablePath: "/missing/codex")
        ) {
            XCTAssertEqual($0 as? CodexAppServerClientError, .configuredExecutableNotFound)
        }
    }

    func testProcessClientCompletesJSONLHandshakeAndReadsRateLimits() async throws {
        let executableURL = try temporaryExecutable(
            body: """
            #!/bin/sh
            IFS= read -r initialize
            printf '%s\\n' '{"id":1,"result":{}}'
            IFS= read -r initialized
            IFS= read -r rate_limits
            printf '%s\\n' '{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":37,"windowDurationMins":300,"resetsAt":1900000000},"secondary":null}}}'
            """,
            filename: "codex"
        )
        let client = ProcessCodexAppServerClient(timeout: 2)

        let payload = try await client.fetchRateLimits(executablePath: executableURL.path)

        XCTAssertEqual(payload.rateLimits.limitID, "codex")
        XCTAssertEqual(payload.rateLimits.primary?.usedPercent, 37)
        XCTAssertNil(payload.rateLimits.secondary)
    }

    private func temporaryExecutable(body: String, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executableURL = directory.appendingPathComponent(filename)
        try Data(body.utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )
        return executableURL
    }
}
