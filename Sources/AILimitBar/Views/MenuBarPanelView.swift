import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var appModel: AppModel
    private let contentInset: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            footerControls
        }
        .padding(contentInset)
        .frame(width: 390)
        .onAppear {
            AppTelemetry.lifecycle.info("Menu bar panel appeared")
            if appModel.enabledSnapshots.isEmpty {
                appModel.refresh()
            }
        }
    }

    private var footerControls: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.glass)

            Spacer()

            Button {
                appModel.refresh()
            } label: {
                Label(appModel.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(appModel.isRefreshing || appModel.hasActiveProviderRefresh || !appModel.hasEnabledAccounts)
            .buttonStyle(.glass)

            Button(role: .destructive) {
                ApplicationLifecycle.terminate()
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.glass)
        }
    }

    private var dashboard: some View {
        dashboardRows
    }

    @ViewBuilder
    private var dashboardRows: some View {
        let rows = appModel.enabledAccountRows
        ScrollView {
            GlassEffectContainer {
                accountRows(rows)
            }
            .padding(.vertical, 1)
            .padding(.trailing, contentInset)
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(.trailing, -contentInset)
        .frame(height: dashboardHeight(for: rows))
    }

    private func accountRows(_ rows: [AccountSnapshotRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                DashboardAccountRowView(
                    appModel: appModel,
                    row: row,
                    isStale: row.snapshot.map { appModel.isSnapshotStale($0) } ?? false
                )
                .padding(10)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func dashboardHeight(for rows: [AccountSnapshotRow]) -> CGFloat {
        let estimatedHeight = rows.reduce(CGFloat.zero) { height, row in
            let limitWindowCount = max(row.snapshot?.displayLimitWindows.count ?? 0, 1)
            return height + 54 + CGFloat(limitWindowCount * 38)
        }
        let dividerHeight = CGFloat(max(rows.count - 1, 0))
        return min(max(estimatedHeight + dividerHeight, 92), 380)
    }

}
