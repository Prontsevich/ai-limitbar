import AILimitBarCore
import Foundation

extension AppModel {
    func acceptOllamaUsagePayload(_ payload: OllamaUsagePagePayload, for account: ProviderAccount) {
        guard let adapter = adapter(for: account.providerID) as? OllamaCloudProviderAdapter else { return }

        do {
            let snapshot = try adapter.makeSnapshot(account: account, payload: payload)
            if handleRefreshedSnapshot(snapshot) {
                saveSnapshots()
            }
        } catch {
            let snapshot = refreshCoordinator.errorSnapshot(
                account: account,
                providerDisplayName: adapter.displayName,
                error: error
            )
            handleFailedSnapshot(snapshot)
            saveSnapshots()
        }
    }

    func setRefreshInterval(_ interval: RefreshInterval) {
        let previousSettings = refreshSettings
        refreshSettings.interval = interval
        guard saveRefreshSettings() else {
            refreshSettings = previousSettings
            return
        }
        configureScheduledRefresh()
    }

    func refresh() {
        guard globalRefreshTask == nil, !isRefreshing, !hasActiveProviderRefresh else { return }
        isRefreshing = true
        AppTelemetry.refresh.info("Refreshing all enabled accounts")

        globalRefreshTask = Task { [weak self] in
            guard let self else { return }
            defer { finishGlobalRefresh() }
            await refreshEnabledProviders()
        }
    }

    func refreshAccount(providerID: String, accountID: String) {
        guard let adapter = adapter(for: providerID) else { return }
        guard let account = account(providerID: providerID, accountID: accountID), account.isEnabled else { return }
        guard !isRefreshing, refreshStatus(for: account) != .refreshing else { return }
        setRefreshStatus(.refreshing, for: account.id)
        AppTelemetry.refresh.info("Refreshing one account")
        let taskID = UUID()
        accountRefreshTaskIDs[account.id] = taskID

        accountRefreshTasks[account.id] = Task { [weak self] in
            guard let self else { return }
            defer { finishAccountRefresh(for: account.id, taskID: taskID) }
            let snapshot = await refreshCoordinator.refresh(
                ProviderRefreshRequest(adapter: adapter, account: account)
            )
            guard !Task.isCancelled, self.account(providerID: providerID, accountID: accountID) != nil else {
                return
            }
            if handleRefreshedSnapshot(snapshot) {
                saveSnapshots()
            }
        }
    }

    func testConnection(providerID: String, accountID: String) {
        guard let adapter = adapter(for: providerID) else { return }
        guard let account = account(providerID: providerID, accountID: accountID) else { return }
        guard !isRefreshing, refreshStatus(for: account) != .refreshing else { return }
        setRefreshStatus(.refreshing, for: account.id)
        AppTelemetry.refresh.info("Testing one account connection")
        let taskID = UUID()
        accountRefreshTaskIDs[account.id] = taskID

        accountRefreshTasks[account.id] = Task { [weak self] in
            guard let self else { return }
            defer { finishAccountRefresh(for: account.id, taskID: taskID) }
            let snapshot = await refreshCoordinator.refresh(
                ProviderRefreshRequest(adapter: adapter, account: account)
            )
            guard !Task.isCancelled, self.account(providerID: providerID, accountID: accountID) != nil else {
                return
            }
            if handleRefreshedSnapshot(snapshot) {
                saveSnapshots()
            }
        }
    }

    func refreshEnabledProviders() async {
        let enabledAccounts = providerAccounts
            .filter(\.isEnabled)
            .filter { registry.adaptersByID[$0.providerID] != nil }
        guard !enabledAccounts.isEmpty else { return }

        for account in enabledAccounts {
            setRefreshStatus(.refreshing, for: account.id)
        }
        let requests = enabledAccounts.compactMap { account -> ProviderRefreshRequest? in
            guard let adapter = registry.adaptersByID[account.providerID] else { return nil }
            return ProviderRefreshRequest(adapter: adapter, account: account)
        }
        let refreshedSnapshots = await refreshCoordinator.refresh(requests)
        guard !Task.isCancelled else { return }

        var didChangeSnapshots = false
        for snapshot in refreshedSnapshots {
            didChangeSnapshots = handleRefreshedSnapshot(snapshot) || didChangeSnapshots
        }
        if didChangeSnapshots {
            saveSnapshots()
        }
    }

    @discardableResult
    func handleRefreshedSnapshot(_ snapshot: UsageSnapshot) -> Bool {
        guard account(providerID: snapshot.providerID, accountID: snapshot.accountID) != nil else {
            return false
        }
        if snapshot.status == .error {
            handleFailedSnapshot(snapshot)
        } else {
            upsert(snapshot)
            accountRefreshIssues.removeValue(forKey: snapshot.id)
            setRefreshStatus(.succeeded(snapshot.lastUpdatedAt), for: snapshot.id)
        }
        return true
    }

    func handleFailedSnapshot(_ snapshot: UsageSnapshot) {
        if existingSnapshot(matching: snapshot) == nil {
            upsert(snapshot)
        }
        accountRefreshIssues[snapshot.id] = AccountRefreshIssue(
            occurredAt: snapshot.lastUpdatedAt,
            warnings: snapshot.warnings
        )
        setRefreshStatus(.failed(snapshot.lastUpdatedAt), for: snapshot.id)
    }

    func setRefreshStatus(_ status: ProviderRefreshStatus, for accountKey: String) {
        providerRefreshStatuses[accountKey] = status
    }

    func cancelAccountRefresh(for accountKey: String) {
        accountRefreshTasks.removeValue(forKey: accountKey)?.cancel()
        accountRefreshTaskIDs.removeValue(forKey: accountKey)
        providerRefreshStatuses.removeValue(forKey: accountKey)
    }

    private func finishAccountRefresh(for accountKey: String, taskID: UUID) {
        guard accountRefreshTaskIDs[accountKey] == taskID else { return }
        accountRefreshTasks.removeValue(forKey: accountKey)
        accountRefreshTaskIDs.removeValue(forKey: accountKey)
    }

    private func finishGlobalRefresh() {
        isRefreshing = false
        globalRefreshTask = nil
        AppTelemetry.refresh.info("Finished refreshing enabled accounts")
    }

    func configureScheduledRefresh() {
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
