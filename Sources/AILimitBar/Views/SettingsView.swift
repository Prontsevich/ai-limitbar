import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selection: SettingsSection = .accounts
    @State private var editorSession = AccountEditorSession()
    @State private var pendingNavigation: SettingsNavigationDestination?
    @State private var isShowingDiscardConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if let warning = appModel.storageWarning {
                Label(warning, systemImage: "externaldrive.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)

                Divider()
            }

            sectionNavigation
            Divider()
            sectionContent
        }
        .frame(minWidth: 760, idealWidth: 840, minHeight: 500, idealHeight: 560)
        .alert("Discard Changes?", isPresented: $isShowingDiscardConfirmation) {
            Button("Discard Changes", role: .destructive) {
                guard let pendingNavigation else { return }
                applyNavigation(pendingNavigation)
                self.pendingNavigation = nil
            }
            Button("Keep Editing", role: .cancel) {
                pendingNavigation = nil
            }
        } message: {
            Text("Your account changes have not been saved.")
        }
        .onAppear {
            AppTelemetry.lifecycle.info("Settings appeared")
        }
        .onDisappear {
            selection = .accounts
            editorSession.reset()
            pendingNavigation = nil
            isShowingDiscardConfirmation = false
        }
    }

    private var sectionNavigation: some View {
        Picker("Settings Section", selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Text(section.title)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 520)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .onChange(of: selection) { oldSelection, newSelection in
            guard oldSelection != newSelection else { return }
            guard editorSession.isDirty else {
                editorSession.discardEditor()
                return
            }

            selection = oldSelection
            pendingNavigation = .section(newSelection)
            isShowingDiscardConfirmation = true
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selection {
        case .accounts:
            AccountsSettingsPane(
                appModel: appModel,
                editorSession: $editorSession,
                onRequestAccountSelection: requestAccountSelection
            )
        case .refresh:
            RefreshSettingsPane(appModel: appModel)
        case .providerSetup:
            ProviderSetupSettingsPane(appModel: appModel)
        }
    }

    private func requestAccountSelection(_ accountID: String?) {
        guard accountID != editorSession.selectedAccountID else { return }
        requestNavigation(.account(accountID))
    }

    private func requestNavigation(_ destination: SettingsNavigationDestination) {
        guard editorSession.isDirty else {
            applyNavigation(destination)
            return
        }

        pendingNavigation = destination
        isShowingDiscardConfirmation = true
    }

    private func applyNavigation(_ destination: SettingsNavigationDestination) {
        editorSession.discardEditor()

        switch destination {
        case let .section(section):
            selection = section
        case let .account(accountID):
            editorSession.selectedAccountID = accountID
        }
    }
}

private enum SettingsNavigationDestination: Equatable {
    case section(SettingsSection)
    case account(String?)
}

struct AccountEditorSession: Equatable {
    var selectedAccountID: String?
    var mode: AccountEditorMode?
    var isDirty: Bool

    init(
        selectedAccountID: String? = nil,
        mode: AccountEditorMode? = nil,
        isDirty: Bool = false
    ) {
        self.selectedAccountID = selectedAccountID
        self.mode = mode
        self.isDirty = isDirty
    }

    mutating func discardEditor() {
        mode = nil
        isDirty = false
    }

    mutating func reset() {
        selectedAccountID = nil
        mode = nil
        isDirty = false
    }
}

enum AccountEditorMode: Equatable {
    case creating
    case editing
}

private enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
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
}
