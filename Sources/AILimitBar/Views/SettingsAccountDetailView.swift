import AILimitBarCore
import SwiftUI
import UniformTypeIdentifiers

struct AccountDetailView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount
    let onEdit: () -> Void

    @State private var isShowingOllamaConnection = false
    @State private var connectionError: String?

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
                    if let codexExecutablePath = currentAccount.codexExecutablePath, !codexExecutablePath.isEmpty {
                        LabeledContent("Codex executable", value: codexExecutablePath)
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

                if !appModel.migrationDiagnostics(for: currentAccount).isEmpty {
                    Section("Migration") {
                        ForEach(appModel.migrationDiagnostics(for: currentAccount)) { diagnostic in
                            Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollBounceBehavior(.basedOnSize)
        }
        .sheet(isPresented: $isShowingOllamaConnection) {
            if let client = appModel.ollamaWebPageClient,
               let connectedAccount = appModel.account(
                   providerID: account.providerID,
                   accountID: account.accountID
               ) {
                OllamaWebPageConnectionSheet(
                    appModel: appModel,
                    account: connectedAccount,
                    client: client
                )
            }
        }
        .alert("Ollama Connection", isPresented: connectionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectionError ?? "Ollama connection is unavailable.")
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

            if currentAccount.providerID == "ollama-cloud",
               currentAccount.sourceMode == .ollamaWebPage {
                Button(action: beginOllamaConnection) {
                    SettingsGlassIcon(systemName: "person.crop.circle.badge.checkmark")
                }
                .disabled(appModel.ollamaWebPageClient == nil)
                .settingsGlassIconButton(help: ollamaConnectionTitle)
                .frame(width: 40, height: 40)
            }

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

    private var ollamaConnectionTitle: String {
        currentAccount.webDataStoreID == nil ? "Connect Ollama" : "Reconnect Ollama"
    }

    private func beginOllamaConnection() {
        guard appModel.ollamaWebPageClient != nil,
              appModel.prepareOllamaWebPageConnection(
                  providerID: currentAccount.providerID,
                  accountID: currentAccount.accountID
              ) != nil
        else {
            connectionError = "Save the account before connecting Ollama through AI Limitbar."
            return
        }
        isShowingOllamaConnection = true
    }

    private var connectionErrorBinding: Binding<Bool> {
        Binding(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
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
    var codexExecutablePath: String

    init(
        providerID: String,
        displayName: String = "",
        isEnabled: Bool = true,
        sourceMode: ProviderSourceMode = .manual,
        codexExecutablePath: String = ""
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.sourceMode = sourceMode
        self.codexExecutablePath = codexExecutablePath
    }

    init(account: ProviderAccount?, defaultProviderID: String) {
        self.init(
            providerID: account?.providerID ?? defaultProviderID,
            displayName: account?.displayName ?? "",
            isEnabled: account?.isEnabled ?? true,
            sourceMode: account?.sourceMode ?? .manual,
            codexExecutablePath: account?.codexExecutablePath ?? ""
        )
    }

    var normalizedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ProviderAccount.defaultDisplayName : trimmed
    }

    var normalizedCodexExecutablePath: String? {
        let trimmed = codexExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func hasChanges(comparedTo original: AccountEditorDraft) -> Bool {
        providerID != original.providerID ||
            normalizedDisplayName != original.normalizedDisplayName ||
            isEnabled != original.isEnabled ||
            sourceMode != original.sourceMode ||
            normalizedCodexExecutablePath != original.normalizedCodexExecutablePath
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
    @State private var isSelectingCodexExecutable = false

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
                    if let displayNameConflict {
                        Text(displayNameConflict)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if account == nil {
                        Toggle("Enabled", isOn: $draft.isEnabled)
                    }
                }

                if draft.providerID == "claude-code" {
                    Section("Source") {
                        Picker("Source", selection: $draft.sourceMode) {
                            Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                            Text(ProviderSourceMode.claudeStatusLine.displayName).tag(ProviderSourceMode.claudeStatusLine)
                        }
                        .pickerStyle(.segmented)

                        if draft.sourceMode == .claudeStatusLine {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Claude Code statusLine helper")
                                    .font(.subheadline.weight(.semibold))

                                Text("The helper reads Claude Code's official statusLine JSON and writes local-estimate rate-limit data to AI Limitbar's managed database. No JSON path is configured or retained.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Install or Repair Helper", action: installHelper)
                                    .disabled(account == nil)

                                if account == nil {
                                    Text("Save this account first, then install its helper configuration.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                } else if draft.providerID == "ollama-cloud" {
                    Section("Source") {
                        Picker("Source", selection: $draft.sourceMode) {
                            Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                            Text(ProviderSourceMode.ollamaWebPage.displayName).tag(ProviderSourceMode.ollamaWebPage)
                        }
                        .pickerStyle(.segmented)

                        if draft.sourceMode == .ollamaWebPage {
                            Text("Experimental source: AI Limitbar opens an isolated WebKit session for https://ollama.com/settings. The session is never copied from another browser, and raw page content is not stored.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else if draft.providerID == "openai-codex" {
                    Section("Source") {
                        Picker("Source", selection: $draft.sourceMode) {
                            Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                            Text(ProviderSourceMode.appServer.displayName).tag(ProviderSourceMode.appServer)
                        }
                        .pickerStyle(.segmented)

                        if draft.sourceMode == .appServer {
                            Text("Experimental source: AI Limitbar starts a short-lived local Codex app-server to read current rate-limit windows. It never reads Codex credentials, session files, browser data, or terminal output.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            TextField("Codex executable path (optional)", text: $draft.codexExecutablePath)

                            HStack {
                                Text("Leave blank to locate Codex automatically.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Browse…") {
                                    isSelectingCodexExecutable = true
                                }
                            }

                            if let codexAppServerConflict {
                                Text(codexAppServerConflict)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                            .disabled(
                                draft.providerID.isEmpty ||
                                (account != nil && !isDirty) ||
                                    displayNameConflict != nil ||
                                    codexAppServerConflict != nil
                            )
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
            .fileImporter(
                isPresented: $isSelectingCodexExecutable,
                allowedContentTypes: [.executable],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    draft.codexExecutablePath = url.path
                }
            }
        }
    }

    private func save() {
        if let account {
            guard appModel.updateAccount(
                providerID: account.providerID,
                accountID: account.accountID,
                displayName: draft.normalizedDisplayName,
                sourceMode: persistedSourceMode,
                codexExecutablePath: persistedCodexExecutablePath
            ) else { return }
            onSave()
            return
        }

        guard let createdAccount = appModel.addAccount(
            providerID: draft.providerID,
            displayName: draft.normalizedDisplayName,
            isEnabled: draft.isEnabled,
            sourceMode: persistedSourceMode,
            codexExecutablePath: persistedCodexExecutablePath
        ) else { return }
        onCreate(createdAccount.id)
    }

    private func updateDirtyState() {
        isDirty = draft.hasChanges(comparedTo: initialDraft)
    }

    private var persistedSourceMode: ProviderSourceMode {
        switch draft.providerID {
        case "claude-code", "ollama-cloud", "openai-codex": draft.sourceMode
        default: .manual
        }
    }

    private var persistedCodexExecutablePath: String? {
        draft.providerID == "openai-codex" ? draft.normalizedCodexExecutablePath : nil
    }

    private var codexAppServerConflict: String? {
        guard draft.providerID == "openai-codex",
              draft.sourceMode == .appServer,
              appModel.hasCodexAppServerConflict(
                  providerID: draft.providerID,
                  accountID: account?.accountID,
                  sourceMode: draft.sourceMode
              )
        else { return nil }

        return "Only one OpenAI Codex account can use the local app-server source because it reads the active local Codex CLI session."
    }

    private var displayNameConflict: String? {
        guard appModel.hasDisplayNameConflict(
            accountID: account?.accountID,
            displayName: draft.normalizedDisplayName
        ) else { return nil }
        return "Account names must be globally unique, including disabled accounts."
    }

    private func installHelper() {
        guard let account else {
            helperSetupError = "Save the account before installing its statusLine helper."
            return
        }
        do {
            let installer = ClaudeCodeStatusLineInstaller()
            let helperURL = try installer.install()
            draft.sourceMode = .claudeStatusLine
            helperSetupError = nil
            helperSetupMessage = "Installed at \(helperURL.path). Add this object to ~/.claude/settings.json:\n\n\(installer.settingsSnippet(helperURL: helperURL, accountID: account.accountID))"
        } catch {
            helperSetupMessage = nil
            helperSetupError = error.localizedDescription
        }
    }
}
