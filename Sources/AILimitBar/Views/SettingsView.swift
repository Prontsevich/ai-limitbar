import AILimitBarCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(appModel.providerConfigurations) { configuration in
                    ProviderSettingsRow(
                        appModel: appModel,
                        providerID: configuration.providerID,
                        isEnabled: binding(for: configuration.providerID)
                    )
                }
            }

            Section("Refresh") {
                Picker("Interval", selection: refreshIntervalBinding) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Credentials") {
                Text("Credential entry is disabled until real provider requirements are verified.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 620, height: 460)
    }

    private func binding(for providerID: String) -> Binding<Bool> {
        Binding(
            get: {
                appModel.providerConfigurations.first(where: { $0.providerID == providerID })?.isEnabled ?? false
            },
            set: { appModel.setProvider(providerID, enabled: $0) }
        )
    }

    private var refreshIntervalBinding: Binding<RefreshInterval> {
        Binding(
            get: { appModel.refreshSettings.interval },
            set: { appModel.setRefreshInterval($0) }
        )
    }
}

private struct ProviderSettingsRow: View {
    @ObservedObject var appModel: AppModel
    let providerID: String
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(providerName, isOn: $isEnabled)

                Spacer()

                Button {
                    appModel.testConnection(providerID: providerID)
                } label: {
                    Label("Test", systemImage: "checkmark.circle")
                }
                .disabled(!isEnabled || appModel.isRefreshing || appModel.refreshStatus(for: providerID) == .refreshing)

                Button {
                    appModel.openUsagePage(providerID: providerID)
                } label: {
                    Label("Open Usage", systemImage: "arrow.up.forward.square")
                }
                .disabled(appModel.adapter(for: providerID)?.usageURL == nil)
            }

            if providerID == "claude-code" {
                claudeCodeConfiguration
            }
        }
    }

    private var claudeCodeConfiguration: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Source", selection: sourceModeBinding) {
                Text(ProviderSourceMode.manual.displayName).tag(ProviderSourceMode.manual)
                Text(ProviderSourceMode.localSnapshot.displayName).tag(ProviderSourceMode.localSnapshot)
            }
            .pickerStyle(.segmented)
            .disabled(!isEnabled)

            TextField("Local snapshot JSON path", text: localSnapshotPathBinding)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEnabled || currentConfiguration.sourceMode != .localSnapshot)
        }
    }

    private var providerName: String {
        appModel.adapter(for: providerID)?.displayName ?? providerID
    }

    private var currentConfiguration: ProviderConfiguration {
        appModel.providerConfigurations.first(where: { $0.providerID == providerID })
            ?? ProviderConfiguration(providerID: providerID, isEnabled: false)
    }

    private var sourceModeBinding: Binding<ProviderSourceMode> {
        Binding(
            get: { currentConfiguration.sourceMode },
            set: { appModel.setProviderSourceMode(providerID, sourceMode: $0) }
        )
    }

    private var localSnapshotPathBinding: Binding<String> {
        Binding(
            get: { currentConfiguration.localSnapshotPath ?? "" },
            set: { appModel.setProviderLocalSnapshotPath(providerID, path: $0) }
        )
    }
}
