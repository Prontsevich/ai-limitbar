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

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TerminalFieldset(title: "STATUS") {
                        EmptyView()
                    } content: {
                        SettingsDetailValueRow(
                            label: "Source",
                            value: currentAccount.sourceMode.displayName,
                            isTechnical: true
                        )
                        SettingsDetailValueRow(
                            label: "Refresh",
                            value: appModel.refreshStatus(for: currentAccount).displayName
                        )
                        SettingsDetailValueRow(
                            label: "Last updated",
                            value: lastUpdatedText,
                            isTechnical: true
                        )
                    }

                    TerminalFieldset(title: "CONFIGURATION") {
                        EmptyView()
                    } content: {
                        SettingsDetailValueRow(
                            label: "Provider",
                            value: appModel.providerDisplayName(for: currentAccount.providerID)
                        )
                        if let executableLabel,
                           let executablePath = currentAccount.executablePath,
                           !executablePath.isEmpty {
                            SettingsDetailValueRow(
                                label: executableLabel,
                                value: executablePath,
                                isTechnical: true
                            )
                        }
                    }

                    if !appModel.migrationDiagnostics(for: currentAccount).isEmpty {
                        TerminalFieldset(title: "MIGRATION") {
                            EmptyView()
                        } content: {
                            ForEach(appModel.migrationDiagnostics(for: currentAccount)) { diagnostic in
                                Label(diagnostic.message, systemImage: "exclamationmark.triangle")
                                    .font(TerminalTheme.bodyFont)
                                    .foregroundStyle(TerminalTheme.warning)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            VStack(alignment: .leading, spacing: 2) {
                Text(currentAccount.displayName)
                    .font(TerminalTheme.titleFont)
                    .foregroundStyle(TerminalTheme.primary)
                Text(appModel.providerDisplayName(for: currentAccount.providerID))
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }

            Spacer()

            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(TerminalToggleStyle())

            Button(action: onEdit) {
                SettingsActionIcon(systemName: "square.and.pencil", verticalOffset: -1)
            }
            .settingsIconButton(help: "Edit account")
            .frame(width: 32, height: 32)

            if currentAccount.providerID == "ollama-cloud",
               currentAccount.sourceMode == .ollamaWebPage {
                Button(action: beginOllamaConnection) {
                    SettingsActionIcon(systemName: "person.crop.circle.badge.checkmark")
                }
                .disabled(appModel.ollamaWebPageClient == nil)
                .settingsIconButton(help: ollamaConnectionTitle)
                .frame(width: 32, height: 32)
            }

            Button {
                appModel.refreshAccount(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            } label: {
                SettingsActionIcon(systemName: "arrow.clockwise")
            }
            .disabled(isAccountActionDisabled)
            .settingsIconButton(help: refreshButtonTitle)
            .frame(width: 32, height: 32)

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
            .frame(width: 32, height: 32)
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

    private var executableLabel: String? {
        switch (currentAccount.providerID, currentAccount.sourceMode) {
        case ("openai-codex", .appServer):
            "Codex executable"
        case ("claude-code", .claudeUsageCLI):
            "Claude executable"
        default:
            nil
        }
    }

    private var lastUpdatedText: String {
        guard let snapshot = appModel.snapshot(for: currentAccount) else {
            return "No usage data"
        }
        return snapshot.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened)
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

private struct SettingsDetailValueRow: View {
    let label: String
    let value: String
    var isTechnical = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(TerminalTheme.detailLabelFont)
                .foregroundStyle(TerminalTheme.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(isTechnical ? TerminalTheme.bodyFont : TerminalTheme.detailValueFont)
                .foregroundStyle(TerminalTheme.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsActionIcon: View {
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
    func settingsIconButton(help: String) -> some View {
        buttonStyle(TerminalIconButtonStyle())
            .help(help)
    }
}

struct AccountEditorDraft: Equatable {
    var providerID: String
    var displayName: String
    var isEnabled: Bool
    var sourceMode: ProviderSourceMode
    var executablePath: String

    init(
        providerID: String,
        displayName: String = "",
        isEnabled: Bool = true,
        sourceMode: ProviderSourceMode? = nil,
        executablePath: String = ""
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.sourceMode = ProviderSourceMode.resolvedMode(sourceMode, for: providerID)
        self.executablePath = executablePath
    }

    init(account: ProviderAccount?, defaultProviderID: String) {
        let providerID = account?.providerID ?? defaultProviderID
        self.init(
            providerID: providerID,
            displayName: account?.displayName ?? "",
            isEnabled: account?.isEnabled ?? true,
            sourceMode: account?.sourceMode,
            executablePath: account?.executablePath ?? ""
        )
    }

    var normalizedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ProviderAccount.defaultDisplayName : trimmed
    }

    var normalizedExecutablePath: String? {
        let trimmed = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func hasChanges(comparedTo original: AccountEditorDraft) -> Bool {
        providerID != original.providerID ||
            normalizedDisplayName != original.normalizedDisplayName ||
            isEnabled != original.isEnabled ||
            sourceMode != original.sourceMode ||
            normalizedExecutablePath != original.normalizedExecutablePath
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
    @State private var isSelectingExecutable = false

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
            defaultProviderID: appModel.providerIDs.first(where: appModel.canAddAccount) ?? ""
        )
        self.initialDraft = initialDraft
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    accountFieldset
                    if hasSourceConfiguration {
                        sourceFieldset
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            Divider()

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(TerminalActionButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button(account == nil ? "Create" : "Save", action: save)
                    .buttonStyle(TerminalActionButtonStyle(isProminent: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        draft.providerID.isEmpty ||
                        (account != nil && !isDirty) ||
                            displayNameConflict != nil ||
                            codexAppServerConflict != nil ||
                            claudeUsageCLIConflict != nil
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .onAppear {
                updateDirtyState()
            }
            .onChange(of: draft) { _, _ in
                updateDirtyState()
            }
            .onChange(of: draft.providerID) { previousProviderID, providerID in
                guard account == nil, previousProviderID != providerID else { return }
                draft.sourceMode = ProviderSourceMode.defaultMode(for: providerID)
            }
            .onChange(of: draft.sourceMode) { _, sourceMode in
                if sourceMode != .claudeStatusLine {
                    helperSetupMessage = nil
                    helperSetupError = nil
                }
            }
            .fileImporter(
                isPresented: $isSelectingExecutable,
                allowedContentTypes: [.executable],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    draft.executablePath = url.path
                }
            }
        }
    }

    private var editorHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(account == nil ? "New Account" : "Edit Account")
                    .font(TerminalTheme.titleFont)
                    .foregroundStyle(TerminalTheme.primary)

                Text(account == nil ? "Add a provider account to track its usage." : "Save to apply account configuration changes.")
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var accountFieldset: some View {
        TerminalFieldset(title: "ACCOUNT") {
            EmptyView()
        } content: {
            SettingsEditorValueRow("Provider") {
                if account == nil {
                    TerminalProviderPicker(
                        selection: $draft.providerID,
                        options: availableProviderIDs.map {
                            TerminalSegmentedOption(
                                value: $0,
                                title: appModel.providerDisplayName(for: $0)
                            )
                        }
                    )
                } else {
                    Text(appModel.providerDisplayName(for: draft.providerID))
                        .font(TerminalTheme.detailValueFont)
                        .foregroundStyle(TerminalTheme.primary)
                }
            }
            .zIndex(1)

            SettingsEditorValueRow("Account Name") {
                TerminalTextField("Account Name", text: $draft.displayName)
            }

            if let displayNameConflict {
                Text(displayNameConflict)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if account == nil {
                SettingsEditorValueRow("Enabled") {
                    Toggle("Enabled", isOn: $draft.isEnabled)
                        .labelsHidden()
                        .toggleStyle(TerminalToggleStyle())
                        .accessibilityLabel("Enabled")
                }
            }
        }
        .zIndex(1)
    }

    private var sourceFieldset: some View {
        TerminalFieldset(title: "SOURCE") {
            EmptyView()
        } content: {
            sourceSelector
            sourceDetails
        }
    }

    @ViewBuilder
    private var sourceSelector: some View {
        if draft.providerID == "claude-code" {
            SettingsEditorValueRow("Mode") {
                TerminalSegmentedControl(
                    "Claude Code source",
                    selection: $draft.sourceMode,
                    options: [
                        TerminalSegmentedOption(value: .manual, title: "Manual"),
                        TerminalSegmentedOption(value: .claudeStatusLine, title: "statusLine"),
                        TerminalSegmentedOption(value: .claudeUsageCLI, title: "/usage CLI")
                    ]
                )
                .labelsHidden()
            }
        } else if let sourceMode = configuredSourceMode {
            SettingsEditorValueRow("Mode") {
                Text(sourceMode.displayName)
                    .font(TerminalTheme.detailValueFont)
                    .foregroundStyle(TerminalTheme.primary)
            }
        }
    }

    @ViewBuilder
    private var sourceDetails: some View {
        if draft.providerID == "claude-code" {
            switch draft.sourceMode {
            case .manual:
                Text("Manual source: open the Claude usage page when you need to check plan limits. AI Limitbar does not start Claude Code or retain provider output in this mode.")
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            case .claudeStatusLine:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude Code statusLine helper")
                        .font(TerminalTheme.emphasizedBodyFont)
                        .foregroundStyle(TerminalTheme.primary)

                    Text("The helper reads Claude Code's official statusLine JSON and writes local-estimate rate-limit data to AI Limitbar's managed database. No JSON path is configured or retained.")
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Install or Repair Helper", action: installHelper)
                        .buttonStyle(TerminalActionButtonStyle())
                        .disabled(account == nil)

                    if account == nil {
                        Text("Save this account first, then install its helper configuration.")
                            .font(TerminalTheme.captionFont)
                            .foregroundStyle(TerminalTheme.secondary)
                    }

                    if let helperSetupMessage {
                        Text(helperSetupMessage)
                            .font(TerminalTheme.captionFont)
                            .foregroundStyle(TerminalTheme.secondary)
                            .textSelection(.enabled)
                    }

                    if let helperSetupError {
                        Text(helperSetupError)
                            .font(TerminalTheme.captionFont)
                            .foregroundStyle(TerminalTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            case .claudeUsageCLI:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Experimental source: AI Limitbar runs the authenticated local Claude Code CLI in safe non-interactive mode and retains only normalized plan-limit windows. Raw output, activity attribution, stderr, and session metadata are discarded.")
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SettingsEditorValueRow("Claude Path") {
                        TerminalTextField("Claude executable path", text: $draft.executablePath)
                    }

                    HStack {
                        Text("Leave blank to locate Claude automatically.")
                            .font(TerminalTheme.captionFont)
                            .foregroundStyle(TerminalTheme.secondary)
                        Spacer()
                        Button("Browse…") {
                            isSelectingExecutable = true
                        }
                        .buttonStyle(TerminalActionButtonStyle())
                    }

                    if let claudeUsageCLIConflict {
                        Text(claudeUsageCLIConflict)
                            .font(TerminalTheme.captionFont)
                            .foregroundStyle(TerminalTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            case .ollamaWebPage, .appServer:
                EmptyView()
            }
        } else if draft.providerID == "ollama-cloud" {
            Text("Experimental source: AI Limitbar opens an isolated WebKit session for https://ollama.com/settings. The session is never copied from another browser, and raw page content is not stored.")
                .font(TerminalTheme.captionFont)
                .foregroundStyle(TerminalTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        } else if draft.providerID == "openai-codex" {
            VStack(alignment: .leading, spacing: 8) {
                Text("Experimental source: AI Limitbar starts a short-lived local Codex app-server to read current rate-limit windows. It never reads Codex credentials, session files, browser data, or terminal output.")
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SettingsEditorValueRow("Codex Path") {
                    TerminalTextField("Codex executable path", text: $draft.executablePath)
                }

                HStack {
                    Text("Leave blank to locate Codex automatically.")
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.secondary)
                    Spacer()
                    Button("Browse…") {
                        isSelectingExecutable = true
                    }
                    .buttonStyle(TerminalActionButtonStyle())
                }

                if let codexAppServerConflict {
                    Text(codexAppServerConflict)
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 4)
        }
    }

    private func save() {
        if let account {
            guard appModel.updateAccount(
                providerID: account.providerID,
                accountID: account.accountID,
                displayName: draft.normalizedDisplayName,
                sourceMode: persistedSourceMode,
                executablePath: persistedExecutablePath
            ) else { return }
            onSave()
            return
        }

        guard let createdAccount = appModel.addAccount(
            providerID: draft.providerID,
            displayName: draft.normalizedDisplayName,
            isEnabled: draft.isEnabled,
            sourceMode: persistedSourceMode,
            executablePath: persistedExecutablePath
        ) else { return }
        onCreate(createdAccount.id)
    }

    private func updateDirtyState() {
        isDirty = draft.hasChanges(comparedTo: initialDraft)
    }

    private var persistedSourceMode: ProviderSourceMode {
        ProviderSourceMode.resolvedMode(draft.sourceMode, for: draft.providerID)
    }

    private var availableProviderIDs: [String] {
        appModel.providerIDs.filter(appModel.canAddAccount)
    }

    private var hasSourceConfiguration: Bool {
        configuredSourceMode != nil
    }

    private var configuredSourceMode: ProviderSourceMode? {
        switch draft.providerID {
        case "claude-code", "ollama-cloud", "openai-codex":
            ProviderSourceMode.defaultMode(for: draft.providerID)
        default:
            nil
        }
    }

    private var persistedExecutablePath: String? {
        switch draft.providerID {
        case "openai-codex", "claude-code":
            draft.normalizedExecutablePath
        default:
            nil
        }
    }

    private var codexAppServerConflict: String? {
        guard draft.providerID == "openai-codex",
              persistedSourceMode == .appServer,
              appModel.hasCodexAppServerConflict(
                  providerID: draft.providerID,
                  accountID: account?.accountID,
                  sourceMode: persistedSourceMode
              )
        else { return nil }

        return "Only one OpenAI Codex account can use the local app-server source because it reads the active local Codex CLI session."
    }

    private var claudeUsageCLIConflict: String? {
        guard draft.providerID == "claude-code",
              persistedSourceMode == .claudeUsageCLI,
              appModel.hasClaudeUsageCLIConflict(
                  providerID: draft.providerID,
                  accountID: account?.accountID,
                  sourceMode: persistedSourceMode
              )
        else { return nil }

        return "Only one Claude Code account can use /usage CLI because it reads the active local Claude CLI identity, including when the other account is disabled."
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

private struct SettingsEditorValueRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(TerminalTheme.detailLabelFont)
                .foregroundStyle(TerminalTheme.secondary)
                .frame(width: 120, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
