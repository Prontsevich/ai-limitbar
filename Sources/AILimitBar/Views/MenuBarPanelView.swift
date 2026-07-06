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

            if !appModel.hasEnabledProviders {
                ContentUnavailableView(
                    "No Providers Enabled",
                    systemImage: "slider.horizontal.3",
                    description: Text("Enable providers in Settings.")
                )
                .frame(width: 320, height: 140)
            } else if appModel.enabledSnapshots.isEmpty {
                ContentUnavailableView(
                    "No Snapshots Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Refresh to load the current provider state.")
                )
                .frame(width: 320, height: 140)
            } else {
                VStack(spacing: 8) {
                    ForEach(appModel.enabledSnapshots) { snapshot in
                        ProviderRowView(snapshot: snapshot)
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
                .disabled(appModel.isRefreshing || !appModel.hasEnabledProviders)

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
                Text("Provider usage snapshots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}
