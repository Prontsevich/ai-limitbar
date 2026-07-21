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
    }
}
