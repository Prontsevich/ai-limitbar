import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var appModel: AppModel

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
            } else if appModel.enabledSnapshots.isEmpty {
                ContentUnavailableView(
                    "No Usage Data",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Refresh to load current usage.")
                )
                .frame(width: 320, height: 140)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appModel.enabledSnapshotGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(group.snapshots) { snapshot in
                                ProviderRowView(
                                    snapshot: snapshot,
                                    refreshStatus: appModel.refreshStatus(for: snapshot),
                                    isStale: appModel.isSnapshotStale(snapshot)
                                )
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                SettingsLink {
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
        .frame(width: 360)
        .onAppear {
            if appModel.enabledSnapshots.isEmpty {
                appModel.refresh()
            }
        }
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
}
