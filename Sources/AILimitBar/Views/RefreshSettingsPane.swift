import AILimitBarCore
import SwiftUI

struct RefreshSettingsPane: View {
    @ObservedObject var appModel: AppModel
    @AppStorage(DashboardHeightPreset.storageKey)
    private var dashboardHeightPresetRawValue = DashboardHeightPreset.standard.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Refresh")
                    .font(.title2.weight(.semibold))
                Text("Choose how often AI Limitbar refreshes enabled accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Schedule") {
                    Picker("Interval", selection: refreshIntervalBinding) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Manual refresh stays available from the menu bar panel.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Dashboard") {
                    Picker("Height", selection: dashboardHeightPresetBinding) {
                        ForEach(DashboardHeightPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Controls the maximum visible height of the menu-bar dashboard. Longer account lists scroll.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: 760, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var refreshIntervalBinding: Binding<RefreshInterval> {
        Binding(
            get: { appModel.refreshSettings.interval },
            set: { appModel.setRefreshInterval($0) }
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
