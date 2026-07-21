#if DEBUG
import AILimitBarCore
import AppKit
import Foundation
import SwiftUI

enum UITestHostScenario: String, CaseIterable {
    case dashboardEmpty = "dashboard-empty"
    case dashboardHealthy = "dashboard-healthy"
    case dashboardMixed = "dashboard-mixed"
    case settings
    case settingsDirtyEditor = "settings-dirty-editor"

    var initialSurface: UITestHostSurface {
        switch self {
        case .dashboardEmpty, .dashboardHealthy, .dashboardMixed:
            .dashboard
        case .settings, .settingsDirtyEditor:
            .settings
        }
    }

    func initialSettingsWorkspace(firstAccountID: String?) -> SettingsWorkspaceState {
        guard self == .settingsDirtyEditor, let firstAccountID else {
            return SettingsWorkspaceState()
        }
        return SettingsWorkspaceState(
            selection: .accounts,
            editorSession: AccountEditorSession(
                selectedAccountID: firstAccountID,
                mode: .editing,
                isDirty: false
            )
        )
    }
}

enum UITestHostSurface {
    case dashboard
    case settings
}

enum UITestHostLanguage: String, CaseIterable {
    case english = "en"
    case russian = "ru"

    var appLanguage: AppLanguage {
        switch self {
        case .english: .english
        case .russian: .russian
        }
    }
}

enum UITestHostAppearance: String, CaseIterable {
    case light
    case dark

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var appKitName: NSAppearance.Name {
        switch self {
        case .light: .aqua
        case .dark: .darkAqua
        }
    }
}

struct UITestHostConfiguration: Equatable {
    static let bundleIdentifier = "io.github.Prontsevich.AILimitBar.UITestHost"
    static let windowID = "ui-test-host"
    static let modeArgument = "--ui-test-host"
    static let languageArgument = "--ui-test-language"
    static let appearanceArgument = "--ui-test-appearance"
    static let heightArgument = "--ui-test-height"

    static let defaultConfiguration = UITestHostConfiguration(
        scenario: .dashboardHealthy,
        language: .english,
        appearance: .dark,
        dashboardHeight: .standard
    )

    let scenario: UITestHostScenario
    let language: UITestHostLanguage
    let appearance: UITestHostAppearance
    let dashboardHeight: DashboardHeightPreset

    static func parse(
        arguments: [String],
        bundleIdentifier: String?
    ) throws -> UITestHostConfiguration? {
        let isHostBundle = bundleIdentifier == Self.bundleIdentifier
        let hasModeArgument = arguments.contains(Self.modeArgument)
        let hasVariantArgument = arguments.contains {
            [languageArgument, appearanceArgument, heightArgument].contains($0)
        }

        guard isHostBundle || hasModeArgument else {
            if hasVariantArgument {
                throw UITestHostConfigurationError.hostModeRequired
            }
            return nil
        }

        var configuration = Self.defaultConfiguration
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            switch argument {
            case modeArgument:
                let value = try value(after: index, in: arguments, for: argument)
                guard let scenario = UITestHostScenario(rawValue: value) else {
                    throw UITestHostConfigurationError.invalidValue(argument: argument, value: value)
                }
                configuration = UITestHostConfiguration(
                    scenario: scenario,
                    language: configuration.language,
                    appearance: configuration.appearance,
                    dashboardHeight: configuration.dashboardHeight
                )
                index += 1
            case languageArgument:
                let value = try value(after: index, in: arguments, for: argument)
                guard let language = UITestHostLanguage(rawValue: value) else {
                    throw UITestHostConfigurationError.invalidValue(argument: argument, value: value)
                }
                configuration = UITestHostConfiguration(
                    scenario: configuration.scenario,
                    language: language,
                    appearance: configuration.appearance,
                    dashboardHeight: configuration.dashboardHeight
                )
                index += 1
            case appearanceArgument:
                let value = try value(after: index, in: arguments, for: argument)
                guard let appearance = UITestHostAppearance(rawValue: value) else {
                    throw UITestHostConfigurationError.invalidValue(argument: argument, value: value)
                }
                configuration = UITestHostConfiguration(
                    scenario: configuration.scenario,
                    language: configuration.language,
                    appearance: appearance,
                    dashboardHeight: configuration.dashboardHeight
                )
                index += 1
            case heightArgument:
                let value = try value(after: index, in: arguments, for: argument)
                guard let height = DashboardHeightPreset(rawValue: value) else {
                    throw UITestHostConfigurationError.invalidValue(argument: argument, value: value)
                }
                configuration = UITestHostConfiguration(
                    scenario: configuration.scenario,
                    language: configuration.language,
                    appearance: configuration.appearance,
                    dashboardHeight: height
                )
                index += 1
            case AppLaunchOptions.storageDirectoryArgument:
                _ = try value(after: index, in: arguments, for: argument)
                index += 1
            default:
                if argument.hasPrefix("--ui-test-") {
                    throw UITestHostConfigurationError.unsupportedArgument(argument)
                }
            }
            index += 1
        }
        return configuration
    }

    private static func value(
        after index: Int,
        in arguments: [String],
        for argument: String
    ) throws -> String {
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex,
              !arguments[valueIndex].hasPrefix("--")
        else {
            throw UITestHostConfigurationError.missingValue(argument)
        }
        return arguments[valueIndex]
    }
}

enum UITestHostConfigurationError: Error, Equatable, CustomStringConvertible {
    case hostModeRequired
    case missingValue(String)
    case invalidValue(argument: String, value: String)
    case unsupportedArgument(String)

    var description: String {
        switch self {
        case .hostModeRequired:
            "UI test variants require --ui-test-host."
        case let .missingValue(argument):
            "Missing value for \(argument)."
        case let .invalidValue(argument, value):
            "Unsupported value '\(value)' for \(argument)."
        case let .unsupportedArgument(argument):
            "Unsupported UI test host argument \(argument)."
        }
    }
}

@MainActor
final class UITestHostSession {
    let storageDirectory: URL
    let userDefaults: UserDefaults

    let userDefaultsSuiteName: String
    private var terminationObservation: NSObjectProtocol?
    private var hasCleanedUp = false

    init(
        storageDirectory requestedStorageDirectory: URL?,
        fileManager: FileManager = .default
    ) throws {
        let sessionID = UUID().uuidString
        let storageDirectory = requestedStorageDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent(
                "ai-limitbar-ui-test-\(sessionID)",
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )

        let suiteName = "\(UITestHostConfiguration.bundleIdentifier).\(sessionID)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            throw UITestHostSessionError.userDefaultsUnavailable
        }
        userDefaults.removePersistentDomain(forName: suiteName)

        self.storageDirectory = storageDirectory
        self.userDefaults = userDefaults
        userDefaultsSuiteName = suiteName
        terminationObservation = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cleanup()
            }
        }
    }

    func cleanup(fileManager: FileManager = .default) {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        try? fileManager.removeItem(at: storageDirectory)
        if let terminationObservation {
            NotificationCenter.default.removeObserver(terminationObservation)
            self.terminationObservation = nil
        }
    }

    isolated deinit {
        MainActor.assumeIsolated {
            cleanup()
        }
    }
}

enum UITestHostSessionError: Error {
    case userDefaultsUnavailable
}

struct UITestHostFixture {
    let adapters: [any ProviderAdapter]
    let accounts: [ProviderAccount]
    let snapshots: [UsageSnapshot]
    let refreshIssues: [String: AccountRefreshIssue]

    @MainActor
    func apply(to appModel: AppModel) {
        appModel.providerAccounts = accounts
        appModel.snapshots = snapshots
        appModel.accountRefreshIssues = refreshIssues
        appModel.providerRefreshStatuses = [:]
        appModel.refreshSettings = RefreshSettings(interval: .manualOnly)
        _ = appModel.saveConfiguration()
        _ = appModel.saveSnapshots()
        _ = appModel.saveRefreshSettings()
    }

    static func make(scenario: UITestHostScenario, anchor: Date) -> UITestHostFixture {
        let anchor = Date(timeIntervalSince1970: floor(anchor.timeIntervalSince1970 / 60) * 60)
        switch scenario {
        case .dashboardEmpty:
            return UITestHostFixture(adapters: [], accounts: [], snapshots: [], refreshIssues: [:])
        case .dashboardHealthy, .settings, .settingsDirtyEditor:
            return healthyFixture(anchor: anchor)
        case .dashboardMixed:
            return mixedFixture(anchor: anchor)
        }
    }

    private static func healthyFixture(anchor: Date) -> UITestHostFixture {
        let accounts = [
            account(providerID: "ui-test-live", accountID: "primary", displayName: "Synthetic Primary"),
            account(providerID: "ui-test-live", accountID: "secondary", displayName: "Synthetic Secondary")
        ]
        let snapshots = [
            snapshot(for: accounts[0], usedPercent: 42, anchor: anchor),
            snapshot(for: accounts[1], usedPercent: 17, anchor: anchor)
        ]
        return UITestHostFixture(
            adapters: [liveAdapter(snapshots: snapshots)],
            accounts: accounts,
            snapshots: snapshots,
            refreshIssues: [:]
        )
    }

    private static func mixedFixture(anchor: Date) -> UITestHostFixture {
        let accounts = [
            account(providerID: "ui-test-live", accountID: "healthy", displayName: "Healthy Synthetic"),
            account(providerID: "ui-test-live", accountID: "warning", displayName: "Warning Synthetic"),
            account(providerID: "ui-test-live", accountID: "stale", displayName: "Stale Synthetic"),
            account(providerID: "ui-test-live", accountID: "failed", displayName: "Failed Synthetic"),
            ProviderAccount(
                providerID: "ui-test-manual",
                accountID: "manual",
                displayName: "Manual Synthetic",
                isEnabled: true,
                sourceMode: .manual
            ),
            account(providerID: "ui-test-empty", accountID: "no-data", displayName: "No Data Synthetic"),
            account(
                providerID: "ui-test-live",
                accountID: "long-name",
                displayName: "Synthetic Account With A Deliberately Long Display Name"
            )
        ]
        let healthy = snapshot(for: accounts[0], usedPercent: 36, anchor: anchor)
        let warning = snapshot(
            for: accounts[1],
            status: .warning,
            usedPercent: 91,
            anchor: anchor
        )
        let stale = snapshot(
            for: accounts[2],
            usedPercent: 54,
            anchor: anchor,
            lastUpdatedAt: anchor.addingTimeInterval(-30 * 60 * 60)
        )
        let failed = snapshot(for: accounts[3], usedPercent: 63, anchor: anchor)
        let longName = snapshot(for: accounts[6], usedPercent: 28, anchor: anchor)
        let snapshots = [healthy, warning, stale, failed, longName]
        let failedIssue = AccountRefreshIssue(
            occurredAt: anchor.addingTimeInterval(-5 * 60),
            warnings: ["Synthetic refresh failure for UI verification."]
        )
        return UITestHostFixture(
            adapters: [
                liveAdapter(
                    snapshots: snapshots,
                    failures: [accounts[3].accountID: failedIssue.warnings[0]]
                ),
                UITestScriptedProviderAdapter(
                    id: "ui-test-manual",
                    displayName: "Synthetic Manual Provider",
                    capabilities: .manualOnly,
                    responses: [:]
                ),
                UITestScriptedProviderAdapter(
                    id: "ui-test-empty",
                    displayName: "Synthetic Empty Provider",
                    capabilities: liveCapabilities,
                    responses: [
                        accounts[5].accountID: .failure(
                            message: "Synthetic source has no data.",
                            delayNanoseconds: 0
                        )
                    ]
                )
            ],
            accounts: accounts,
            snapshots: snapshots,
            refreshIssues: [accounts[3].id: failedIssue]
        )
    }

    private static func account(
        providerID: String,
        accountID: String,
        displayName: String
    ) -> ProviderAccount {
        ProviderAccount(
            providerID: providerID,
            accountID: accountID,
            displayName: displayName,
            isEnabled: true,
            sourceMode: .appServer
        )
    }

    private static func snapshot(
        for account: ProviderAccount,
        status: UsageStatus = .ok,
        usedPercent: Double,
        anchor: Date,
        lastUpdatedAt: Date? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerID: account.providerID,
            accountID: account.accountID,
            accountDisplayName: account.displayName,
            displayName: "Synthetic Provider",
            status: status,
            planName: "Synthetic Plan",
            periodLabel: "Synthetic window",
            usedPercent: usedPercent,
            remainingLabel: "Synthetic remaining value",
            resetAt: anchor.addingTimeInterval(2 * 60 * 60),
            limitWindows: [
                UsageLimitWindow(
                    id: "weekly",
                    displayName: "Weekly",
                    usedPercent: usedPercent,
                    remainingLabel: "Synthetic remaining value",
                    resetAt: anchor.addingTimeInterval(2 * 60 * 60)
                ),
                UsageLimitWindow(
                    id: "rolling",
                    displayName: "5-hour",
                    usedPercent: max(0, usedPercent - 11),
                    remainingLabel: "Synthetic rolling value",
                    resetAt: anchor.addingTimeInterval(5 * 60 * 60)
                )
            ],
            lastUpdatedAt: lastUpdatedAt ?? anchor.addingTimeInterval(-60),
            confidence: .localEstimate,
            source: "Synthetic UI test fixture"
        )
    }

    private static func liveAdapter(
        snapshots: [UsageSnapshot],
        failures: [String: String] = [:]
    ) -> UITestScriptedProviderAdapter {
        var responses = Dictionary(uniqueKeysWithValues: snapshots.map {
            ($0.accountID, UITestScriptedProviderResponse.snapshot($0, delayNanoseconds: 150_000_000))
        })
        for (accountID, message) in failures {
            responses[accountID] = .failure(message: message, delayNanoseconds: 150_000_000)
        }
        return UITestScriptedProviderAdapter(
            id: "ui-test-live",
            displayName: "Synthetic Live Provider",
            capabilities: liveCapabilities,
            responses: responses
        )
    }

    private static let liveCapabilities = ProviderCapabilities(sources: [
        ProviderSourceCapability(
            mode: .appServer,
            kind: .live,
            summary: "Synthetic live data for UI verification."
        )
    ])
}

enum UITestScriptedProviderResponse: Sendable {
    case snapshot(UsageSnapshot, delayNanoseconds: UInt64)
    case failure(message: String, delayNanoseconds: UInt64)
}

struct UITestScriptedProviderAdapter: ProviderAdapter {
    let id: String
    let displayName: String
    let usageURL: URL? = nil
    let capabilities: ProviderCapabilities
    let responses: [String: UITestScriptedProviderResponse]

    func fetchSnapshot(account: ProviderAccount) async throws -> UsageSnapshot {
        guard let response = responses[account.accountID] else {
            throw ProviderAdapterError(
                providerID: id,
                message: "No synthetic response is configured for this account."
            )
        }
        switch response {
        case let .snapshot(snapshot, delayNanoseconds):
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            return snapshot
        case let .failure(message, delayNanoseconds):
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            throw ProviderAdapterError(providerID: id, message: message)
        }
    }
}

struct UITestHostRootView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appLanguagePreference: AppLanguagePreference
    let configuration: UITestHostConfiguration
    let userDefaults: UserDefaults

    @StateObject private var panelPresentation = MenuBarPanelPresentationState()
    @State private var surface: UITestHostSurface

    init(
        appModel: AppModel,
        appLanguagePreference: AppLanguagePreference,
        configuration: UITestHostConfiguration,
        userDefaults: UserDefaults
    ) {
        self.appModel = appModel
        self.appLanguagePreference = appLanguagePreference
        self.configuration = configuration
        self.userDefaults = userDefaults
        _surface = State(initialValue: configuration.scenario.initialSurface)
    }

    var body: some View {
        AppLocaleScope(languagePreference: appLanguagePreference) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .accessibilityElement()
                    .accessibilityLabel("UI test host root")
                    .accessibilityIdentifier(
                        "ui-test-host.root.\(configuration.scenario.rawValue)"
                    )

                Group {
                    switch surface {
                    case .dashboard:
                        dashboard
                    case .settings:
                        SettingsView(
                            appModel: appModel,
                            appLanguagePreference: appLanguagePreference,
                            initialWorkspace: initialSettingsWorkspace
                        )
                    }
                }
            }
        }
        .defaultAppStorage(userDefaults)
        .preferredColorScheme(configuration.appearance.colorScheme)
        .onAppear(perform: activateHost)
        .onChange(of: surface) { _, surface in
            panelPresentation.isVisible = surface == .dashboard
            if surface == .dashboard {
                focusDashboardResponder()
            }
        }
        .onDisappear {
            panelPresentation.isVisible = false
        }
    }

    private var dashboard: some View {
        MenuBarPanelView(
            appModel: appModel,
            onOpenSettings: {
                surface = .settings
            },
            onOpenAbout: {
                ApplicationLifecycle.openAbout(appLanguagePreference: appLanguagePreference)
            },
            onOpenOllamaConnection: {},
            onCloseDashboard: {
                NSApp.keyWindow?.performClose(nil)
            },
            panelPresentation: panelPresentation
        )
    }

    private var initialSettingsWorkspace: SettingsWorkspaceState {
        configuration.scenario.initialSettingsWorkspace(
            firstAccountID: appModel.providerAccounts.first?.id
        )
    }

    private func activateHost() {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: configuration.appearance.appKitName)
        NSApp.activate(ignoringOtherApps: true)
        panelPresentation.isVisible = surface == .dashboard
        if surface == .dashboard {
            focusDashboardResponder()
        }
    }

    private func focusDashboardResponder(attemptsRemaining: Int = 4) {
        DispatchQueue.main.async {
            let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible)
            window?.makeKeyAndOrderFront(nil)
            if let responder = panelPresentation.keyboardResponder,
               window?.makeFirstResponder(responder) == true {
                return
            }
            guard attemptsRemaining > 1 else { return }
            focusDashboardResponder(attemptsRemaining: attemptsRemaining - 1)
        }
    }
}
#endif
