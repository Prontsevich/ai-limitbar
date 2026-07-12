import AILimitBarCore
import SwiftUI

struct AccountDetailView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Divider()

            Form {
                Section("Account") {
                    LabeledContent("Name", value: currentAccount.displayName)
                    LabeledContent("Provider", value: appModel.providerDisplayName(for: currentAccount.providerID))
                }

                Section("Configuration") {
                    LabeledContent("Source", value: currentAccount.sourceMode.displayName)
                    if let localSnapshotPath = currentAccount.localSnapshotPath, !localSnapshotPath.isEmpty {
                        LabeledContent("Local snapshot", value: localSnapshotPath)
                    }
                }

                Section("Status") {
                    LabeledContent("Refresh", value: appModel.refreshStatus(for: currentAccount).displayName)
                    if let snapshot = appModel.snapshot(for: currentAccount) {
                        LabeledContent("Last updated", value: snapshot.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        LabeledContent("Last updated", value: "No usage data")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer()

            Button(action: onEdit) {
                SettingsGlassIcon(systemName: "square.and.pencil", verticalOffset: -1)
            }
            .settingsGlassIconButton(help: "Edit account")
            .frame(width: 40, height: 40)

            Button {
                appModel.refreshAccount(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            } label: {
                SettingsGlassIcon(systemName: "arrow.clockwise")
            }
            .disabled(isAccountActionDisabled)
            .settingsGlassIconButton(help: refreshButtonTitle)
            .frame(width: 40, height: 40)

            NativeActionsMenuButton(
                isTestEnabled: !isAccountActionDisabled,
                isUsageEnabled: usageURL != nil,
                onTest: {
                    appModel.testConnection(
                        providerID: currentAccount.providerID,
                        accountID: currentAccount.accountID
                    )
                },
                onOpenUsage: {
                    if let usageURL {
                        openURL(usageURL)
                    }
                }
            )
            .frame(width: 40, height: 40)
        }
    }

    private var currentAccount: ProviderAccount {
        appModel.account(providerID: account.providerID, accountID: account.accountID) ?? account
    }

    private var isAccountActionDisabled: Bool {
        !currentAccount.isEnabled ||
            appModel.isRefreshing ||
            appModel.refreshStatus(for: currentAccount) == .refreshing
    }

    private var refreshButtonTitle: String {
        appModel.refreshStatus(for: currentAccount) == .refreshing ? "Refreshing…" : "Refresh"
    }

    private var usageURL: URL? {
        appModel.usageURL(providerID: currentAccount.providerID, accountID: currentAccount.accountID)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { currentAccount.isEnabled },
            set: {
                appModel.setAccount(
                    currentAccount.providerID,
                    accountID: currentAccount.accountID,
                    enabled: $0
                )
            }
        )
    }
}

struct SettingsGlassIcon: View {
    let systemName: String
    var verticalOffset: CGFloat = 0

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 20, height: 20)
            .offset(y: verticalOffset)
    }
}

extension View {
    func settingsGlassIconButton(help: String) -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .help(help)
    }

}

struct AccountEditorDraft: Equatable {
    var providerID: String
    var displayName: String
    var isEnabled: Bool
    var sourceMode: ProviderSourceMode
    var localSnapshotPath: String

    init(
        providerID: String,
        displayName: String = "",
        isEnabled: Bool = true,
        sourceMode: ProviderSourceMode = .manual,
        localSnapshotPath: String = ""
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.sourceMode = sourceMode
        self.localSnapshotPath = localSnapshotPath
    }

    init(account: ProviderAccount?, defaultProviderID: String) {
        self.init(
            providerID: account?.providerID ?? defaultProviderID,
            displayName: account?.displayName ?? "",
            isEnabled: account?.isEnabled ?? true,
            sourceMode: account?.sourceMode ?? .manual,
            localSnapshotPath: account?.localSnapshotPath ?? ""
        )
    }

    var normalizedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ProviderAccount.defaultDisplayName : trimmed
    }

    var normalizedSnapshotPath: String? {
        let trimmed = localSnapshotPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func hasChanges(comparedTo original: AccountEditorDraft) -> Bool {
        providerID != original.providerID ||
            normalizedDisplayName != original.normalizedDisplayName ||
            isEnabled != original.isEnabled ||
            sourceMode != original.sourceMode ||
            normalizedSnapshotPath != original.normalizedSnapshotPath
    }
}

struct AccountEditorView: View {
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount?
    @Binding var isDirty: Bool
    let onCancel: () -> Void
    let onCreate: (String) -> Void
    let onSave: () -> Void

    private let initialDraft: AccountEditorDraft
    @State private var draft: AccountEditorDraft
    @State private var helperSetupMessage: String?
    @State private var helperSetupError: String?

    init(
        appModel: AppModel,
        account: ProviderAccount?,
        isDirty: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onCreate: @escaping (String) -> Void,
        onSave: @escaping () -> Void
    ) {
        self.appModel = appModel
        self.account = account
        self._isDirty = isDirty
        self.onCancel = onCancel
        self.onCreate = onCreate
        self.onSave = onSave

        let initialDraft = AccountEditorDraft(
            account: account,
            defaultProviderID: appModel.providerIDs.first ?? ""
        )
        self.initialDraft = initialDraft
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(account == nil ? "New Account" : "Edit Account")
                        .font(.title3.weight(.semibold))

                    Text(account == nil ? "Add a provider account to track its usage." : "Save to apply account configuration changes.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Form {
                Section("Account") {
                    if account == nil {
                        Picker("Provider", selection: $draft.providerID) {
                            ForEach(appModel.providerIDs, id: \.self) { providerID in
                                Text(appModel.providerDisplayName(for: providerID)).tag(providerID)
                            }
                        }
                    } else {
                        LabeledContent("Provider", value: appModel.providerDisplayName(for: draft.providerID))
                    }

                    TextField("Account Name", text: $draft.displayName)
                    if account == nil {
                        Toggle("Enabled", isOn: $draft.isEnabled)
                    }
                }

                if draft.providerID == "claude-code" {
                    Section("Source") {
                        Picker("Source", selection: $draft.sourceMode) {
                            Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                            Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
                        }
                        .pickerStyle(.segmented)

                        TextField("Local snapshot JSON path", text: $draft.localSnapshotPath)
                            .disabled(draft.sourceMode != .localSnapshot)

                        if draft.sourceMode == .localSnapshot {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Claude Code statusLine helper")
                                    .font(.subheadline.weight(.semibold))

                                Text("The helper reads Claude Code's official statusLine JSON and writes local-estimate rate-limit data. It replaces the current custom statusLine only after you apply the shown configuration.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Install or Repair Helper", action: installHelper)

                                if let helperPathConflict {
                                    Text(helperPathConflict)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                if let helperSetupMessage {
                                    Text(helperSetupMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                if let helperSetupError {
                                    Text(helperSetupError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Section("Source") {
                        LabeledContent("Source", value: ProviderSourceMode.manual.displayName)
                    }
                }

                Section {
                    HStack {
                        Spacer()

                        Button("Cancel", action: onCancel)
                            .keyboardShortcut(.cancelAction)

                        Button(account == nil ? "Create" : "Save", action: save)
                            .keyboardShortcut(.defaultAction)
                            .disabled(draft.providerID.isEmpty || (account != nil && !isDirty) || helperPathConflict != nil)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollBounceBehavior(.basedOnSize)
            .onAppear {
                updateDirtyState()
            }
            .onChange(of: draft) { _, _ in
                updateDirtyState()
            }
        }
    }

    private func save() {
        if let account {
            guard appModel.updateAccount(
                providerID: account.providerID,
                accountID: account.accountID,
                displayName: draft.normalizedDisplayName,
                sourceMode: draft.sourceMode,
                localSnapshotPath: draft.normalizedSnapshotPath
            ) else { return }
            onSave()
            return
        }

        guard let createdAccount = appModel.addAccount(
            providerID: draft.providerID,
            displayName: draft.normalizedDisplayName,
            isEnabled: draft.isEnabled,
            sourceMode: draft.providerID == "claude-code" ? draft.sourceMode : .manual,
            localSnapshotPath: draft.providerID == "claude-code" ? draft.normalizedSnapshotPath : nil
        ) else { return }
        onCreate(createdAccount.id)
    }

    private func updateDirtyState() {
        isDirty = draft.hasChanges(comparedTo: initialDraft)
    }

    private var helperPathConflict: String? {
        guard draft.providerID == "claude-code",
              draft.sourceMode == .localSnapshot,
              let defaultURL = try? ClaudeCodeStatusLinePaths.snapshotURL()
        else { return nil }

        let normalizedDraftPath = URL(fileURLWithPath: (draft.localSnapshotPath as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
        guard normalizedDraftPath == defaultURL.standardizedFileURL.path else { return nil }

        let currentAccountID = account?.accountID
        let isUsedByAnotherAccount = appModel.providerAccounts.contains {
            $0.providerID == "claude-code" &&
                $0.localSnapshotPath.map { normalizedPath($0) } == normalizedDraftPath &&
                $0.accountID != currentAccountID
        }
        guard isUsedByAnotherAccount else { return nil }
        return "The managed Claude Code helper path is already assigned to another account. Use a different local snapshot path for this account."
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }

    private func installHelper() {
        do {
            let installer = ClaudeCodeStatusLineInstaller()
            let helperURL = try installer.install()
            let snapshotURL = try installer.defaultSnapshotURL()
            draft.sourceMode = .localSnapshot
            draft.localSnapshotPath = snapshotURL.path
            helperSetupError = nil
            helperSetupMessage = "Installed at \(helperURL.path). Add this object to ~/.claude/settings.json:\n\n\(installer.settingsSnippet(helperURL: helperURL, snapshotURL: snapshotURL))"
        } catch {
            helperSetupMessage = nil
            helperSetupError = error.localizedDescription
        }
    }
}
