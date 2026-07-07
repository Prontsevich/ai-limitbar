import AILimitBarCore
import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshots: [UsageSnapshot] = []
    @Published private(set) var providerConfigurations: [ProviderConfiguration] = []
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

        self.snapshotStore = JSONSnapshotStore(directory: directory)
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
        let enabledIDs = Set(providerConfigurations.filter(\.isEnabled).map(\.providerID))
        return snapshots
            .filter { enabledIDs.contains($0.providerID) }
            .sorted { $0.displayName < $1.displayName }
    }

    var hasEnabledProviders: Bool {
        providerConfigurations.contains(where: \.isEnabled)
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

    func refreshStatus(for providerID: String) -> ProviderRefreshStatus {
        providerRefreshStatuses[providerID] ?? .idle
    }

    func setProvider(_ providerID: String, enabled: Bool) {
        guard let index = providerConfigurations.firstIndex(where: { $0.providerID == providerID }) else {
            return
        }
        providerConfigurations[index].isEnabled = enabled
        saveConfiguration()
    }

    func setProviderSourceMode(_ providerID: String, sourceMode: ProviderSourceMode) {
        guard let index = providerConfigurations.firstIndex(where: { $0.providerID == providerID }) else {
            return
        }
        providerConfigurations[index].sourceMode = sourceMode
        saveConfiguration()
    }

    func setProviderLocalSnapshotPath(_ providerID: String, path: String) {
        guard let index = providerConfigurations.firstIndex(where: { $0.providerID == providerID }) else {
            return
        }
        providerConfigurations[index].localSnapshotPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        saveConfiguration()
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

    func testConnection(providerID: String) {
        guard let adapter = adapter(for: providerID) else { return }
        guard !isRefreshing else { return }
        guard refreshStatus(for: providerID) != .refreshing else { return }
        setRefreshStatus(.refreshing, for: providerID)

        Task {
            do {
                let configuration = providerConfiguration(for: providerID)
                let snapshot = try await adapter.fetchSnapshot(configuration: configuration)
                upsert(snapshot)
                setRefreshStatus(.succeeded(snapshot.lastUpdatedAt), for: providerID)
                saveSnapshots()
            } catch {
                let snapshot = refreshCoordinator.errorSnapshot(
                    providerID: providerID,
                    displayName: adapter.displayName,
                    error: error
                )
                upsert(snapshot)
                setRefreshStatus(.failed(snapshot.lastUpdatedAt), for: providerID)
                saveSnapshots()
            }
        }
    }

    func openUsagePage(providerID: String) {
        guard let url = adapter(for: providerID)?.usageURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshEnabledProviders() async {
        let enabledAdapters = providerConfigurations
            .filter(\.isEnabled)
            .compactMap { registry.adaptersByID[$0.providerID] }

        guard !enabledAdapters.isEmpty else { return }

        for adapter in enabledAdapters {
            setRefreshStatus(.refreshing, for: adapter.id)
        }

        let requests = enabledAdapters.map { adapter in
            ProviderRefreshRequest(
                adapter: adapter,
                configuration: providerConfiguration(for: adapter.id)
            )
        }

        let refreshedSnapshots = await refreshCoordinator.refresh(requests)
        for snapshot in refreshedSnapshots {
            upsert(snapshot)
            setRefreshStatus(
                snapshot.status == .error ? .failed(snapshot.lastUpdatedAt) : .succeeded(snapshot.lastUpdatedAt),
                for: snapshot.providerID
            )
        }

        saveSnapshots()
    }

    private func loadConfiguration() {
        let defaults = registry.adapters.map {
            ProviderConfiguration(providerID: $0.id, isEnabled: $0.defaultEnabled)
        }
        let result = configurationStore.load(defaults: defaults)
        providerConfigurations = result.configurations
        storageWarning = storageWarning ?? result.warning
    }

    private func saveConfiguration() {
        do {
            try configurationStore.save(providerConfigurations)
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

    private func providerConfiguration(for providerID: String) -> ProviderConfiguration {
        providerConfigurations.first(where: { $0.providerID == providerID })
            ?? ProviderConfiguration(providerID: providerID, isEnabled: false)
    }

    private func saveSnapshots() {
        do {
            try snapshotStore.save(snapshots)
        } catch {
            storageWarning = "Snapshots could not be saved."
        }
    }

    private func upsert(_ snapshot: UsageSnapshot) {
        if let index = snapshots.firstIndex(where: { $0.providerID == snapshot.providerID }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
    }

    private func setRefreshStatus(_ status: ProviderRefreshStatus, for providerID: String) {
        providerRefreshStatuses[providerID] = status
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

}
