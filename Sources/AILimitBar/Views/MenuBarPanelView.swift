import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.openSettings) private var openSystemSettings
    @ObservedObject var appModel: AppModel
    let openCustomSettings: () -> Void

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
                dashboard
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                settingsControls
                actionControls
            }
        }
        .padding(14)
        .frame(width: 420)
        .onAppear {
            if appModel.enabledSnapshots.isEmpty {
                appModel.refresh()
            }
        }
    }

    private var settingsControls: some View {
        HStack {
            Button {
                openCustomSettings()
            } label: {
                Label("Custom Settings", systemImage: "gearshape")
            }

            Button {
                openSystemSettings()
            } label: {
                Label("Standard Settings", systemImage: "gearshape.2")
            }

            Spacer()
        }
    }

    private var actionControls: some View {
        HStack {
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

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accounts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            dashboardRows
        }
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var dashboardRows: some View {
        let rows = appModel.enabledAccountRows
        if rows.count > 5 {
            ScrollView {
                accountRows(rows)
            }
            .frame(height: min(CGFloat(rows.count) * 92, 360))
        } else {
            accountRows(rows)
        }
    }

    private func accountRows(_ rows: [AccountSnapshotRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                DashboardAccountRowView(
                    appModel: appModel,
                    row: row,
                    isStale: row.snapshot.map { appModel.isSnapshotStale($0) } ?? false
                )
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
