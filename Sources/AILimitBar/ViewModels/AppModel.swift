import AILimitBarCore
import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshots: [UsageSnapshot] = []
    @Published private(set) var providerAccounts: [ProviderAccount] = []
    @Published private(set) var providerRefreshStatuses: [String: ProviderRefreshStatus] = [:]
    @Published private(set) var refreshSettings = RefreshSettings()
    @Published private(set) var isRefreshing = false
    @Published var storageWarning: String?

    private let registry: ProviderRegistry
    private let snapshotStore: JSONSnapshotStore
    private let configurationStore: ProviderConfigurationStore
    private let refreshSettingsStore: RefreshSettingsStore
    private let refreshCoordinator: ProviderRefreshCoordinator
    private var scheduledRefreshTimer: Timer?

    init(
        registry: ProviderRegistry = ProviderRegistry(),
        directoryResolver: ApplicationSupportDirectoryResolver = ApplicationSupportDirectoryResolver()
    ) {
        self.registry = registry
        self.refreshCoordinator = ProviderRefreshCoordinator()

        let directory: URL
        do {
            directory = try directoryResolver.resolve()
        } catch {
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("AI Limitbar")
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            directory = fallback
            self.storageWarning = "Application Support is unavailable. Temporary storage is active."
        }

        let snapshotContainer = LocalSnapshotStorageContainer(snapshotsDirectory: directory)
        self.snapshotStore = JSONSnapshotStore(container: snapshotContainer)
        self.configurationStore = ProviderConfigurationStore(directory: directory)
        self.refreshSettingsStore = RefreshSettingsStore(directory: directory)
        loadConfiguration()
        loadRefreshSettings()
        loadSnapshots()
        configureScheduledRefresh()
    }

    deinit {
        scheduledRefreshTimer?.invalidate()
    }

    var enabledSnapshots: [UsageSnapshot] {
        let enabledIDs = Set(providerAccounts.filter(\.isEnabled).map(\.id))
        return snapshots
            .filter { enabledIDs.contains($0.id) }
            .sorted {
                if $0.displayName == $1.displayName {
                    return $0.accountDisplayName < $1.accountDisplayName
                }
                return $0.displayName < $1.displayName
            }
    }

    var enabledSnapshotGroups: [ProviderSnapshotGroup] {
        let snapshotsByProviderID = Dictionary(grouping: enabledSnapshots, by: \.providerID)
        return registry.adapters.compactMap { adapter in
            guard let providerSnapshots = snapshotsByProviderID[adapter.id], !providerSnapshots.isEmpty else {
                return nil
            }
            return ProviderSnapshotGroup(
                providerID: adapter.id,
                displayName: adapter.displayName,
                snapshots: providerSnapshots
            )
        }
    }

    var hasEnabledAccounts: Bool {
        providerAccounts.contains(where: \.isEnabled)
    }

    var hasActiveProviderRefresh: Bool {
        providerRefreshStatuses.values.contains(.refreshing)
    }

    var menuBarTitle: String {
        guard let highestUsage = enabledSnapshots.compactMap(\.usedPercent).max() else {
            return "AI Limits"
        }
        return "AI \(Int(highestUsage.rounded()))%"
    }

    var menuBarSystemImage: String {
        if enabledSnapshots.contains(where: { $0.status == .error }) {
            return "exclamationmark.triangle"
        }
        if enabledSnapshots.contains(where: { $0.status == .warning }) {
            return "gauge.with.dots.needle.67percent"
        }
        return "gauge.with.dots.needle.33percent"
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
            .sorted {
                if $0.accountID == ProviderAccount.defaultAccountID { return true }
                if $1.accountID == ProviderAccount.defaultAccountID { return false }
                return $0.displayName < $1.displayName
            }
    }

    func account(providerID: String, accountID: String) -> ProviderAccount? {
        providerAccounts.first {
            $0.providerID == providerID && $0.accountID == accountID
        }
    }

    func refreshStatus(for account: ProviderAccount) -> ProviderRefreshStatus {
        providerRefreshStatuses[account.id] ?? .idle
    }

    func refreshStatus(for snapshot: UsageSnapshot) -> ProviderRefreshStatus {
        providerRefreshStatuses[snapshot.id] ?? .idle
    }

    func isSnapshotStale(_ snapshot: UsageSnapshot, now: Date = Date()) -> Bool {
        now.timeIntervalSince(snapshot.lastUpdatedAt) > refreshSettings.interval.staleAfter
    }

    func setAccount(_ providerID: String, accountID: String, enabled: Bool) {
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else {
            return
        }
        providerAccounts[index].isEnabled = enabled
        saveConfiguration()
    }

    func setAccountDisplayName(_ providerID: String, accountID: String, displayName: String) {
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else {
            return
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = trimmed.isEmpty ? ProviderAccount.defaultDisplayName : trimmed
        providerAccounts[index].displayName = resolvedDisplayName
        updateSnapshotAccountDisplayName(
            providerID: providerID,
            accountID: accountID,
            displayName: resolvedDisplayName
        )
        saveConfiguration()
        saveSnapshots()
    }

    func setAccountSourceMode(_ providerID: String, accountID: String, sourceMode: ProviderSourceMode) {
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else {
            return
        }
        providerAccounts[index].sourceMode = sourceMode
        saveConfiguration()
    }

    func setAccountLocalSnapshotPath(_ providerID: String, accountID: String, path: String) {
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else {
            return
        }
        providerAccounts[index].localSnapshotPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        saveConfiguration()
    }

    func addAccount(
        providerID: String,
        displayName: String? = nil,
        isEnabled: Bool = true,
        sourceMode: ProviderSourceMode = .manual,
        localSnapshotPath: String? = nil
    ) {
        guard adapter(for: providerID) != nil else { return }
        let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedSnapshotPath = localSnapshotPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let account = ProviderAccount(
            providerID: providerID,
            accountID: "account-\(UUID().uuidString.lowercased())",
            displayName: trimmedDisplayName.isEmpty ? nextAccountDisplayName(for: providerID) : trimmedDisplayName,
            isEnabled: isEnabled,
            sourceMode: sourceMode,
            localSnapshotPath: trimmedSnapshotPath.isEmpty ? nil : trimmedSnapshotPath
        )
        providerAccounts.append(account)
        saveConfiguration()
    }

    func deleteAccount(providerID: String, accountID: String) {
        let accountKey = "\(providerID):\(accountID)"
        guard providerAccounts.contains(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else {
            return
        }
        providerAccounts.removeAll {
            $0.providerID == providerID && $0.accountID == accountID
        }
        snapshots.removeAll { $0.id == accountKey }
        providerRefreshStatuses.removeValue(forKey: accountKey)
        saveConfiguration()
        saveSnapshots()
    }

    func canDeleteAccount(providerID: String, accountID: String) -> Bool {
        providerAccounts.contains {
            $0.providerID == providerID && $0.accountID == accountID
        }
    }

    func setRefreshInterval(_ interval: RefreshInterval) {
        refreshSettings.interval = interval
        saveRefreshSettings()
        configureScheduledRefresh()
    }

    func refresh() {
        guard !isRefreshing, !hasActiveProviderRefresh else { return }
        isRefreshing = true

        Task {
            await refreshEnabledProviders()
            isRefreshing = false
        }
    }

    func testConnection(providerID: String, accountID: String) {
        guard let adapter = adapter(for: providerID) else { return }
        guard let account = account(providerID: providerID, accountID: accountID) else { return }
        guard !isRefreshing else { return }
        guard refreshStatus(for: account) != .refreshing else { return }
        setRefreshStatus(.refreshing, for: account.id)

        Task {
            do {
                let snapshot = try await adapter.fetchSnapshot(account: account)
                upsert(snapshot)
                setRefreshStatus(.succeeded(snapshot.lastUpdatedAt), for: snapshot.id)
                saveSnapshots()
            } catch {
                let snapshot = refreshCoordinator.errorSnapshot(
                    account: account,
                    providerDisplayName: adapter.displayName,
                    error: error
                )
                upsert(snapshot)
                setRefreshStatus(.failed(snapshot.lastUpdatedAt), for: snapshot.id)
                saveSnapshots()
            }
        }
    }

    func openUsagePage(providerID: String) {
        guard let url = adapter(for: providerID)?.usageURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshEnabledProviders() async {
        let enabledAccounts = providerAccounts
            .filter(\.isEnabled)
            .filter { registry.adaptersByID[$0.providerID] != nil }

        guard !enabledAccounts.isEmpty else { return }

        for account in enabledAccounts {
            setRefreshStatus(.refreshing, for: account.id)
        }

        let requests = enabledAccounts.compactMap { account -> ProviderRefreshRequest? in
            guard let adapter = registry.adaptersByID[account.providerID] else { return nil }
            return ProviderRefreshRequest(
                adapter: adapter,
                account: account
            )
        }

        let refreshedSnapshots = await refreshCoordinator.refresh(requests)
        for snapshot in refreshedSnapshots {
            upsert(snapshot)
            setRefreshStatus(
                snapshot.status == .error ? .failed(snapshot.lastUpdatedAt) : .succeeded(snapshot.lastUpdatedAt),
                for: snapshot.id
            )
        }

        saveSnapshots()
    }

    private func loadConfiguration() {
        let result = configurationStore.load(knownProviderIDs: Set(providerIDs))
        providerAccounts = result.accounts
        storageWarning = storageWarning ?? result.warning
    }

    private func saveConfiguration() {
        do {
            try configurationStore.save(providerAccounts)
        } catch {
            storageWarning = "Provider settings could not be saved."
        }
    }

    private func loadRefreshSettings() {
        let result = refreshSettingsStore.load()
        refreshSettings = result.settings
        storageWarning = storageWarning ?? result.warning
    }

    private func saveRefreshSettings() {
        do {
            try refreshSettingsStore.save(refreshSettings)
        } catch {
            storageWarning = "Refresh settings could not be saved."
        }
    }

    private func loadSnapshots() {
        let result = snapshotStore.load()
        snapshots = result.snapshots
        storageWarning = storageWarning ?? result.warning
    }

    private func saveSnapshots() {
        do {
            try snapshotStore.save(snapshots)
        } catch {
            storageWarning = "Snapshots could not be saved."
        }
    }

    private func upsert(_ snapshot: UsageSnapshot) {
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
    }

    private func updateSnapshotAccountDisplayName(providerID: String, accountID: String, displayName: String) {
        guard let index = snapshots.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else {
            return
        }

        let snapshot = snapshots[index]
        snapshots[index] = UsageSnapshot(
            providerID: snapshot.providerID,
            accountID: snapshot.accountID,
            accountDisplayName: displayName,
            displayName: snapshot.displayName,
            status: snapshot.status,
            planName: snapshot.planName,
            periodLabel: snapshot.periodLabel,
            usedPercent: snapshot.usedPercent,
            remainingLabel: snapshot.remainingLabel,
            resetAt: snapshot.resetAt,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            confidence: snapshot.confidence,
            source: snapshot.source,
            warnings: snapshot.warnings
        )
    }

    private func setRefreshStatus(_ status: ProviderRefreshStatus, for accountKey: String) {
        providerRefreshStatuses[accountKey] = status
    }

    private func configureScheduledRefresh() {
        scheduledRefreshTimer?.invalidate()
        scheduledRefreshTimer = nil

        guard let timeInterval = refreshSettings.interval.timeInterval else { return }

        scheduledRefreshTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func nextAccountDisplayName(for providerID: String) -> String {
        let count = accounts(for: providerID).count
        return "Account \(count + 1)"
    }
}

struct ProviderSnapshotGroup: Identifiable {
    let providerID: String
    let displayName: String
    let snapshots: [UsageSnapshot]

    var id: String { providerID }
}
