import AILimitBarCore
import Foundation
import XCTest
@testable import AILimitBar

final class UITestHostTests: XCTestCase {
    func testProductionLaunchArgumentsDoNotEnableHost() {
        let options = AppLaunchOptions(
            arguments: ["/path/to/AILimitBar"],
            bundleIdentifier: "io.github.Prontsevich.AILimitBar"
        )

        XCTAssertNil(options.storageDirectory)
        XCTAssertNil(options.uiTestHostConfiguration)
    }

    func testHostBundleUsesSafeDefaultConfiguration() throws {
        let configuration = try XCTUnwrap(UITestHostConfiguration.parse(
            arguments: ["/path/to/AILimitBarTest", "-psn_0_12345"],
            bundleIdentifier: UITestHostConfiguration.bundleIdentifier
        ))

        XCTAssertEqual(configuration, .defaultConfiguration)
        XCTAssertEqual(configuration.scenario, .dashboardHealthy)
        XCTAssertEqual(configuration.language, .english)
        XCTAssertEqual(configuration.appearance, .dark)
        XCTAssertEqual(configuration.dashboardHeight, .standard)
    }

    func testHostArgumentsResolveEveryVariant() throws {
        let configuration = try XCTUnwrap(UITestHostConfiguration.parse(
            arguments: [
                "/path/to/AILimitBar",
                UITestHostConfiguration.modeArgument,
                UITestHostScenario.dashboardMixed.rawValue,
                UITestHostConfiguration.languageArgument,
                UITestHostLanguage.russian.rawValue,
                UITestHostConfiguration.appearanceArgument,
                UITestHostAppearance.light.rawValue,
                UITestHostConfiguration.heightArgument,
                DashboardHeightPreset.tall.rawValue
            ],
            bundleIdentifier: "io.github.Prontsevich.AILimitBar"
        ))

        XCTAssertEqual(configuration.scenario, .dashboardMixed)
        XCTAssertEqual(configuration.language, .russian)
        XCTAssertEqual(configuration.appearance, .light)
        XCTAssertEqual(configuration.dashboardHeight, .tall)
    }

    func testHostParserRejectsMissingInvalidAndDetachedValues() {
        XCTAssertThrowsError(try UITestHostConfiguration.parse(
            arguments: ["app", UITestHostConfiguration.modeArgument],
            bundleIdentifier: nil
        )) { error in
            XCTAssertEqual(
                error as? UITestHostConfigurationError,
                .missingValue(UITestHostConfiguration.modeArgument)
            )
        }

        XCTAssertThrowsError(try UITestHostConfiguration.parse(
            arguments: ["app", UITestHostConfiguration.modeArgument, "unknown"],
            bundleIdentifier: nil
        ))

        XCTAssertThrowsError(try UITestHostConfiguration.parse(
            arguments: ["app", UITestHostConfiguration.languageArgument, "en"],
            bundleIdentifier: nil
        )) { error in
            XCTAssertEqual(error as? UITestHostConfigurationError, .hostModeRequired)
        }
    }

    func testEveryScenarioBuildsPrivacySafeSyntheticFixtures() {
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)

        for scenario in UITestHostScenario.allCases {
            let fixture = UITestHostFixture.make(scenario: scenario, anchor: anchor)
            XCTAssertTrue(fixture.adapters.allSatisfy { $0 is UITestScriptedProviderAdapter })
            XCTAssertTrue(fixture.accounts.allSatisfy {
                $0.executablePath == nil && $0.webDataStoreID == nil && $0.localSnapshotPath == nil
            })
            XCTAssertTrue(fixture.snapshots.allSatisfy {
                $0.source == "Synthetic UI test fixture"
            })
        }
    }

    func testMixedFixtureContainsEveryRequiredPresentationState() {
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = UITestHostFixture.make(scenario: .dashboardMixed, anchor: anchor)

        XCTAssertEqual(fixture.accounts.count, 7)
        XCTAssertTrue(fixture.snapshots.contains(where: { $0.status == .warning }))
        XCTAssertEqual(fixture.refreshIssues.count, 1)
        XCTAssertTrue(fixture.accounts.contains(where: { $0.sourceMode == .manual }))
        XCTAssertTrue(fixture.accounts.contains(where: { account in
            account.providerID == "ui-test-empty" &&
                !fixture.snapshots.contains(where: { $0.id == account.id })
        }))
        let stale = fixture.snapshots.first { $0.accountID == "stale" }
        XCTAssertNotNil(stale)
        XCTAssertGreaterThan(
            anchor.timeIntervalSince(stale?.lastUpdatedAt ?? anchor),
            RefreshInterval.manualOnly.staleAfter
        )
        XCTAssertTrue(
            stale?.limitWindows.allSatisfy { ($0.resetAt ?? anchor) > anchor } == true
        )
    }

    func testOpenRouterFixturePreservesNativeHierarchyAndPrivacyBoundary() throws {
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = UITestHostFixture.make(
            scenario: .dashboardOpenRouter,
            anchor: anchor
        )
        let account = try XCTUnwrap(fixture.accounts.first)
        let snapshot = try XCTUnwrap(fixture.nativeCapacitySnapshots[account.id])
        let credentials = try XCTUnwrap(fixture.credentialContexts[account.id])
        let diagnostics = try XCTUnwrap(fixture.credentialDiagnostics[account.id])

        XCTAssertEqual(account.providerID, OpenRouterProviderContract.providerID)
        XCTAssertEqual(
            snapshot.metrics.filter { $0.metricID == "account-credits" }.count,
            1
        )
        XCTAssertEqual(credentials.filter { $0.slot.role == .ordinary }.count, 3)
        XCTAssertEqual(credentials.filter { $0.slot.role == .management }.count, 1)
        XCTAssertEqual(diagnostics.map(\.code), [.authentication])
        XCTAssertTrue(credentials.allSatisfy {
            $0.slot.keychainReference.hasPrefix("synthetic-reference-")
                && !$0.slot.keychainReference.contains("sk-")
        })

        let presentation = OpenRouterCapacityPresentation(
            account: account,
            snapshot: snapshot,
            credentialContexts: credentials,
            refreshStates: fixture.credentialRefreshStates[account.id] ?? [],
            diagnostics: diagnostics,
            now: anchor,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(presentation.state, .partial)
        XCTAssertTrue(presentation.sharedCredits.valueText.contains("USD 87.5 remaining"))
        XCTAssertTrue(presentation.sharedCredits.valueText.contains("USD 100 total"))
        XCTAssertFalse(presentation.sharedCredits.valueText.contains("%"))
        XCTAssertTrue(presentation.credentials.contains { $0.state == .stale })
        XCTAssertTrue(presentation.credentials.contains { $0.state == .partial })
        XCTAssertTrue(presentation.credentials.contains {
            $0.metrics.contains { $0.state == .unknown }
                && $0.metrics.contains { $0.state == .unlimited }
        })
    }

    @MainActor
    func testOpenRouterHostRefreshPreservesSyntheticNativeFixture() async throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ai-limitbar-ui-test-openrouter-\(UUID().uuidString)"
            )
        let options = AppLaunchOptions(
            arguments: [
                "app",
                UITestHostConfiguration.modeArgument,
                UITestHostScenario.dashboardOpenRouter.rawValue,
                AppLaunchOptions.storageDirectoryArgument,
                storageDirectory.path
            ],
            bundleIdentifier: UITestHostConfiguration.bundleIdentifier
        )
        let runtime = AppRuntime(launchOptions: options)
        let session = try XCTUnwrap(runtime.uiTestHostSession)
        defer { session.cleanup() }
        let account = try XCTUnwrap(runtime.appModel.providerAccounts.first)
        let before = try XCTUnwrap(
            runtime.appModel.openRouterCapacityPresentation(
                for: account,
                locale: Locale(identifier: "en_US")
            )
        )

        runtime.appModel.refresh()
        await runtime.appModel.waitForRefreshCompletionForTesting()

        let after = try XCTUnwrap(
            runtime.appModel.openRouterCapacityPresentation(
                for: account,
                locale: Locale(identifier: "en_US")
            )
        )
        XCTAssertEqual(after.sharedCredits, before.sharedCredits)
        XCTAssertEqual(after.credentials, before.credentials)
        XCTAssertEqual(after.credentials.count, 3)
        XCTAssertNil(runtime.appModel.accountRefreshIssues[account.id])
    }

    @MainActor
    func testHostRuntimeUsesIsolatedStoragePreferencesAndNoStatusItem() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-limitbar-ui-test-unit-\(UUID().uuidString)")
        let options = AppLaunchOptions(
            arguments: [
                "app",
                UITestHostConfiguration.modeArgument,
                UITestHostScenario.dashboardHealthy.rawValue,
                AppLaunchOptions.storageDirectoryArgument,
                storageDirectory.path
            ],
            bundleIdentifier: "io.github.Prontsevich.AILimitBar"
        )
        let runtime = AppRuntime(launchOptions: options)
        let session = try XCTUnwrap(runtime.uiTestHostSession)

        XCTAssertFalse(runtime.ownsMenuBarStatusItemController)
        XCTAssertEqual(runtime.appModel.refreshSettings.interval, .manualOnly)
        XCTAssertEqual(runtime.appModel.userDefaults, session.userDefaults)
        XCTAssertEqual(runtime.appLanguagePreference.language, .english)
        XCTAssertEqual(
            session.userDefaults.string(forKey: DashboardHeightPreset.storageKey),
            DashboardHeightPreset.standard.rawValue
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageDirectory.path))

        let suiteName = session.userDefaultsSuiteName
        session.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageDirectory.path))
        XCTAssertTrue(
            UserDefaults.standard.persistentDomain(forName: suiteName)?.isEmpty ?? true
        )
    }

    func testDirtyEditorScenarioStartsEditingSyntheticAccount() {
        let workspace = UITestHostScenario.settingsDirtyEditor
            .initialSettingsWorkspace(firstAccountID: "ui-test-live:primary")

        XCTAssertEqual(workspace.selection, .accounts)
        XCTAssertEqual(workspace.editorSession.selectedAccountID, "ui-test-live:primary")
        XCTAssertEqual(workspace.editorSession.mode, .editing)
        XCTAssertFalse(workspace.editorSession.isDirty)
        XCTAssertEqual(
            UITestHostScenario.settings.initialSettingsWorkspace(firstAccountID: "account"),
            SettingsWorkspaceState()
        )
        XCTAssertEqual(
            UITestHostScenario.settingsOpenRouter.initialSettingsWorkspace(
                firstAccountID: "openrouter:account"
            ),
            SettingsWorkspaceState()
        )
    }
}
