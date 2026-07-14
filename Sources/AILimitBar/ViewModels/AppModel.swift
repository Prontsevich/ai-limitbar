import AILimitBarCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshots: [UsageSnapshot] = []
    @Published var providerAccounts: [ProviderAccount] = []
    @Published var providerRefreshStatuses: [String: ProviderRefreshStatus] = [:]
    @Published var accountRefreshIssues: [String: AccountRefreshIssue] = [:]
    @Published var sourceDiagnostics: [SourceDiagnostic] = []
    @Published var refreshSettings = RefreshSettings()
    @Published var isRefreshing = false
    @Published var storageWarning: String?
    @Published private(set) var ollamaConnectionAccount: ProviderAccount?

    let registry: ProviderRegistry
    let snapshotStore: any CurrentSnapshotStore
    let configurationStore: any ProviderAccountStore
    let refreshSettingsStore: any RefreshSettingsStoreProtocol
    let diagnosticStore: any SourceDiagnosticStore
    let refreshCoordinator: ProviderRefreshCoordinator
    let ollamaWebPageClient: OllamaWebPageClientController?
    var scheduledRefreshTimer: Timer?
    var globalRefreshTask: Task<Void, Never>?
    var accountRefreshTasks: [String: Task<Void, Never>] = [:]
    var accountRefreshTaskIDs: [String: UUID] = [:]

    init(
        registry: ProviderRegistry? = nil,
        ollamaWebPageClient: OllamaWebPageClientController? = nil,
        directoryResolver: ApplicationSupportDirectoryResolver = ApplicationSupportDirectoryResolver(),
        storageDirectory: URL? = nil,
        refreshCoordinator: ProviderRefreshCoordinator = ProviderRefreshCoordinator()
    ) {
        self.ollamaWebPageClient = ollamaWebPageClient
        let resolvedClient: any OllamaWebPageClient = ollamaWebPageClient ?? UnavailableOllamaWebPageClient()
        self.refreshCoordinator = refreshCoordinator

        let directory: URL
        var initialStorageWarning: String?
        if let storageDirectory {
            directory = storageDirectory
        } else {
            do {
                directory = try directoryResolver.resolve()
            } catch {
                let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("AI Limitbar")
                try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
                directory = fallback
                initialStorageWarning = "Application Support is unavailable. Temporary storage is active."
            }
        }

        let database: AppDatabase?
        do {
            database = try AppDatabase(directory: directory)
        } catch {
            database = nil
            initialStorageWarning = "AI Limitbar storage is unavailable. Changes cannot be saved."
        }
        let snapshotStore = DatabaseSnapshotStore(database: database)
        self.snapshotStore = snapshotStore
        self.configurationStore = DatabaseProviderConfigurationStore(database: database)
        self.refreshSettingsStore = DatabaseRefreshSettingsStore(database: database)
        self.diagnosticStore = DatabaseSourceDiagnosticStore(database: database)
        self.storageWarning = initialStorageWarning
        self.registry = registry ?? ProviderRegistry(
            ollamaWebPageClient: resolvedClient,
            claudeSnapshotStore: snapshotStore
        )

        if let database {
            do {
                try LegacyStorageImporter(
                    directory: directory,
                    database: database,
                    knownProviderIDs: Set(self.registry.adapters.map(\.id))
                ).runIfNeeded()
            } catch {
                self.storageWarning = "Legacy JSON data could not be migrated. Existing database data remains available."
            }
        }
        loadConfiguration()
        loadRefreshSettings()
        loadSnapshots()
        loadDiagnostics()
        configureScheduledRefresh()
    }

    isolated deinit {
        scheduledRefreshTimer?.invalidate()
        globalRefreshTask?.cancel()
        accountRefreshTasks.values.forEach { $0.cancel() }
    }

    var enabledSnapshots: [UsageSnapshot] {
        providerAccounts
            .filter(\.isEnabled)
            .compactMap { snapshot(for: $0) }
    }

    var enabledAccountRows: [AccountSnapshotRow] {
        providerAccounts
            .filter(\.isEnabled)
            .filter { registry.adaptersByID[$0.providerID] != nil }
            .map { account in
                AccountSnapshotRow(
                    account: account,
                    providerDisplayName: providerDisplayName(for: account.providerID),
                    snapshot: snapshot(for: account),
                    refreshStatus: refreshStatus(for: account),
                    refreshIssue: accountRefreshIssues[account.id]
                )
            }
    }

    var hasEnabledAccounts: Bool {
        providerAccounts.contains(where: \.isEnabled)
    }

    var hasActiveProviderRefresh: Bool {
        providerRefreshStatuses.values.contains(.refreshing)
    }

    func presentOllamaConnection(for account: ProviderAccount) {
        ollamaConnectionAccount = account
    }

    func clearOllamaConnection(for account: ProviderAccount) {
        guard ollamaConnectionAccount?.id == account.id else { return }
        ollamaConnectionAccount = nil
    }

    var menuBarTitle: String {
        let highestUsage = enabledSnapshots
            .flatMap(\.displayLimitWindows)
            .compactMap(\.usedPercent)
            .max()

        guard let highestUsage else {
            return "AI Limits"
        }
        return "AI \(Int(highestUsage.rounded()))%"
    }

    var menuBarSystemImage: String {
        if !accountRefreshIssues.isEmpty {
            return "exclamationmark.triangle"
        }
        if enabledSnapshots.contains(where: { $0.status == .error }) {
            return "exclamationmark.triangle"
        }
        if enabledSnapshots.contains(where: { $0.status == .warning }) {
            return "gauge.with.dots.needle.67percent"
        }
        return "gauge.with.dots.needle.33percent"
    }

    var menuBarAccessibilityValue: String {
        if !accountRefreshIssues.isEmpty {
            return "One or more account refreshes failed"
        }

        let highestUsage = enabledSnapshots
            .flatMap(\.displayLimitWindows)
            .compactMap(\.usedPercent)
            .max()

        guard let highestUsage else {
            return hasEnabledAccounts ? "No usage data available" : "No enabled accounts"
        }
        return "Highest usage is \(Int(highestUsage.rounded())) percent"
    }

    func adapter(for providerID: String) -> (any ProviderAdapter)? {
        registry.adaptersByID[providerID]
    }

    var providerIDs: [String] {
        registry.adapters.map(\.id)
    }

    func providerDisplayName(for providerID: String) -> String {
        adapter(for: providerID)?.displayName ?? providerID
    }

    func accounts(for providerID: String) -> [ProviderAccount] {
        providerAccounts
            .filter { $0.providerID == providerID }
    }

    func account(providerID: String, accountID: String) -> ProviderAccount? {
        providerAccounts.first {
            $0.providerID == providerID && $0.accountID == accountID
        }
    }

    func refreshStatus(for account: ProviderAccount) -> ProviderRefreshStatus {
        providerRefreshStatuses[account.id] ?? .idle
    }

    func snapshot(for account: ProviderAccount) -> UsageSnapshot? {
        snapshots.first { $0.id == account.id }
    }

    func migrationDiagnostics(for account: ProviderAccount) -> [SourceDiagnostic] {
        sourceDiagnostics.filter {
            $0.providerID == account.providerID &&
                $0.accountID == account.accountID &&
                !$0.code.hasPrefix("refresh-")
        }
    }

    func isSnapshotStale(_ snapshot: UsageSnapshot, now: Date = Date()) -> Bool {
        now.timeIntervalSince(snapshot.lastUpdatedAt) > refreshSettings.interval.staleAfter
    }

    func usageURL(providerID: String, accountID: String? = nil) -> URL? {
        guard let url = adapter(for: providerID)?.usageURL else { return nil }
        if let accountID {
            guard account(providerID: providerID, accountID: accountID) != nil else { return nil }
        }
        return url
    }
}
