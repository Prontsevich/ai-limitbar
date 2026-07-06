import AILimitBarCore
import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshots: [UsageSnapshot] = []
    @Published private(set) var providerConfigurations: [ProviderConfiguration] = []
    @Published private(set) var isRefreshing = false
    @Published var storageWarning: String?

    private let registry: ProviderRegistry
    private let snapshotStore: JSONSnapshotStore
    private let configurationStore: ProviderConfigurationStore

    init(
        registry: ProviderRegistry = ProviderRegistry(),
        directoryResolver: ApplicationSupportDirectoryResolver = ApplicationSupportDirectoryResolver()
    ) {
        self.registry = registry

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
        loadConfiguration()
        loadSnapshots()
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

    func refresh() {
        guard !isRefreshing else { return }

        Task {
            await refreshEnabledProviders()
        }
    }

    func testConnection(providerID: String) {
        guard let adapter = adapter(for: providerID) else { return }

        Task {
            do {
                let snapshot = try await adapter.fetchSnapshot()
                upsert(snapshot)
                saveSnapshots()
            } catch {
                let snapshot = errorSnapshot(
                    providerID: providerID,
                    displayName: adapter.displayName,
                    message: error.localizedDescription
                )
                upsert(snapshot)
                saveSnapshots()
            }
        }
    }

    func openUsagePage(providerID: String) {
        guard let url = adapter(for: providerID)?.usageURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshEnabledProviders() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let enabledAdapters = providerConfigurations
            .filter(\.isEnabled)
            .compactMap { registry.adaptersByID[$0.providerID] }

        guard !enabledAdapters.isEmpty else { return }

        for adapter in enabledAdapters {
            do {
                let snapshot = try await adapter.fetchSnapshot()
                upsert(snapshot)
            } catch {
                let snapshot = errorSnapshot(
                    providerID: adapter.id,
                    displayName: adapter.displayName,
                    message: error.localizedDescription
                )
                upsert(snapshot)
            }
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
        if let index = snapshots.firstIndex(where: { $0.providerID == snapshot.providerID }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
    }

    private func errorSnapshot(providerID: String, displayName: String, message: String) -> UsageSnapshot {
        UsageSnapshot(
            providerID: providerID,
            displayName: displayName,
            status: .error,
            remainingLabel: "Refresh failed",
            lastUpdatedAt: Date(),
            confidence: .unknown,
            source: "Provider adapter error",
            warnings: [message]
        )
    }
}
