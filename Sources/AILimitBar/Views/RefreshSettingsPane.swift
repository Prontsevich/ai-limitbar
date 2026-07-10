import AILimitBarCore
import SwiftUI

struct RefreshSettingsPane: View {
    @ObservedObject var appModel: AppModel

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
            }
            .formStyle(.grouped)
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: 560, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var refreshIntervalBinding: Binding<RefreshInterval> {
        Binding(
            get: { appModel.refreshSettings.interval },
            set: { appModel.setRefreshInterval($0) }
        )
    }
}
