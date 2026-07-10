import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selection: SettingsSection? = .accounts
    @State private var isAddingAccount = false

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 230)
        } detail: {
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

                content
            }
            .navigationTitle(selectedSection.title)
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 480, idealHeight: 560)
        .onAppear {
            AppTelemetry.lifecycle.info("Settings appeared")
        }
        .onDisappear {
            resetTransientState()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
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

    private var selectedSection: SettingsSection {
        selection ?? .accounts
    }

    private func resetTransientState() {
        isAddingAccount = false
    }
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

    var systemImage: String {
        switch self {
        case .accounts: "person.crop.square.stack"
        case .refresh: "arrow.clockwise"
        case .providerSetup: "key.horizontal"
        }
    }
}
