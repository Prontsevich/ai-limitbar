import AILimitBarCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var isShowingAddAccount = false

    var body: some View {
        Form {
            Section {
                let accountProviderIDs = appModel.providerIDs.filter { !appModel.accounts(for: $0).isEmpty }
                if accountProviderIDs.isEmpty {
                    Text("No accounts. Create an account to start tracking usage.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accountProviderIDs, id: \.self) { providerID in
                        ProviderAccountsSection(appModel: appModel, providerID: providerID)
                    }
                }
            } header: {
                HStack {
                    Text("Accounts")
                    Spacer()
                    Button {
                        isShowingAddAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus.circle")
                    }
                }
            }

            Section("Refresh") {
                Picker("Interval", selection: refreshIntervalBinding) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Credentials") {
                Text("Credential entry is disabled until real provider requirements are verified.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 680, height: 560)
        .sheet(isPresented: $isShowingAddAccount) {
            AddAccountSheet(appModel: appModel)
        }
    }

    private var refreshIntervalBinding: Binding<RefreshInterval> {
        Binding(
            get: { appModel.refreshSettings.interval },
            set: { appModel.setRefreshInterval($0) }
        )
    }
}

private struct ProviderAccountsSection: View {
    @ObservedObject var appModel: AppModel
    let providerID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appModel.providerDisplayName(for: providerID))
                .font(.headline)
            let accounts = appModel.accounts(for: providerID)
            ForEach(accounts) { account in
                ProviderAccountSettingsRow(appModel: appModel, account: account)
            }
        }
    }
}

private struct AddAccountSheet: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var providerID: String
    @State private var displayName = ""
    @State private var isEnabled = true
    @State private var sourceMode = ProviderSourceMode.manual
    @State private var localSnapshotPath = ""

    init(appModel: AppModel) {
        self.appModel = appModel
        _providerID = State(initialValue: appModel.providerIDs.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Account")
                .font(.title3.weight(.semibold))

            Form {
                Picker("Provider", selection: $providerID) {
                    ForEach(appModel.providerIDs, id: \.self) { providerID in
                        Text(appModel.providerDisplayName(for: providerID)).tag(providerID)
                    }
                }

                TextField("Account name", text: $displayName)

                Toggle("Enabled", isOn: $isEnabled)

                if providerID == "claude-code" {
                    Picker("Source", selection: $sourceMode) {
                        Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                        Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
                    }
                    .pickerStyle(.segmented)

                    TextField("Local snapshot JSON path", text: $localSnapshotPath)
                        .disabled(sourceMode != .localSnapshot)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
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
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(providerID.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

private struct ProviderAccountSettingsRow: View {
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)

                TextField("Account name", text: displayNameBinding)
                    .textFieldStyle(.roundedBorder)

                Button {
                    appModel.testConnection(providerID: account.providerID, accountID: account.accountID)
                } label: {
                    Label("Test", systemImage: "checkmark.circle")
                }
                .disabled(!currentAccount.isEnabled || appModel.isRefreshing || appModel.refreshStatus(for: currentAccount) == .refreshing)

                Button {
                    appModel.openUsagePage(providerID: account.providerID)
                } label: {
                    Label("Open Usage", systemImage: "arrow.up.forward.square")
                }
                .disabled(appModel.adapter(for: account.providerID)?.usageURL == nil)

                Button(role: .destructive) {
                    appModel.deleteAccount(providerID: account.providerID, accountID: account.accountID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if account.providerID == "claude-code" {
                claudeCodeConfiguration
            }
        }
        .padding(.vertical, 4)
    }

    private var claudeCodeConfiguration: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Source", selection: sourceModeBinding) {
                Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
            }
            .pickerStyle(.segmented)
            .disabled(!currentAccount.isEnabled)

            TextField("Local snapshot JSON path", text: localSnapshotPathBinding)
                .textFieldStyle(.roundedBorder)
                .disabled(!currentAccount.isEnabled || currentAccount.sourceMode != .localSnapshot)
        }
    }

    private var currentAccount: ProviderAccount {
        appModel.account(providerID: account.providerID, accountID: account.accountID) ?? account
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { currentAccount.isEnabled },
            set: {
                appModel.setAccount(
                    account.providerID,
                    accountID: account.accountID,
                    enabled: $0
                )
            }
        )
    }

    private var displayNameBinding: Binding<String> {
        Binding(
            get: { currentAccount.displayName },
            set: {
                appModel.setAccountDisplayName(
                    account.providerID,
                    accountID: account.accountID,
                    displayName: $0
                )
            }
        )
    }

    private var sourceModeBinding: Binding<ProviderSourceMode> {
        Binding(
            get: { currentAccount.sourceMode },
            set: {
                appModel.setAccountSourceMode(
                    account.providerID,
                    accountID: account.accountID,
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
                    account.providerID,
                    accountID: account.accountID,
                    path: $0
                )
            }
        )
    }
}
