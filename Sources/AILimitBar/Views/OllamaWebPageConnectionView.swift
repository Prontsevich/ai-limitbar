import AILimitBarCore
import SwiftUI
import WebKit

struct OllamaWebPageConnectionSheet: View {
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount
    let client: OllamaWebPageClientController
    let dismiss: () -> Void

    @State private var attempt = 0
    @State private var isConnecting = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.webDataStoreID == nil ? "Connect Ollama" : "Reconnect Ollama")
                    .font(.title2.weight(.semibold))
                Text("Sign in directly with Ollama in this isolated AI Limitbar window. Cookies, tokens, passwords, and raw page content stay inside WebKit and are never exported to AI Limitbar storage.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let webView = client.webView(for: account) {
                OllamaWebView(webView: webView)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }
            } else {
                ContentUnavailableView(
                    "Connection Profile Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Save this account before opening the Ollama connection flow.")
                )
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }

                if statusMessage != nil && !isConnecting {
                    Button("Try Again") {
                        attempt += 1
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 980, idealWidth: 1080, minHeight: 780, idealHeight: 840)
        .task(id: attempt) {
            await connect()
        }
    }

    private func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        statusMessage = "Loading Ollama settings…"
        defer { isConnecting = false }

        do {
            let payload = try await client.connect(account: account)
            appModel.acceptOllamaUsagePayload(payload, for: account)
            dismiss()
        } catch is CancellationError {
            statusMessage = "Connection cancelled."
        } catch {
            statusMessage = connectionMessage(for: error)
        }
    }

    private func connectionMessage(for error: Error) -> String {
        guard let providerError = error as? ProviderAdapterError else {
            return "Ollama connection failed. Reconnect and try again."
        }
        if let recoverySuggestion = providerError.recoverySuggestion {
            return "\(providerError.message) \(recoverySuggestion)"
        }
        return providerError.message
    }
}

struct OllamaWebPageConnectionWindow: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @ObservedObject var appModel: AppModel

    var body: some View {
        Group {
            if let account = appModel.ollamaConnectionAccount,
               let client = appModel.ollamaWebPageClient {
                OllamaWebPageConnectionSheet(
                    appModel: appModel,
                    account: account,
                    client: client,
                    dismiss: { closeConnection(for: account) }
                )
            } else {
                ContentUnavailableView(
                    "Ollama Connection Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Choose Connect Ollama or Reconnect from an Ollama account first.")
                )
                .frame(
                    minWidth: OllamaConnectionWindowConfiguration.preferredSize.width,
                    minHeight: OllamaConnectionWindowConfiguration.preferredSize.height
                )
            }
        }
        .onDisappear {
            if let account = appModel.ollamaConnectionAccount {
                appModel.clearOllamaConnection(for: account)
            }
        }
    }

    private func closeConnection(for account: ProviderAccount) {
        appModel.clearOllamaConnection(for: account)
        dismissWindow(id: OllamaConnectionWindowConfiguration.id)
    }
}

private struct OllamaWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
