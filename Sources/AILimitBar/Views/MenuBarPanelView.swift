import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let warning = appModel.storageWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !appModel.hasEnabledAccounts {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "slider.horizontal.3",
                    description: Text("Create an account in Settings.")
                )
                .frame(width: 320, height: 140)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    accountList

                    if let selectedRow = appModel.selectedAccountRow {
                        AccountDetailsView(appModel: appModel, row: selectedRow)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Spacer()

                Button {
                    appModel.refresh()
                } label: {
                    Label(appModel.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appModel.isRefreshing || appModel.hasActiveProviderRefresh || !appModel.hasEnabledAccounts)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 380)
        .onAppear {
            if appModel.enabledSnapshots.isEmpty {
                appModel.refresh()
            }
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accounts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appModel.enabledAccountGroups) { group in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(group.displayName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)

                            ForEach(group.rows) { row in
                                ProviderRowView(
                                    row: row,
                                    isSelected: row.id == appModel.effectiveSelectedAccountKey,
                                    isStale: row.snapshot.map { appModel.isSnapshotStale($0) } ?? false
                                ) {
                                    appModel.selectAccount(
                                        providerID: row.account.providerID,
                                        accountID: row.account.accountID
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: accountListHeight)
        }
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Limitbar")
                    .font(.headline)
            }

            Spacer()

            if appModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var accountListHeight: CGFloat {
        let rowCount = max(appModel.enabledAccountRows.count, 1)
        let groupCount = max(appModel.enabledAccountGroups.count, 1)
        let desiredHeight = CGFloat(rowCount * 42 + groupCount * 18)
        return min(max(desiredHeight, 62), 170)
    }
}
