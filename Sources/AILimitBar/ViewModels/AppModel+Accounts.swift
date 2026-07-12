import AILimitBarCore
import Foundation

extension AppModel {
    func setAccount(_ providerID: String, accountID: String, enabled: Bool) {
        let previousAccounts = providerAccounts
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

        providerAccounts[index].isEnabled = enabled
        if !enabled {
            cancelAccountRefresh(for: providerAccounts[index].id)
        }
        if !saveConfiguration() {
            providerAccounts = previousAccounts
        }
    }

    func setAccountDisplayName(_ providerID: String, accountID: String, displayName: String) {
        let previousAccounts = providerAccounts
        let previousSnapshots = snapshots
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = trimmed.isEmpty ? ProviderAccount.defaultDisplayName : trimmed
        providerAccounts[index].displayName = resolvedDisplayName
        updateSnapshotAccountDisplayName(
            providerID: providerID,
            accountID: accountID,
            displayName: resolvedDisplayName
        )
        guard saveConfiguration() else {
            providerAccounts = previousAccounts
            snapshots = previousSnapshots
            return
        }
        saveSnapshots()
    }

    @discardableResult
    func updateAccount(
        providerID: String,
        accountID: String,
        displayName: String,
        sourceMode: ProviderSourceMode,
        localSnapshotPath: String?
    ) -> Bool {
        let previousAccounts = providerAccounts
        let previousSnapshots = snapshots
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return false }

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSnapshotPath = localSnapshotPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedDisplayName = trimmedDisplayName.isEmpty ? ProviderAccount.defaultDisplayName : trimmedDisplayName

        providerAccounts[index].displayName = resolvedDisplayName
        providerAccounts[index].sourceMode = sourceMode
        providerAccounts[index].localSnapshotPath = trimmedSnapshotPath.isEmpty ? nil : trimmedSnapshotPath
        updateSnapshotAccountDisplayName(
            providerID: providerID,
            accountID: accountID,
            displayName: resolvedDisplayName
        )

        guard saveConfiguration() else {
            providerAccounts = previousAccounts
            snapshots = previousSnapshots
            return false
        }
        saveSnapshots()
        return true
    }

    func setAccountSourceMode(_ providerID: String, accountID: String, sourceMode: ProviderSourceMode) {
        let previousAccounts = providerAccounts
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

        providerAccounts[index].sourceMode = sourceMode
        if !saveConfiguration() {
            providerAccounts = previousAccounts
        }
    }

    func setAccountLocalSnapshotPath(_ providerID: String, accountID: String, path: String) {
        let previousAccounts = providerAccounts
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

        providerAccounts[index].localSnapshotPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !saveConfiguration() {
            providerAccounts = previousAccounts
        }
    }

    func moveAccountUp(providerID: String, accountID: String) {
        moveAccount(providerID: providerID, accountID: accountID, offset: -1)
    }

    func moveAccountDown(providerID: String, accountID: String) {
        moveAccount(providerID: providerID, accountID: accountID, offset: 1)
    }

    func moveAccounts(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !offsets.isEmpty,
              destination >= 0,
              destination <= providerAccounts.count,
              offsets.allSatisfy(providerAccounts.indices.contains)
        else { return }

        let previousAccounts = providerAccounts
        let movedAccounts = offsets.map { providerAccounts[$0] }
        var remainingAccounts = providerAccounts.enumerated().compactMap { index, account in
            offsets.contains(index) ? nil : account
        }
        let adjustedDestination = destination - offsets.filter { $0 < destination }.count
        remainingAccounts.insert(contentsOf: movedAccounts, at: adjustedDestination)
        providerAccounts = remainingAccounts

        if !saveConfiguration() {
            providerAccounts = previousAccounts
        }
    }

    func canMoveAccountUp(providerID: String, accountID: String) -> Bool {
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return false }
        return index > providerAccounts.startIndex
    }

    func canMoveAccountDown(providerID: String, accountID: String) -> Bool {
        guard let index = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return false }
        return index < providerAccounts.index(before: providerAccounts.endIndex)
    }

    @discardableResult
    func addAccount(
        providerID: String,
        displayName: String? = nil,
        isEnabled: Bool = true,
        sourceMode: ProviderSourceMode = .manual,
        localSnapshotPath: String? = nil
    ) -> ProviderAccount? {
        guard adapter(for: providerID) != nil else { return nil }
        let previousAccounts = providerAccounts
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
        if !saveConfiguration() {
            providerAccounts = previousAccounts
            return nil
        }
        return account
    }

    func deleteAccount(providerID: String, accountID: String) {
        let accountKey = "\(providerID):\(accountID)"
        let previousAccounts = providerAccounts
        let previousSnapshots = snapshots
        let previousStatuses = providerRefreshStatuses
        let previousIssues = accountRefreshIssues
        guard providerAccounts.contains(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

        cancelAccountRefresh(for: accountKey)
        providerAccounts.removeAll { $0.providerID == providerID && $0.accountID == accountID }
        snapshots.removeAll { $0.id == accountKey }
        providerRefreshStatuses.removeValue(forKey: accountKey)
        accountRefreshIssues.removeValue(forKey: accountKey)
        guard saveConfiguration() else {
            providerAccounts = previousAccounts
            snapshots = previousSnapshots
            providerRefreshStatuses = previousStatuses
            accountRefreshIssues = previousIssues
            return
        }
        saveSnapshots()
    }

    func canDeleteAccount(providerID: String, accountID: String) -> Bool {
        providerAccounts.contains { $0.providerID == providerID && $0.accountID == accountID }
    }

    func updateSnapshotAccountDisplayName(providerID: String, accountID: String, displayName: String) {
        guard let index = snapshots.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

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
            limitWindows: snapshot.limitWindows,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            confidence: snapshot.confidence,
            source: snapshot.source,
            warnings: snapshot.warnings
        )
    }

    private func nextAccountDisplayName(for providerID: String) -> String {
        "Account \(accounts(for: providerID).count + 1)"
    }

    private func moveAccount(providerID: String, accountID: String, offset: Int) {
        let previousAccounts = providerAccounts
        guard let sourceIndex = providerAccounts.firstIndex(where: {
            $0.providerID == providerID && $0.accountID == accountID
        }) else { return }

        let destinationIndex = sourceIndex + offset
        guard providerAccounts.indices.contains(destinationIndex) else { return }
        providerAccounts.swapAt(sourceIndex, destinationIndex)
        if !saveConfiguration() {
            providerAccounts = previousAccounts
        }
    }
}
