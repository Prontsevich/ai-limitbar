import SwiftUI

struct ProviderSetupSettingsPane: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Provider Setup")
                    .font(.title2.weight(.semibold))
                Text("Provider access stays conservative until stable machine-readable sources are verified.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Providers") {
                    ForEach(appModel.providerIDs, id: \.self) { providerID in
                        ProviderSetupRow(appModel: appModel, providerID: providerID)
                    }
                }

                Section("Credentials") {
                    Text("Credential entry is disabled until real provider requirements are verified.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
}

private struct ProviderSetupRow: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var appModel: AppModel
    let providerID: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appModel.providerDisplayName(for: providerID))
                    .font(.headline)
                Text(sourceSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let usageURL { openURL(usageURL) }
            } label: {
                Label("Open Usage", systemImage: "arrow.up.forward.square")
            }
            .disabled(usageURL == nil)
        }
    }

    private var usageURL: URL? {
        appModel.usageURL(providerID: providerID)
    }

    private var sourceSummary: String {
        providerID == "claude-code" ? "Manual or local snapshot · statusLine helper" : "Manual source"
    }
}
