#if DEBUG
import AILimitBarCore
import Foundation
import XCTest
@testable import AILimitBar

final class KeychainVerificationCommandTests: XCTestCase {
    func testCreateFailsClosedWithoutReplacingAnExistingCredentialFreeAccount() throws {
        let directory = temporaryDirectory()
        let existingAccount = ProviderAccount(
            providerID: "mock",
            accountID: "existing",
            displayName: "Existing account",
            isEnabled: true
        )
        let database = try AppDatabase(directory: directory)
        let accountStore = DatabaseProviderConfigurationStore(database: database)
        try accountStore.save([existingAccount])
        let keychain = VerificationKeychainService()
        let command = KeychainVerificationCommand(
            operation: .create,
            storageDirectory: directory,
            keychainService: keychain
        )

        XCTAssertThrowsError(try command.run()) {
            XCTAssertEqual($0 as? CredentialStoreError, .storageUnavailable)
        }
        XCTAssertEqual(
            accountStore.load(knownProviderIDs: ["mock"]).accounts,
            [existingAccount]
        )
        XCTAssertEqual(try accountStore.accountCount(), 1)
        XCTAssertTrue(keychain.isEmpty)
    }

    func testReplaceAndDeleteRejectAnyAdditionalAccount() throws {
        let directory = temporaryDirectory()
        let keychain = VerificationKeychainService()
        let create = KeychainVerificationCommand(
            operation: .create,
            storageDirectory: directory,
            keychainService: keychain
        )
        let reference = try XCTUnwrap(create.run())
        let originalValue = try keychain.value(reference: reference)

        let database = try AppDatabase(directory: directory)
        let accountStore = DatabaseProviderConfigurationStore(database: database)
        let temporaryAccount = try XCTUnwrap(
            accountStore.load(
                knownProviderIDs: ["keychain-verification"]
            ).accounts.first
        )
        let unrelatedAccount = ProviderAccount(
            providerID: "mock",
            accountID: "existing",
            displayName: "Existing account",
            isEnabled: true
        )
        try accountStore.save([temporaryAccount, unrelatedAccount])

        for operation in [
            KeychainVerificationCommand.Operation.replace,
            .delete
        ] {
            let command = KeychainVerificationCommand(
                operation: operation,
                storageDirectory: directory,
                keychainService: keychain
            )
            XCTAssertThrowsError(try command.run()) {
                XCTAssertEqual($0 as? CredentialStoreError, .storageUnavailable)
            }
        }

        XCTAssertEqual(try accountStore.accountCount(), 2)
        XCTAssertEqual(try keychain.value(reference: reference), originalValue)
    }

    func testDebugStagingUsesAuthorizedAppleDevelopmentSigningForDPK() throws {
        let script = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("script/stage_app_bundle.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(script.contains("-allowProvisioningUpdates"))
        XCTAssertTrue(script.contains("-allowProvisioningDeviceRegistration"))
        XCTAssertTrue(script.contains("embedded.provisionprofile"))
        XCTAssertTrue(script.contains("Apple Development:"))
        XCTAssertTrue(script.contains("com.apple.application-identifier"))
        XCTAssertTrue(script.contains("keychain-access-groups"))
        XCTAssertTrue(script.contains("--entitlements \"$SIGNING_ENTITLEMENTS\""))
        XCTAssertTrue(script.contains("codesign --verify --deep --strict"))
        XCTAssertTrue(
            script.contains(
                "DEVELOPMENT_TEAM=\"${AILIMITBAR_DEVELOPMENT_TEAM:-}\""
            )
        )
        XCTAssertTrue(
            script.contains(
                "error: DEBUG staging requires AILIMITBAR_DEVELOPMENT_TEAM."
            )
        )
        XCTAssertTrue(
            script.contains(
                "AILIMITBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID"
            )
        )
        XCTAssertFalse(script.contains("LOCAL_AD_HOC_REQUIREMENT"))
        XCTAssertFalse(script.contains("--requirements"))
    }

    func testLocalSigningSupportRequestsOnlyTheAppDefaultKeychainGroup() throws {
        let supportDirectory = repositoryRoot
            .appendingPathComponent("Support/LocalSigning")
        let entitlements = try String(
            contentsOf: supportDirectory
                .appendingPathComponent("AILimitBarLocalSigning.entitlements"),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: supportDirectory
                .appendingPathComponent(
                    "AILimitBarLocalSigning.xcodeproj/project.pbxproj"
                ),
            encoding: .utf8
        )

        XCTAssertTrue(entitlements.contains("<key>keychain-access-groups</key>"))
        XCTAssertTrue(
            entitlements.contains(
                "$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)"
            )
        )
        XCTAssertFalse(entitlements.contains("application-identifier"))
        XCTAssertFalse(entitlements.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(project.contains("com.apple.Keychain"))
        XCTAssertFalse(project.contains("DEVELOPMENT_TEAM ="))
        XCTAssertTrue(
            project.contains(
                "PRODUCT_BUNDLE_IDENTIFIER = io.github.Prontsevich.AILimitBar;"
            )
        )
        XCTAssertTrue(project.contains("CODE_SIGN_STYLE = Automatic;"))
        XCTAssertTrue(project.contains("CODE_SIGN_IDENTITY = \"Apple Development\";"))
    }

    func testSigningDocumentationUsesOnlyExplicitTeamPlaceholder() throws {
        let agents = try String(
            contentsOf: repositoryRoot.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        let plan = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/plan.md"),
            encoding: .utf8
        )
        let contributing = try String(
            contentsOf: repositoryRoot.appendingPathComponent("CONTRIBUTING.md"),
            encoding: .utf8
        )

        for document in [agents, plan, contributing] {
            XCTAssertTrue(
                document.contains(
                    "AILIMITBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID"
                )
            )
        }
        XCTAssertTrue(
            agents.contains(
                "Release staging remains ad-hoc and explicitly non-credential-capable"
            )
        )
        XCTAssertTrue(contributing.contains("Apple Development"))
        XCTAssertTrue(contributing.contains("Xcode-managed provisioning profile"))
        XCTAssertTrue(
            contributing.contains(
                "Release staging remains ad-hoc and non-credential-capable"
            )
        )
    }

    func testReleaseStagingIsExplicitlyNonCredentialCapable() throws {
        let script = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("script/stage_app_bundle.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(
            script.contains(
                "rm -f \"$APP_CONTENTS/embedded.provisionprofile\""
            )
        )
        XCTAssertTrue(
            script.contains(
                "error: ad-hoc release must remain non-credential-capable"
            )
        )
        XCTAssertTrue(
            script.contains(
                "Staged $APP_BUNDLE (non-credential-capable ad-hoc release)"
            )
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private final class VerificationKeychainService: KeychainService, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: String] = [:]

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return items.isEmpty
    }

    func value(reference: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let value = items[reference] else {
            throw KeychainServiceError.credentialNotFound
        }
        return value
    }

    func createCredential(
        _ credential: CredentialSecret,
        reference: String
    ) throws {
        let value = try credential.withUTF8String { $0 }
        lock.lock()
        defer { lock.unlock() }
        guard items[reference] == nil else {
            throw KeychainServiceError.duplicateReference
        }
        items[reference] = value
    }

    func readCredential(reference: String) throws -> CredentialSecret {
        try CredentialSecret(value(reference: reference))
    }

    func replaceCredential(
        _ credential: CredentialSecret,
        reference: String
    ) throws {
        let value = try credential.withUTF8String { $0 }
        lock.lock()
        defer { lock.unlock() }
        guard items[reference] != nil else {
            throw KeychainServiceError.credentialNotFound
        }
        items[reference] = value
    }

    func deleteCredential(reference: String) throws {
        lock.lock()
        items.removeValue(forKey: reference)
        lock.unlock()
    }
}
#endif
