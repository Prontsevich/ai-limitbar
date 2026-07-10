import AILimitBarCore

extension AppModel {
    func loadConfiguration() {
        let result = configurationStore.load(knownProviderIDs: Set(providerIDs))
        providerAccounts = result.accounts
        storageWarning = storageWarning ?? result.warning
    }

    @discardableResult
    func saveConfiguration() -> Bool {
        do {
            try configurationStore.save(providerAccounts)
            clearStorageWarning("Provider settings could not be saved.")
            return true
        } catch {
            storageWarning = "Provider settings could not be saved."
            AppTelemetry.storage.error("Provider settings could not be saved")
            return false
        }
    }

    func loadRefreshSettings() {
        let result = refreshSettingsStore.load()
        refreshSettings = result.settings
        storageWarning = storageWarning ?? result.warning
    }

    @discardableResult
    func saveRefreshSettings() -> Bool {
        do {
            try refreshSettingsStore.save(refreshSettings)
            clearStorageWarning("Refresh settings could not be saved.")
            return true
        } catch {
            storageWarning = "Refresh settings could not be saved."
            AppTelemetry.storage.error("Refresh settings could not be saved")
            return false
        }
    }

    func loadSnapshots() {
        let result = snapshotStore.load()
        snapshots = result.snapshots
        storageWarning = storageWarning ?? result.warning
    }

    @discardableResult
    func saveSnapshots() -> Bool {
        do {
            try snapshotStore.save(snapshots)
            clearStorageWarning("Snapshots could not be saved.")
            return true
        } catch {
            storageWarning = "Snapshots could not be saved."
            AppTelemetry.storage.error("Snapshots could not be saved")
            return false
        }
    }

    func upsert(_ snapshot: UsageSnapshot) {
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
    }

    func existingSnapshot(matching snapshot: UsageSnapshot) -> UsageSnapshot? {
        snapshots.first { $0.id == snapshot.id }
    }

    private func clearStorageWarning(_ warning: String) {
        if storageWarning == warning {
            storageWarning = nil
        }
    }
}
