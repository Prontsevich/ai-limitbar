import AILimitBarCore
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    let enableTextFieldPrewarming: Bool
    @State private var selection = SettingsSection.accounts
    @State private var isAddingAccount = false
    @State private var contentResetID = UUID()

    init(appModel: AppModel, enableTextFieldPrewarming: Bool = true) {
        self.appModel = appModel
        self.enableTextFieldPrewarming = enableTextFieldPrewarming
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            content
                .id(contentResetID)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 520, idealHeight: 600)
        .background {
            SettingsWindowCloseObserver {
                resetTransientState()
            }
            .frame(width: 0, height: 0)

            if enableTextFieldPrewarming {
                TextFieldFocusPrewarmer()
                    .frame(width: 0, height: 0)
            }
        }
        .onDisappear {
            resetTransientState()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ForEach(SettingsSection.allCases) { section in
                SettingsSidebarButton(
                    section: section,
                    isSelected: selection == section
                ) {
                    selection = section
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 184)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .accounts:
            AccountsSettingsPane(
                appModel: appModel,
                isAddingAccount: $isAddingAccount
            )
        case .refresh:
            RefreshSettingsPane(appModel: appModel)
        case .providerSetup:
            ProviderSetupSettingsPane(appModel: appModel)
        }
    }

    private func resetTransientState() {
        isAddingAccount = false
        contentResetID = UUID()
        dismissFocusedTextField()
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case accounts
    case refresh
    case providerSetup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accounts: "Accounts"
        case .refresh: "Refresh"
        case .providerSetup: "Provider Setup"
        }
    }

    var systemImage: String {
        switch self {
        case .accounts: "person.crop.square.stack"
        case .refresh: "arrow.clockwise"
        case .providerSetup: "key.horizontal"
        }
    }
}

private struct SettingsSidebarButton: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(section.title, systemImage: section.systemImage)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.selection.opacity(0.18))
                    }
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

private struct AccountsSettingsPane: View {
    @ObservedObject var appModel: AppModel
    @Binding var isAddingAccount: Bool
    @FocusState private var focusedField: SettingsFocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if isAddingAccount {
                        InlineAddAccountForm(
                            appModel: appModel,
                            focusedField: $focusedField,
                            onCancel: {
                                isAddingAccount = false
                                focusedField = nil
                                dismissFocusedTextField()
                            },
                            onCreate: {
                                isAddingAccount = false
                                focusedField = nil
                                dismissFocusedTextField()
                            }
                        )
                    }

                    if appModel.providerAccounts.isEmpty {
                        ContentUnavailableView(
                            "No Accounts",
                            systemImage: "person.crop.square.badge.plus",
                            description: Text("Create an account to start tracking usage.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        ForEach(appModel.providerAccounts) { account in
                            ProviderAccountSettingsCard(
                                appModel: appModel,
                                account: account,
                                focusedField: $focusedField
                            )
                        }
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(24)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            dismissFocusedTextField()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Accounts")
                    .font(.title2.weight(.semibold))
                Text("Account order here matches the menu bar dashboard.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isAddingAccount.toggle()
                focusedField = nil
                dismissFocusedTextField()
            } label: {
                Label(isAddingAccount ? "Cancel Add" : "Add Account", systemImage: isAddingAccount ? "xmark" : "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct RefreshSettingsPane: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Refresh")
                    .font(.title2.weight(.semibold))
                Text("Choose how often AI Limitbar refreshes enabled accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Interval", selection: refreshIntervalBinding) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Manual refresh stays available from the menu bar panel.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var refreshIntervalBinding: Binding<RefreshInterval> {
        Binding(
            get: { appModel.refreshSettings.interval },
            set: { appModel.setRefreshInterval($0) }
        )
    }
}

private struct ProviderSetupSettingsPane: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Provider Setup")
                    .font(.title2.weight(.semibold))
                Text("Provider access stays conservative until stable machine-readable sources are verified.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(appModel.providerIDs, id: \.self) { providerID in
                    ProviderSetupRow(appModel: appModel, providerID: providerID)
                }
            }

            GroupBox("Credentials") {
                Text("Credential entry is disabled until real provider requirements are verified.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ProviderSetupRow: View {
    @ObservedObject var appModel: AppModel
    let providerID: String

    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.providerDisplayName(for: providerID))
                        .font(.headline)
                    Text(sourceSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appModel.openUsagePage(providerID: providerID)
                } label: {
                    Label("Open Usage", systemImage: "arrow.up.forward.square")
                }
                .disabled(appModel.adapter(for: providerID)?.usageURL == nil)
            }
            .padding(4)
        }
    }

    private var sourceSummary: String {
        providerID == "claude-code" ? "Manual or local snapshot source" : "Manual source"
    }
}

private struct InlineAddAccountForm: View {
    @ObservedObject var appModel: AppModel
    let focusedField: FocusState<SettingsFocusField?>.Binding
    let onCancel: () -> Void
    let onCreate: () -> Void
    @State private var providerID: String
    @State private var displayName = ""
    @State private var isEnabled = true
    @State private var sourceMode = ProviderSourceMode.manual
    @State private var localSnapshotPath = ""

    init(
        appModel: AppModel,
        focusedField: FocusState<SettingsFocusField?>.Binding,
        onCancel: @escaping () -> Void,
        onCreate: @escaping () -> Void
    ) {
        self.appModel = appModel
        self.focusedField = focusedField
        self.onCancel = onCancel
        self.onCreate = onCreate
        _providerID = State(initialValue: appModel.providerIDs.first ?? "")
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Add Account", systemImage: "plus.circle")
                        .font(.headline)

                    Spacer()

                    HStack(alignment: .center, spacing: 5) {
                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                            .frame(width: 16, height: 16)

                        Text("Enabled")
                            .font(.callout.weight(.medium))
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    GridRow {
                        Text("Provider")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Provider", selection: $providerID) {
                            ForEach(appModel.providerIDs, id: \.self) { providerID in
                                Text(appModel.providerDisplayName(for: providerID)).tag(providerID)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 280, alignment: .leading)
                    }

                    GridRow {
                        Text("Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Optional account name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .focused(focusedField, equals: .newAccountName)
                    }

                    if providerID == "claude-code" {
                        GridRow {
                            Text("Source")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Source", selection: $sourceMode) {
                                Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                                Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 260, alignment: .leading)
                        }

                        GridRow {
                            Text("Snapshot")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Local snapshot JSON path", text: $localSnapshotPath)
                                .textFieldStyle(.roundedBorder)
                                .focused(focusedField, equals: .newLocalSnapshotPath)
                                .disabled(sourceMode != .localSnapshot)
                        }
                    }
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Create") {
                        appModel.addAccount(
                            providerID: providerID,
                            displayName: displayName,
                            isEnabled: isEnabled,
                            sourceMode: providerID == "claude-code" ? sourceMode : .manual,
                            localSnapshotPath: providerID == "claude-code" ? localSnapshotPath : nil
                        )
                        onCreate()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(providerID.isEmpty)
                }
            }
            .padding(4)
        }
    }
}

private struct ProviderAccountSettingsCard: View {
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount
    let focusedField: FocusState<SettingsFocusField?>.Binding
    @State private var isRenaming = false
    @State private var draftDisplayName = ""
    @State private var isSourceExpanded = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                header

                if currentAccount.providerID == "claude-code", isSourceExpanded {
                    sourceConfiguration
                }

                Divider()

                actions
            }
            .padding(4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField.wrappedValue = nil
            dismissFocusedTextField()
        }
        .alert("Delete Account?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                appModel.deleteAccount(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(currentAccount.displayName) and its stored snapshot from AI Limitbar.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                titleRow

                HStack(spacing: 8) {
                    Label(appModel.providerDisplayName(for: currentAccount.providerID), systemImage: "server.rack")
                    Text("·")
                    Text(currentAccount.sourceMode.displayName)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 360, alignment: .leading)

            Spacer()

            enabledControl
                .frame(height: 28, alignment: .center)
        }
    }

    private var enabledControl: some View {
        HStack(alignment: .center, spacing: 5) {
            Toggle("", isOn: enabledBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .frame(width: 16, height: 16)

            Text("Enabled")
                .font(.callout.weight(.medium))
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            if isRenaming {
                TextField("Account name", text: $draftDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.weight(.semibold))
                    .frame(width: 310)
                    .focused(focusedField, equals: .accountName(currentAccount.id))
                    .onSubmit {
                        commitRename()
                    }

                Button {
                    commitRename()
                } label: {
                    Image(systemName: "checkmark")
                        .frame(width: 14)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Save account name")

                Button {
                    cancelRename()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 14)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Cancel rename")
            } else {
                Text(currentAccount.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Button {
                    beginRename()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .help("Rename account")
            }
        }
        .frame(height: 28, alignment: .center)
    }

    private var sourceConfiguration: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Source", selection: sourceModeBinding) {
                    Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                    Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(!currentAccount.isEnabled)
                .frame(maxWidth: 260, alignment: .leading)
            }

            GridRow {
                Text("Snapshot")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Local snapshot JSON path", text: localSnapshotPathBinding)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .localSnapshotPath(currentAccount.id))
                    .disabled(!currentAccount.isEnabled || currentAccount.sourceMode != .localSnapshot)
            }
        }
        .padding(.top, 2)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                appModel.moveAccountUp(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Move account up")
            .disabled(!appModel.canMoveAccountUp(
                providerID: currentAccount.providerID,
                accountID: currentAccount.accountID
            ))

            Button {
                appModel.moveAccountDown(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Move account down")
            .disabled(!appModel.canMoveAccountDown(
                providerID: currentAccount.providerID,
                accountID: currentAccount.accountID
            ))

            Spacer()

            if currentAccount.providerID == "claude-code" {
                Button {
                    isSourceExpanded.toggle()
                    focusedField.wrappedValue = nil
                    dismissFocusedTextField()
                } label: {
                    Label(isSourceExpanded ? "Hide Source" : "Source Settings", systemImage: "slider.horizontal.3")
                }
            }

            Button {
                appModel.testConnection(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            } label: {
                Label(testButtonTitle, systemImage: "checkmark.circle")
            }
            .disabled(isActionDisabled)

            Button {
                appModel.openUsagePage(
                    providerID: currentAccount.providerID,
                    accountID: currentAccount.accountID
                )
            } label: {
                Label("Open Usage", systemImage: "arrow.up.forward.square")
            }
            .disabled(appModel.adapter(for: currentAccount.providerID)?.usageURL == nil)

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Delete account")
            .disabled(!appModel.canDeleteAccount(
                providerID: currentAccount.providerID,
                accountID: currentAccount.accountID
            ))
        }
        .controlSize(.regular)
    }

    private func beginRename() {
        draftDisplayName = currentAccount.displayName
        isRenaming = true
        focusedField.wrappedValue = .accountName(currentAccount.id)
    }

    private func commitRename() {
        appModel.setAccountDisplayName(
            currentAccount.providerID,
            accountID: currentAccount.accountID,
            displayName: draftDisplayName
        )
        isRenaming = false
        focusedField.wrappedValue = nil
        dismissFocusedTextField()
    }

    private func cancelRename() {
        draftDisplayName = currentAccount.displayName
        isRenaming = false
        focusedField.wrappedValue = nil
        dismissFocusedTextField()
    }

    private var currentAccount: ProviderAccount {
        appModel.account(providerID: account.providerID, accountID: account.accountID) ?? account
    }

    private var isActionDisabled: Bool {
        !currentAccount.isEnabled ||
            appModel.isRefreshing ||
            appModel.refreshStatus(for: currentAccount) == .refreshing
    }

    private var testButtonTitle: String {
        appModel.refreshStatus(for: currentAccount) == .refreshing ? "Testing" : "Test Connection"
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

    private var sourceModeBinding: Binding<ProviderSourceMode> {
        Binding(
            get: { currentAccount.sourceMode },
            set: {
                appModel.setAccountSourceMode(
                    currentAccount.providerID,
                    accountID: currentAccount.accountID,
                    sourceMode: $0
                )
            }
        )
    }

    private var localSnapshotPathBinding: Binding<String> {
        Binding(
            get: { currentAccount.localSnapshotPath ?? "" },
            set: {
                appModel.setAccountLocalSnapshotPath(
                    currentAccount.providerID,
                    accountID: currentAccount.accountID,
                    path: $0
                )
            }
        )
    }
}

private enum SettingsFocusField: Hashable {
    case accountName(String)
    case localSnapshotPath(String)
    case newAccountName
    case newLocalSnapshotPath
}

private struct SettingsWindowCloseObserver: NSViewRepresentable {
    let onWillClose: () -> Void

    func makeNSView(context: Context) -> SettingsWindowCloseObserverView {
        let view = SettingsWindowCloseObserverView()
        view.onWillClose = onWillClose
        return view
    }

    func updateNSView(_ nsView: SettingsWindowCloseObserverView, context: Context) {
        nsView.onWillClose = onWillClose
    }
}

private final class SettingsWindowCloseObserverView: NSView {
    var onWillClose: (() -> Void)?
    private weak var observedWindow: NSWindow?
    private var observer: NSObjectProtocol?

    deinit {
        removeObserver()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateObserver()
    }

    private func updateObserver() {
        guard observedWindow !== window else { return }
        removeObserver()
        observedWindow = window

        guard let window else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onWillClose?()
        }
    }

    private func removeObserver() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        observedWindow = nil
    }
}

private struct TextFieldFocusPrewarmer: NSViewRepresentable {
    func makeNSView(context: Context) -> TextFieldFocusPrewarmView {
        TextFieldFocusPrewarmView()
    }

    func updateNSView(_ nsView: TextFieldFocusPrewarmView, context: Context) {}
}

private final class TextFieldFocusPrewarmView: NSView {
    private var didPrewarm = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didPrewarm, let window else { return }
        didPrewarm = true

        // Prewarm AppKit's field editor before the first visible inline rename.
        // Without this, the first focused TextField in this accessory settings window
        // can briefly flicker while macOS lazily initializes text focus handling.
        let textField = NSTextField(frame: NSRect(x: -10_000, y: -10_000, width: 1, height: 1))
        textField.focusRingType = .none
        textField.alphaValue = 0
        textField.stringValue = ""
        addSubview(textField)

        window.makeFirstResponder(textField)
        window.makeFirstResponder(nil)
        textField.removeFromSuperview()
    }
}

private func dismissFocusedTextField() {
    NSApp.keyWindow?.makeFirstResponder(nil)
}
