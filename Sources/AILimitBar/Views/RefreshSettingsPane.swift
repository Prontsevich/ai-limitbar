import AILimitBarCore
import SwiftUI

struct RefreshSettingsPane: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appLanguagePreference: AppLanguagePreference
    @Environment(\.locale) private var locale
    @AppStorage(DashboardHeightPreset.storageKey)
    private var dashboardHeightPresetRawValue = DashboardHeightPreset.standard.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TerminalFieldset(
                title: AppStrings.Settings.Language.title.localized(locale: locale)
            ) {
                EmptyView()
            } content: {
                HStack(alignment: .center, spacing: 14) {
                    Text(AppStrings.Settings.Language.selection.resource(locale: locale))
                        .font(TerminalTheme.bodyFont)
                        .foregroundStyle(TerminalTheme.secondary)
                        .frame(width: 120, alignment: .leading)

                    TerminalSegmentedControl(
                        AppStrings.Settings.Language.selection.localized(locale: locale),
                        selection: appLanguageBinding,
                        options: AppLanguage.allCases.map {
                            TerminalSegmentedOption(
                                value: $0,
                                title: AppStrings.Settings.Language.option(for: $0)
                                    .localized(locale: locale)
                            )
                        }
                    )
                }

                Text(AppStrings.Settings.Language.description.resource(locale: locale))
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("REFRESH")
                    .font(TerminalTheme.titleFont)
                    .foregroundStyle(TerminalTheme.primary)
                Text("Choose how often AI Limitbar refreshes enabled accounts.")
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }

            TerminalFieldset(title: "SCHEDULE") {
                EmptyView()
            } content: {
                HStack(alignment: .center, spacing: 14) {
                    Text("Interval")
                        .font(TerminalTheme.bodyFont)
                        .foregroundStyle(TerminalTheme.secondary)
                        .frame(width: 80, alignment: .leading)

                    TerminalSegmentedControl(
                        "Refresh interval",
                        selection: refreshIntervalBinding,
                        options: RefreshInterval.allCases.map {
                            TerminalSegmentedOption(value: $0, title: $0.displayName)
                        }
                    )
                }

                Text("Manual refresh stays available from the menu bar panel.")
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }

            TerminalFieldset(title: "DASHBOARD") {
                EmptyView()
            } content: {
                HStack(alignment: .center, spacing: 14) {
                    Text("Height")
                        .font(TerminalTheme.bodyFont)
                        .foregroundStyle(TerminalTheme.secondary)
                        .frame(width: 80, alignment: .leading)

                    TerminalSegmentedControl(
                        "Dashboard height",
                        selection: dashboardHeightPresetBinding,
                        options: DashboardHeightPreset.allCases.map {
                            TerminalSegmentedOption(value: $0, title: $0.displayName)
                        }
                    )
                }

                Text("Controls the maximum visible height of the menu-bar dashboard. Longer account lists scroll.")
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var refreshIntervalBinding: Binding<RefreshInterval> {
        Binding(
            get: { appModel.refreshSettings.interval },
            set: { appModel.setRefreshInterval($0) }
        )
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { appLanguagePreference.language },
            set: { appLanguagePreference.select($0) }
        )
    }

    private var dashboardHeightPresetBinding: Binding<DashboardHeightPreset> {
        Binding(
            get: {
                DashboardHeightPreset(rawValue: dashboardHeightPresetRawValue) ?? .standard
            },
            set: { dashboardHeightPresetRawValue = $0.rawValue }
        )
    }
}
