import XCTest
@testable import AILimitBarCore

final class ProviderConfigurationTests: XCTestCase {
    func testProviderAccountRoundTripsLocalSnapshotSettings() throws {
        let account = ProviderAccount(
            providerID: "claude-code",
            accountID: "work",
            displayName: "Work",
            isEnabled: true,
            sourceMode: .localSnapshot,
            localSnapshotPath: "/Users/example/Library/Application Support/AI Limitbar/claude-code.json"
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(ProviderAccount.self, from: data)

        XCTAssertEqual(decoded, account)
        XCTAssertEqual(decoded.id, "claude-code:work")
    }

    func testProviderConfigurationStoreStartsEmptyWhenMissing() throws {
        let directory = try temporaryDirectory()

        let result = ProviderConfigurationStore(directory: directory).load(
            knownProviderIDs: ["mock", "claude-code"]
        )

        XCTAssertNil(result.warning)
        XCTAssertEqual(result.accounts, [])
    }

    func testProviderConfigurationStoreRoundTripsAccountSettings() throws {
        let directory = try temporaryDirectory()
        let accounts = [
            ProviderAccount(providerID: "mock", isEnabled: true),
            ProviderAccount(providerID: "claude-code", accountID: "work", displayName: "Work", isEnabled: true)
        ]
        let store = ProviderConfigurationStore(directory: directory)

        try store.save(accounts)
        let result = store.load(knownProviderIDs: ["mock", "claude-code"])

        XCTAssertEqual(result.accounts, accounts)
    }

    func testProviderConfigurationStorePreservesAccountOrder() throws {
        let directory = try temporaryDirectory()
        let accounts = [
            ProviderAccount(providerID: "claude-code", accountID: "work", displayName: "Work", isEnabled: true),
            ProviderAccount(providerID: "mock", accountID: "demo", displayName: "Demo", isEnabled: true),
            ProviderAccount(providerID: "claude-code", accountID: "personal", displayName: "Personal", isEnabled: true)
        ]
        let store = ProviderConfigurationStore(directory: directory)

        try store.save(accounts)
        let result = store.load(knownProviderIDs: ["mock", "claude-code"])

        XCTAssertEqual(result.accounts.map(\.id), [
            "claude-code:work",
            "mock:demo",
            "claude-code:personal"
        ])
    }

    func testProviderConfigurationStoreDeduplicatesByProviderScopedAccountKey() throws {
        let directory = try temporaryDirectory()
        let stored = [
            ProviderAccount(providerID: "mock", accountID: "default", displayName: "Mock", isEnabled: true),
            ProviderAccount(providerID: "claude-code", accountID: "default", displayName: "Claude", isEnabled: true),
            ProviderAccount(providerID: "mock", accountID: "default", displayName: "Duplicate", isEnabled: true)
        ]
        try ProviderConfigurationStore(directory: directory).save(stored)

        let result = ProviderConfigurationStore(directory: directory).load(
            knownProviderIDs: ["mock", "claude-code"]
        )

        XCTAssertEqual(result.accounts.map(\.id), [
            "mock:default",
            "claude-code:default"
        ])
    }

    func testProviderConfigurationStoreIgnoresUnknownProvidersWithoutAddingDefaults() throws {
        let directory = try temporaryDirectory()
        let stored = [
            ProviderAccount(providerID: "unknown", isEnabled: true),
            ProviderAccount(providerID: "claude-code", accountID: "work", displayName: "Work", isEnabled: true)
        ]
        try ProviderConfigurationStore(directory: directory).save(stored)

        let result = ProviderConfigurationStore(directory: directory).load(
            knownProviderIDs: ["mock", "claude-code"]
        )

        XCTAssertEqual(result.accounts.count, 1)
        XCTAssertEqual(result.accounts[0].providerID, "claude-code")
        XCTAssertEqual(result.accounts[0].accountID, "work")
        XCTAssertEqual(result.accounts[0].displayName, "Work")
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
