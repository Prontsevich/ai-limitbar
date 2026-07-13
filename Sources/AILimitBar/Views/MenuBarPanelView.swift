import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var appModel: AppModel
    @AppStorage(DashboardHeightPreset.storageKey)
    private var dashboardHeightPresetRawValue = DashboardHeightPreset.standard.rawValue

    private let contentInset: CGFloat = 12
    private let accountPanelSpacing: CGFloat = 14
    private let legendClearance: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let warning = appModel.storageWarning {
                Text(warning)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if appModel.hasEnabledAccounts {
                dashboard
            } else {
                emptyAccountsPanel
            }

            TerminalRule()

            footerControls
        }
        .padding(contentInset)
        .frame(width: 390)
        .background(TerminalTheme.surface)
        .onAppear {
            AppTelemetry.lifecycle.info("Menu bar panel appeared")
            if appModel.enabledSnapshots.isEmpty {
                appModel.refresh()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(">_ AI Limitbar")
                .font(TerminalTheme.titleFont)
                .foregroundStyle(TerminalTheme.primary)

            Spacer()

            Button {
                appModel.refresh()
            } label: {
                Group {
                    if appModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(TerminalTheme.secondary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 14, height: 14)
            }
            .buttonStyle(TerminalIconButtonStyle())
            .disabled(!canRefreshAll)
            .help(refreshAllHelp)
            .accessibilityLabel("Refresh all accounts")
            .accessibilityValue(appModel.isRefreshing ? "Refreshing" : "Ready")
        }
    }

    private var emptyAccountsPanel: some View {
        TerminalFieldset(title: "ACCOUNTS") {
            EmptyView()
        } content: {
            Text("No enabled accounts.")
                .font(TerminalTheme.emphasizedBodyFont)
                .foregroundStyle(TerminalTheme.primary)
            Text("Create an account in Settings.")
                .font(TerminalTheme.captionFont)
                .foregroundStyle(TerminalTheme.secondary)
        }
    }

    private var footerControls: some View {
        HStack {
            Button {
                ApplicationLifecycle.openSettings(using: openWindow)
            } label: {
                Text("Settings")
            }
            .buttonStyle(TerminalTextButtonStyle())

            Spacer()

            Button(role: .destructive) {
                ApplicationLifecycle.terminate()
            } label: {
                Text("Quit")
            }
            .buttonStyle(TerminalTextButtonStyle())
        }
    }

    private var dashboard: some View {
        let rows = appModel.enabledAccountRows
        return ScrollView {
            accountRows(rows)
                .padding(.top, legendClearance)
                .padding(.trailing, contentInset)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.visible)
        .padding(.trailing, -contentInset)
        .frame(height: dashboardHeightPreset.viewportHeight)
    }

    private func accountRows(_ rows: [AccountSnapshotRow]) -> some View {
        VStack(alignment: .leading, spacing: accountPanelSpacing) {
            ForEach(rows) { row in
                DashboardAccountRowView(
                    appModel: appModel,
                    row: row,
                    isStale: row.snapshot.map { appModel.isSnapshotStale($0) } ?? false
                )
            }
        }
    }

    private var dashboardHeightPreset: DashboardHeightPreset {
        DashboardHeightPreset(rawValue: dashboardHeightPresetRawValue)
            ?? .standard
    }

    private var canRefreshAll: Bool {
        appModel.hasEnabledAccounts && !appModel.isRefreshing && !appModel.hasActiveProviderRefresh
    }

    private var refreshAllHelp: String {
        if !appModel.hasEnabledAccounts {
            return "No enabled accounts to refresh."
        }
        if appModel.isRefreshing {
            return "Refreshing all accounts."
        }
        if appModel.hasActiveProviderRefresh {
            return "Wait for the current account refresh to finish."
        }
        return "Refresh all accounts"
    }
}
