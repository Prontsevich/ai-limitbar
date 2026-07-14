import SwiftUI

struct ProviderSetupSettingsPane: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PROVIDER SETUP")
                    .font(TerminalTheme.titleFont)
                    .foregroundStyle(TerminalTheme.primary)
                Text("Provider access stays conservative until stable machine-readable sources are verified.")
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }

            TerminalFieldset(title: "PROVIDERS") {
                EmptyView()
            } content: {
                VStack(spacing: 0) {
                    ForEach(appModel.providerIDs, id: \.self) { providerID in
                        ProviderSetupRow(appModel: appModel, providerID: providerID)

                        if providerID != appModel.providerIDs.last {
                            TerminalRule()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
                    .font(TerminalTheme.emphasizedBodyFont)
                    .foregroundStyle(TerminalTheme.primary)
                Text(sourceSummary)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }
            Spacer()
            Button {
                if let usageURL { openURL(usageURL) }
            } label: {
                Label("Open Usage", systemImage: "arrow.up.forward.square")
            }
            .buttonStyle(TerminalActionButtonStyle())
            .disabled(usageURL == nil)
        }
    }

    private var usageURL: URL? {
        appModel.usageURL(providerID: providerID)
    }

    private var sourceSummary: String {
        switch providerID {
        case "mock": "Built-in local fixture"
        case "claude-code": "Manual · managed statusLine · experimental /usage CLI"
        case "openai-codex": "Experimental app-server"
        case "ollama-cloud": "Experimental web page"
        default: "No configured source"
        }
    }
}
