import AILimitBarCore
import SwiftUI

struct ProviderAccountSettingsCard: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount
    let focusedField: FocusState<SettingsFocusField?>.Binding
    @State private var draftDisplayName = ""
    @State private var isSourceExpanded = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Section {
            HStack(alignment: .center, spacing: 12) {
                accountIdentity
                Spacer()
                Toggle("Enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
            }

            if currentAccount.providerID == "claude-code" {
                DisclosureGroup(isExpanded: $isSourceExpanded) {
                    sourceConfiguration
                } label: {
                    Label("Source Settings", systemImage: "slider.horizontal.3")
                }
            } else {
                LabeledContent("Source", value: currentAccount.sourceMode.displayName)
            }

            HStack(spacing: 8) {
                orderingControls
                Spacer()
                actions
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField.wrappedValue = nil }
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

    private var accountIdentity: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "person.crop.square")
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)

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
            .frame(maxWidth: 330, alignment: .leading)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            if isRenaming {
                TextField("Account name", text: $draftDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.weight(.semibold))
                    .frame(width: 270)
                    .focused(focusedField, equals: .accountName(currentAccount.id))
                    .onSubmit(commitRename)

                Button(action: commitRename) {
                    Image(systemName: "checkmark").frame(width: 14)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Save account name")
                .accessibilityLabel("Save account name")

                Button(action: cancelRename) {
                    Image(systemName: "xmark").frame(width: 14)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Cancel rename")
                .accessibilityLabel("Cancel rename")
                .keyboardShortcut(.cancelAction)
            } else {
                Text(currentAccount.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Button(action: beginRename) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .help("Rename account")
                .accessibilityLabel("Rename \(currentAccount.displayName)")
            }
        }
        .frame(height: 28, alignment: .center)
    }

    private var sourceConfiguration: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Source", selection: sourceModeBinding) {
                Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
            }
            .pickerStyle(.segmented)
            .disabled(!currentAccount.isEnabled)
            .frame(maxWidth: 280, alignment: .leading)

            TextField("Local snapshot JSON path", text: localSnapshotPathBinding)
                .textFieldStyle(.roundedBorder)
                .focused(focusedField, equals: .localSnapshotPath(currentAccount.id))
                .disabled(!currentAccount.isEnabled || currentAccount.sourceMode != .localSnapshot)
        }
        .padding(.top, 2)
    }

    private var orderingControls: some View {
        HStack(spacing: 8) {
            Button {
                appModel.moveAccountUp(providerID: currentAccount.providerID, accountID: currentAccount.accountID)
            } label: {
                Image(systemName: "chevron.up").frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Move account up")
            .accessibilityLabel("Move \(currentAccount.displayName) up")
            .disabled(!appModel.canMoveAccountUp(
                providerID: currentAccount.providerID,
                accountID: currentAccount.accountID
            ))

            Button {
                appModel.moveAccountDown(providerID: currentAccount.providerID, accountID: currentAccount.accountID)
            } label: {
                Image(systemName: "chevron.down").frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Move account down")
            .accessibilityLabel("Move \(currentAccount.displayName) down")
            .disabled(!appModel.canMoveAccountDown(
                providerID: currentAccount.providerID,
                accountID: currentAccount.accountID
            ))
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
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
                if let usageURL { openURL(usageURL) }
            } label: {
                Label("Open Usage", systemImage: "arrow.up.forward.square")
            }
            .disabled(usageURL == nil)

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash").frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Delete account")
            .accessibilityLabel("Delete \(currentAccount.displayName)")
            .disabled(!appModel.canDeleteAccount(
                providerID: currentAccount.providerID,
                accountID: currentAccount.accountID
            ))
        }
        .controlSize(.regular)
        .buttonBorderShape(.roundedRectangle)
    }

    private var isRenaming: Bool {
        focusedField.wrappedValue == .accountName(currentAccount.id)
    }

    private var currentAccount: ProviderAccount {
        appModel.account(providerID: account.providerID, accountID: account.accountID) ?? account
    }

    private var isActionDisabled: Bool {
        !currentAccount.isEnabled ||
            appModel.isRefreshing ||
            appModel.refreshStatus(for: currentAccount) == .refreshing
    }

    private var usageURL: URL? {
        appModel.usageURL(providerID: currentAccount.providerID, accountID: currentAccount.accountID)
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

    private func beginRename() {
        draftDisplayName = currentAccount.displayName
        focusedField.wrappedValue = .accountName(currentAccount.id)
    }

    private func commitRename() {
        appModel.setAccountDisplayName(
            currentAccount.providerID,
            accountID: currentAccount.accountID,
            displayName: draftDisplayName
        )
        focusedField.wrappedValue = nil
    }

    private func cancelRename() {
        draftDisplayName = currentAccount.displayName
        focusedField.wrappedValue = nil
    }
}
