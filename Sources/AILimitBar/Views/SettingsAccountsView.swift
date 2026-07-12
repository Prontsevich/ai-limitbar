import AILimitBarCore
import SwiftUI

struct AccountsSettingsPane: View {
    @ObservedObject var appModel: AppModel
    @Binding var editorSession: AccountEditorSession
    let onRequestAccountSelection: (String?) -> Void

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                accountList
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)

                detail
                    .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: reconcileSelection)
        .onChange(of: accountIDs) { _, _ in
            reconcileSelection()
        }
        .alert("Delete Account?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: deleteSelectedAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(selectedAccount?.displayName ?? "the selected account") and its stored snapshot from AI Limitbar.")
        }
    }

    private var accountList: some View {
        VStack(spacing: 0) {
            List(selection: accountSelection) {
                ForEach(appModel.providerAccounts) { account in
                    AccountListRow(
                        account: account,
                        providerName: appModel.providerDisplayName(for: account.providerID)
                    )
                    .tag(account.id)
                    .contextMenu {
                        Button("Move Up") {
                            appModel.moveAccountUp(providerID: account.providerID, accountID: account.accountID)
                        }
                        .disabled(editorSession.isDirty || !appModel.canMoveAccountUp(
                            providerID: account.providerID,
                            accountID: account.accountID
                        ))

                        Button("Move Down") {
                            appModel.moveAccountDown(providerID: account.providerID, accountID: account.accountID)
                        }
                        .disabled(editorSession.isDirty || !appModel.canMoveAccountDown(
                            providerID: account.providerID,
                            accountID: account.accountID
                        ))
                    }
                }
                .onMove { offsets, destination in
                    guard !editorSession.isDirty else { return }
                    appModel.moveAccounts(fromOffsets: offsets, toOffset: destination)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            HStack(spacing: 10) {
                Button(action: beginAdding) {
                    SettingsGlassIcon(systemName: "plus")
                }
                .settingsGlassIconButton(help: "Add account")
                .accessibilityLabel("Add account")

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    SettingsGlassIcon(systemName: "minus")
                }
                .settingsGlassIconButton(help: "Delete selected account")
                .accessibilityLabel("Delete selected account")
                .disabled(selectedAccount == nil || editorSession.isDirty)

                Spacer()

                Button {
                    appModel.refresh()
                } label: {
                    SettingsGlassIcon(systemName: "arrow.clockwise")
                }
                .settingsGlassIconButton(help: appModel.isRefreshing ? "Refreshing all accounts" : "Refresh all accounts")
                .accessibilityLabel(appModel.isRefreshing ? "Refreshing all accounts" : "Refresh all accounts")
                .disabled(appModel.isRefreshing || appModel.hasActiveProviderRefresh || !appModel.hasEnabledAccounts)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if editorSession.mode == .creating {
            AccountEditorView(
                appModel: appModel,
                account: nil,
                isDirty: $editorSession.isDirty,
                onCancel: discardEditor,
                onCreate: { accountID in
                    editorSession.selectedAccountID = accountID
                    finishEditor()
                },
                onSave: { finishEditor() }
            )
            .id("new-account")
        } else if let account = selectedAccount {
            if editorSession.mode == .editing {
                AccountEditorView(
                    appModel: appModel,
                    account: account,
                    isDirty: $editorSession.isDirty,
                    onCancel: discardEditor,
                    onCreate: { _ in },
                    onSave: { finishEditor() }
                )
                .id(account.id)
            } else {
                AccountDetailView(
                    appModel: appModel,
                    account: account,
                    onEdit: beginEditing
                )
            }
        } else {
            ContentUnavailableView(
                "No Account Selected",
                systemImage: "person.crop.square",
                description: Text("Select an account or add a new one to configure it.")
            )
        }
    }

    private var accountSelection: Binding<String?> {
        Binding(
            get: { editorSession.selectedAccountID },
            set: { requestedAccountID in
                requestAccountSelection(requestedAccountID)
            }
        )
    }

    private var selectedAccount: ProviderAccount? {
        guard let selectedAccountID = editorSession.selectedAccountID else { return nil }
        return appModel.providerAccounts.first { $0.id == selectedAccountID }
    }

    private var accountIDs: [String] {
        appModel.providerAccounts.map(\.id)
    }

    private func beginAdding() {
        guard !editorSession.isDirty else { return }
        editorSession.selectedAccountID = nil
        editorSession.mode = .creating
        editorSession.isDirty = false
    }

    private func beginEditing() {
        guard selectedAccount != nil else { return }
        editorSession.mode = .editing
        editorSession.isDirty = false
    }

    private func requestAccountSelection(_ accountID: String?) {
        guard accountID != editorSession.selectedAccountID else { return }
        onRequestAccountSelection(accountID)
    }

    private func finishEditor() {
        editorSession.discardEditor()
        reconcileSelection()
    }

    private func discardEditor() {
        editorSession.discardEditor()
        if editorSession.selectedAccountID == nil {
            editorSession.selectedAccountID = appModel.providerAccounts.first?.id
        }
    }

    private func deleteSelectedAccount() {
        guard let account = selectedAccount,
              let index = appModel.providerAccounts.firstIndex(where: { $0.id == account.id })
        else { return }

        let nextSelection = appModel.providerAccounts.dropFirst(index + 1).first?.id
            ?? appModel.providerAccounts.prefix(index).last?.id
        appModel.deleteAccount(providerID: account.providerID, accountID: account.accountID)
        editorSession.selectedAccountID = nextSelection
        reconcileSelection()
    }

    private func reconcileSelection() {
        guard editorSession.mode != .creating else { return }
        guard let selectedAccountID = editorSession.selectedAccountID,
              appModel.providerAccounts.contains(where: { $0.id == selectedAccountID })
        else {
            editorSession.selectedAccountID = appModel.providerAccounts.first?.id
            return
        }
    }
}

private struct AccountListRow: View {
    let account: ProviderAccount
    let providerName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.square")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .lineLimit(1)

                Text(providerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
