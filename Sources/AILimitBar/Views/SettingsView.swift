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

            Section("Credentials") {
                Text("Credential entry is disabled until real provider requirements are verified.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520, height: 360)
    }

    private func binding(for providerID: String) -> Binding<Bool> {
        Binding(
            get: {
                appModel.providerConfigurations.first(where: { $0.providerID == providerID })?.isEnabled ?? false
            },
            set: { appModel.setProvider(providerID, enabled: $0) }
        )
    }
}

private struct ProviderSettingsRow: View {
    @ObservedObject var appModel: AppModel
    let providerID: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            Toggle(providerName, isOn: $isEnabled)

            Spacer()

            Button {
                appModel.testConnection(providerID: providerID)
            } label: {
                Label("Test", systemImage: "checkmark.circle")
            }
            .disabled(!isEnabled)

            Button {
                appModel.openUsagePage(providerID: providerID)
            } label: {
                Label("Open Usage", systemImage: "arrow.up.forward.square")
            }
            .disabled(appModel.adapter(for: providerID)?.usageURL == nil)
        }
    }

    private var providerName: String {
        appModel.adapter(for: providerID)?.displayName ?? providerID
    }
}
