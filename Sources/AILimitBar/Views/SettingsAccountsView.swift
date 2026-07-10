import AILimitBarCore
import SwiftUI

struct AccountsSettingsPane: View {
    @ObservedObject var appModel: AppModel
    @Binding var isAddingAccount: Bool
    @FocusState private var focusedField: SettingsFocusField?

    var body: some View {
        Form {
            Section {
                Text("Account order here matches the menu bar dashboard.")
                    .foregroundStyle(.secondary)
            }

            if isAddingAccount {
                InlineAddAccountForm(
                    appModel: appModel,
                    focusedField: $focusedField,
                    onCancel: finishAdding,
                    onCreate: finishAdding
                )
            }

            if appModel.providerAccounts.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "person.crop.square.badge.plus",
                        description: Text("Create an account to start tracking usage.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
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
        .formStyle(.grouped)
        .padding(18)
        .frame(maxWidth: 560, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingAccount.toggle()
                    focusedField = isAddingAccount ? .newAccountName : nil
                } label: {
                    Label(
                        isAddingAccount ? "Cancel Add" : "Add Account",
                        systemImage: isAddingAccount ? "xmark" : "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func finishAdding() {
        isAddingAccount = false
        focusedField = nil
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
        Section("New Account") {
            Picker("Provider", selection: $providerID) {
                ForEach(appModel.providerIDs, id: \.self) { providerID in
                    Text(appModel.providerDisplayName(for: providerID)).tag(providerID)
                }
            }
            .frame(maxWidth: 320, alignment: .leading)

            TextField("Account Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: .newAccountName)

            Toggle("Enabled", isOn: $isEnabled)

            if providerID == "claude-code" {
                Picker("Source", selection: $sourceMode) {
                    Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                    Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
                }
                .pickerStyle(.segmented)

                TextField("Local snapshot JSON path", text: $localSnapshotPath)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .newLocalSnapshotPath)
                    .disabled(sourceMode != .localSnapshot)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
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
    }
}

enum SettingsFocusField: Hashable {
    case accountName(String)
    case localSnapshotPath(String)
    case newAccountName
    case newLocalSnapshotPath
}
