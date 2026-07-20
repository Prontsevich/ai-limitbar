import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var appModel: AppModel
    let onOpenSettings: () -> Void
    let onOpenAbout: () -> Void
    let onOpenOllamaConnection: () -> Void
    @AppStorage(DashboardHeightPreset.storageKey)
    private var dashboardHeightPresetRawValue = DashboardHeightPreset.standard.rawValue

    private let contentInset: CGFloat = 12
    private let accountPanelSpacing: CGFloat = 14
    private let legendClearance: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let warning = appModel.localizedStorageWarning(locale: locale) {
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
            .accessibilityLabel(AppStrings.MenuBar.refreshAllAccounts.resource(locale: locale))
            .accessibilityValue(
                appModel.isRefreshing
                    ? AppStrings.MenuBar.refreshing.localized(locale: locale)
                    : AppStrings.MenuBar.ready.localized(locale: locale)
            )
        }
    }

    private var emptyAccountsPanel: some View {
        TerminalFieldset(title: AppStrings.MenuBar.accountsTitle.localized(locale: locale)) {
            EmptyView()
        } content: {
            Text(AppStrings.MenuBar.noEnabledAccounts.resource(locale: locale))
                .font(TerminalTheme.emphasizedBodyFont)
                .foregroundStyle(TerminalTheme.primary)
            Text(AppStrings.MenuBar.createAccountInSettings.resource(locale: locale))
                .font(TerminalTheme.captionFont)
                .foregroundStyle(TerminalTheme.secondary)
        }
    }

    private var footerControls: some View {
        HStack(spacing: 8) {
            Button {
                onOpenSettings()
            } label: {
                Text(AppStrings.MenuBar.settings.resource(locale: locale))
            }
            .buttonStyle(TerminalTextButtonStyle())

            Button {
                onOpenAbout()
            } label: {
                Text(AppStrings.MenuBar.about.resource(locale: locale))
            }
            .buttonStyle(TerminalTextButtonStyle())
            .help(AppStrings.MenuBar.aboutAILimitbar.localized(locale: locale))
            .accessibilityLabel(AppStrings.MenuBar.aboutAILimitbar.resource(locale: locale))

            Spacer()

            Button(role: .destructive) {
                ApplicationLifecycle.terminate()
            } label: {
                Text(AppStrings.MenuBar.quit.resource(locale: locale))
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
                    isStale: row.snapshot.map { appModel.isSnapshotStale($0) } ?? false,
                    onOpenOllamaConnection: onOpenOllamaConnection
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
            return AppStrings.MenuBar.noEnabledAccountsToRefresh.localized(locale: locale)
        }
        if appModel.isRefreshing {
            return AppStrings.MenuBar.refreshingAllAccounts.localized(locale: locale)
        }
        if appModel.hasActiveProviderRefresh {
            return AppStrings.MenuBar.waitForCurrentRefresh.localized(locale: locale)
        }
        return AppStrings.MenuBar.refreshAllAccounts.localized(locale: locale)
    }
}
