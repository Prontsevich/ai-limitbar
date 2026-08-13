#if DEBUG
import Foundation
import XCTest
@testable import AILimitBar
@testable import AILimitBarCore

@MainActor
final class MiniMaxAppIntegrationTests: XCTestCase {
    func testProductionCompositionRefreshesConfiguredMiniMaxAccount() async throws {
        let directory = temporaryDirectory()
        let keychain = MiniMaxAppIntegrationKeychain()
        let client = InjectedMiniMaxAPIClient()
        let model = AppModel(
            storageDirectory: directory,
            userDefaults: isolatedDefaults(),
            refreshCoordinator: ProviderRefreshCoordinator(
                retryPolicy: ProviderRetryPolicy(maxAttempts: 1, initialDelay: 0)
            ),
            miniMaxAPIClient: client,
            credentialKeychainService: keychain
        )
        let account = try XCTUnwrap(
            model.addAccount(providerID: "minimax", displayName: "Local Team")
        )
        try configureCredential(model: model, account: account)

        let initialCallCount = await client.callCount
        XCTAssertEqual(initialCallCount, 0)
        model.refreshAccount(
            providerID: account.providerID,
            accountID: account.accountID
        )
        await model.waitForRefreshCompletionForTesting()

        let refreshedCallCount = await client.callCount
        XCTAssertEqual(refreshedCallCount, 1)
        let projection = try XCTUnwrap(model.snapshot(for: account))
        XCTAssertEqual(projection.status, .ok)
        XCTAssertNil(projection.usedPercent)
        XCTAssertTrue(projection.limitWindows.isEmpty)
        XCTAssertFalse(projection.source.contains(InjectedMiniMaxAPIClient.rawMarker))
        XCTAssertFalse(projection.source.contains(MiniMaxAppIntegrationKeychain.secretMarker))

        let native = try XCTUnwrap(
            try model.nativeCapacitySnapshotStore.load(
                providerID: account.providerID,
                accountID: account.accountID,
                surface: MiniMaxProviderContract.surface,
                sources: MiniMaxProviderContract.sources
            )
        )
        XCTAssertEqual(native.savedAccountID, account.accountID)
        XCTAssertEqual(
            native.metrics.map(\.metricID),
            ["quota-category-a.current"]
        )
        XCTAssertEqual(native.metrics.map(\.accountContextID), ["team-root"])
        XCTAssertEqual(
            native.metrics.map(\.displayName),
            ["Included usage — current rolling window"]
        )
        XCTAssertTrue(model.diagnosticStore.load().allSatisfy {
            !$0.message.contains(InjectedMiniMaxAPIClient.rawMarker)
                && !$0.message.contains(MiniMaxAppIntegrationKeychain.secretMarker)
        })
        try assertStorage(
            at: directory,
            excludes: [
                InjectedMiniMaxAPIClient.rawMarker,
                MiniMaxAppIntegrationKeychain.secretMarker,
                "unrecognized-category-marker",
                "general",
                "video"
            ]
        )
    }

    func testProductionQuotaCategoryMappingUsesOnlyLocalOutputLabels() throws {
        let mapping = MiniMaxProviderContract.reviewedQuotaCategories
        let categoryA = try XCTUnwrap(
            mapping.reviewedCategory(forProviderIdentifier: "general")
        )
        let categoryB = try XCTUnwrap(
            mapping.reviewedCategory(forProviderIdentifier: "video")
        )

        XCTAssertEqual(categoryA.stableID, "quota-category-a")
        XCTAssertEqual(categoryA.displayName, "Token Plan capacity A")
        XCTAssertEqual(categoryB.stableID, "quota-category-b")
        XCTAssertEqual(categoryB.displayName, "Token Plan capacity B")
        XCTAssertNil(mapping.reviewedCategory(
            forProviderIdentifier: "unknown-category"
        ))
        XCTAssertNil(mapping.reviewedCategory(forProviderIdentifier: "MiniMax-M2"))
        XCTAssertNil(mapping.reviewedCategory(forProviderIdentifier: "MiniMax-M*"))
        XCTAssertFalse(categoryA.displayName.contains("general"))
        XCTAssertFalse(categoryB.displayName.contains("video"))
    }

    func testDeletingMiniMaxAccountRemovesOnlyItsCredentials() throws {
        let directory = temporaryDirectory()
        let keychain = MiniMaxAppIntegrationKeychain()
        let model = AppModel(
            storageDirectory: directory,
            userDefaults: isolatedDefaults(),
            miniMaxAPIClient: InjectedMiniMaxAPIClient(),
            credentialKeychainService: keychain
        )
        let deletedAccount = try XCTUnwrap(
            model.addAccount(providerID: "minimax", displayName: "Delete Me")
        )
        let retainedAccount = try XCTUnwrap(
            model.addAccount(providerID: "minimax", displayName: "Keep Me")
        )
        try configureCredential(model: model, account: deletedAccount)
        try configureCredential(model: model, account: retainedAccount)
        let deletedReference = try XCTUnwrap(
            model.accountCredentialStore.loadCredentialContexts(
                providerID: deletedAccount.providerID,
                accountID: deletedAccount.accountID
            ).first?.slot.keychainReference
        )
        let retainedReference = try XCTUnwrap(
            model.accountCredentialStore.loadCredentialContexts(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).first?.slot.keychainReference
        )
        let occurredAt = Date(timeIntervalSince1970: 60_000)
        try seedRefreshMetadata(
            model: model,
            account: deletedAccount,
            occurredAt: occurredAt
        )
        try seedRefreshMetadata(
            model: model,
            account: retainedAccount,
            occurredAt: occurredAt
        )

        model.deleteAccount(
            providerID: deletedAccount.providerID,
            accountID: deletedAccount.accountID
        )

        XCTAssertEqual(model.providerAccounts, [retainedAccount])
        let persisted = DatabaseProviderConfigurationStore(
            database: try AppDatabase(directory: directory)
        ).load(knownProviderIDs: ["minimax"])
        XCTAssertEqual(persisted.accounts, [retainedAccount])
        XCTAssertTrue(
            try model.accountCredentialStore.loadContexts(
                providerID: deletedAccount.providerID,
                accountID: deletedAccount.accountID
            ).isEmpty
        )
        XCTAssertTrue(
            try model.accountCredentialStore.loadCredentialContexts(
                providerID: deletedAccount.providerID,
                accountID: deletedAccount.accountID
            ).isEmpty
        )
        XCTAssertFalse(keychain.containsCredential(reference: deletedReference))
        XCTAssertTrue(keychain.containsCredential(reference: retainedReference))
        XCTAssertTrue(
            model.diagnosticStore.loadRefreshStates().filter {
                $0.providerID == deletedAccount.providerID
                    && $0.accountID == deletedAccount.accountID
            }.isEmpty
        )
        XCTAssertTrue(
            model.diagnosticStore.load().filter {
                $0.providerID == deletedAccount.providerID
                    && $0.accountID == deletedAccount.accountID
            }.isEmpty
        )
        XCTAssertTrue(
            try model.accountCredentialStore.loadRefreshStates(
                providerID: deletedAccount.providerID,
                accountID: deletedAccount.accountID
            ).isEmpty
        )
        XCTAssertTrue(
            try model.accountCredentialStore.loadDiagnostics(
                providerID: deletedAccount.providerID,
                accountID: deletedAccount.accountID
            ).isEmpty
        )
        XCTAssertEqual(
            model.diagnosticStore.loadRefreshStates().filter {
                $0.providerID == retainedAccount.providerID
                    && $0.accountID == retainedAccount.accountID
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnosticStore.load().filter {
                $0.providerID == retainedAccount.providerID
                    && $0.accountID == retainedAccount.accountID
            }.count,
            1
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadRefreshStates(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).count,
            1
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadDiagnostics(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).count,
            1
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadCredentialContexts(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).map(\.slot.keychainReference),
            [retainedReference]
        )
    }

    func testMiniMaxDeletionKeychainFailureKeepsRecoverableAccountData() throws {
        let directory = temporaryDirectory()
        let keychain = MiniMaxAppIntegrationKeychain()
        let model = AppModel(
            storageDirectory: directory,
            userDefaults: isolatedDefaults(),
            miniMaxAPIClient: InjectedMiniMaxAPIClient(),
            credentialKeychainService: keychain
        )
        let failedAccount = try XCTUnwrap(
            model.addAccount(providerID: "minimax", displayName: "Retry Me")
        )
        let retainedAccount = try XCTUnwrap(
            model.addAccount(providerID: "minimax", displayName: "Keep Me")
        )
        try configureCredential(model: model, account: failedAccount)
        try configureCredential(model: model, account: retainedAccount)
        let failedReference = try XCTUnwrap(
            model.accountCredentialStore.loadCredentialContexts(
                providerID: failedAccount.providerID,
                accountID: failedAccount.accountID
            ).first?.slot.keychainReference
        )
        let retainedReference = try XCTUnwrap(
            model.accountCredentialStore.loadCredentialContexts(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).first?.slot.keychainReference
        )
        let occurredAt = Date(timeIntervalSince1970: 70_000)
        try seedRefreshMetadata(
            model: model,
            account: failedAccount,
            occurredAt: occurredAt
        )
        try seedRefreshMetadata(
            model: model,
            account: retainedAccount,
            occurredAt: occurredAt
        )
        keychain.failDeletion(for: failedReference)

        model.deleteAccount(
            providerID: failedAccount.providerID,
            accountID: failedAccount.accountID
        )

        XCTAssertEqual(model.providerAccounts, [failedAccount, retainedAccount])
        let persisted = DatabaseProviderConfigurationStore(
            database: try AppDatabase(directory: directory)
        ).load(knownProviderIDs: ["minimax"])
        XCTAssertEqual(persisted.accounts, [failedAccount, retainedAccount])
        let failedContexts = try model.accountCredentialStore.loadCredentialContexts(
            providerID: failedAccount.providerID,
            accountID: failedAccount.accountID
        )
        XCTAssertEqual(failedContexts.map(\.slot.keychainReference), [failedReference])
        XCTAssertEqual(
            failedContexts.map(\.slot.lifecycleState),
            [.pendingDeletion]
        )
        XCTAssertTrue(keychain.containsCredential(reference: failedReference))
        XCTAssertTrue(keychain.containsCredential(reference: retainedReference))
        XCTAssertEqual(
            try model.accountCredentialStore.loadRefreshStates(
                providerID: failedAccount.providerID,
                accountID: failedAccount.accountID
            ).count,
            1
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadDiagnostics(
                providerID: failedAccount.providerID,
                accountID: failedAccount.accountID
            ).count,
            1
        )
        XCTAssertEqual(
            model.diagnosticStore.loadRefreshStates().filter {
                $0.providerID == failedAccount.providerID
                    && $0.accountID == failedAccount.accountID
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnosticStore.load().filter {
                $0.providerID == failedAccount.providerID
                    && $0.accountID == failedAccount.accountID
            }.count,
            1
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadCredentialContexts(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).map(\.slot.keychainReference),
            [retainedReference]
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadRefreshStates(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).count,
            1
        )
        XCTAssertEqual(
            try model.accountCredentialStore.loadDiagnostics(
                providerID: retainedAccount.providerID,
                accountID: retainedAccount.accountID
            ).count,
            1
        )
        XCTAssertEqual(
            model.diagnosticStore.loadRefreshStates().filter {
                $0.providerID == retainedAccount.providerID
                    && $0.accountID == retainedAccount.accountID
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnosticStore.load().filter {
                $0.providerID == retainedAccount.providerID
                    && $0.accountID == retainedAccount.accountID
            }.count,
            1
        )
    }

    private func configureCredential(
        model: AppModel,
        account: ProviderAccount
    ) throws {
        try model.accountCredentialStore.createContext(
            ProviderAccountContextConfiguration(
                providerID: account.providerID,
                accountID: account.accountID,
                contextID: "team-root",
                kind: .team,
                displayName: "Configured Team",
                regionID: "global"
            )
        )
        try model.accountCredentialStore.createContext(
            ProviderAccountContextConfiguration(
                providerID: account.providerID,
                accountID: account.accountID,
                contextID: "credential-local",
                kind: .credential,
                displayName: "Subscription Key",
                regionID: "global",
                parentContextID: "team-root"
            )
        )
        try model.accountCredentialStore.createCredential(
            providerID: account.providerID,
            accountID: account.accountID,
            slotID: "subscription",
            contextID: "credential-local",
            role: .ordinary,
            credential: CredentialSecret(MiniMaxAppIntegrationKeychain.secretMarker)
        )
    }

    private func seedRefreshMetadata(
        model: AppModel,
        account: ProviderAccount,
        occurredAt: Date
    ) throws {
        try model.diagnosticStore.recordRefreshFailure(
            providerID: account.providerID,
            accountID: account.accountID,
            occurredAt: occurredAt
        )
        try model.diagnosticStore.replaceRefreshDiagnostics(
            providerID: account.providerID,
            accountID: account.accountID,
            occurredAt: occurredAt,
            messages: ["MiniMax refresh diagnostic."]
        )
        try model.accountCredentialStore.recordRefreshFailure(
            providerID: account.providerID,
            accountID: account.accountID,
            slotID: "subscription",
            code: .transientFailure,
            occurredAt: occurredAt
        )
    }

    private func assertStorage(
        at directory: URL,
        excludes markers: [String]
    ) throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        for url in urls where
            try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            let data = try Data(contentsOf: url)
            for marker in markers {
                XCTAssertNil(
                    data.range(of: Data(marker.utf8)),
                    "Persisted forbidden marker in \(url.lastPathComponent)."
                )
            }
        }
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "MiniMaxAppIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

private actor InjectedMiniMaxAPIClient: MiniMaxAPIClient {
    static let rawMarker = "raw-response-marker"

    private(set) var callCount = 0

    func fetchTokenPlanCapacity(
        credential: MiniMaxSubscriptionKey
    ) async throws -> MiniMaxCapacityResult {
        callCount += 1
        let observedAt = Date(timeIntervalSince1970: 50_000)
        return MiniMaxCapacityResult(
            observedAt: observedAt,
            metrics: [
                CapacityMetric(
                    metricID: "quota-category-a.current",
                    accountContextID: "credential-local",
                    sourceID: MiniMaxProviderContract.sourceID,
                    capability: "quota-windows",
                    displayName: "unrecognized-category-marker \(Self.rawMarker)",
                    availability: .known,
                    unit: CapacityUnit(
                        kind: .providerDefined,
                        providerUnitID: MiniMaxProviderContract.providerUnitID
                    ),
                    values: CapacityValues(
                        consumed: CapacityValue(value: 4, origin: .reported)
                    ),
                    window: CapacityWindow(
                        kind: .rolling,
                        durationSeconds: 18_000,
                        startsAt: observedAt,
                        endsAt: observedAt.addingTimeInterval(18_000),
                        nextTransition: CapacityTransition(
                            kind: .reset,
                            at: observedAt.addingTimeInterval(18_000)
                        )
                    ),
                    freshness: ObservationFreshness(observedAt: observedAt),
                    confidence: .live
                )
            ],
            diagnostics: []
        )
    }
}

private final class MiniMaxAppIntegrationKeychain:
    KeychainService,
    @unchecked Sendable
{
    static let secretMarker = "integration-secret-marker"

    private let lock = NSLock()
    private var values: [String: CredentialSecret] = [:]
    private var deletionFailures: Set<String> = []

    func createCredential(
        _ credential: CredentialSecret,
        reference: String
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard values[reference] == nil else {
            throw KeychainServiceError.duplicateReference
        }
        values[reference] = credential
    }

    func readCredential(reference: String) throws -> CredentialSecret {
        lock.lock()
        defer { lock.unlock() }
        guard let credential = values[reference] else {
            throw KeychainServiceError.credentialNotFound
        }
        return credential
    }

    func replaceCredential(
        _ credential: CredentialSecret,
        reference: String
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard values[reference] != nil else {
            throw KeychainServiceError.credentialNotFound
        }
        values[reference] = credential
    }

    func deleteCredential(reference: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !deletionFailures.contains(reference) else {
            throw KeychainServiceError.accessDenied
        }
        values.removeValue(forKey: reference)
    }

    func containsCredential(reference: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return values[reference] != nil
    }

    func failDeletion(for reference: String) {
        lock.lock()
        defer { lock.unlock() }
        deletionFailures.insert(reference)
    }
}
#endif
