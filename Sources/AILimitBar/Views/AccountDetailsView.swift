import AILimitBarCore
import SwiftUI

struct AccountDetailsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var appModel: AppModel
    let row: AccountSnapshotRow

    @State private var isShowingOllamaConnection = false
    @State private var connectionError: String?

    private var dashboardPresentation: DashboardAccountPresentation {
        DashboardAccountPresentation(
            row: row,
            isStale: row.snapshot.map { appModel.isSnapshotStale($0) } ?? false,
            isGlobalRefresh: appModel.isRefreshing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                inspector
                    .padding(12)
            }
            .scrollBounceBehavior(.basedOnSize)

            TerminalRule()

            actionBar
                .padding(12)
        }
        .frame(maxHeight: 520)
        .background(TerminalTheme.surface)
        .sheet(isPresented: $isShowingOllamaConnection) {
            if let client = appModel.ollamaWebPageClient {
                OllamaWebPageConnectionSheet(
                    appModel: appModel,
                    account: currentAccount,
                    client: client
                )
            }
        }
        .alert("Ollama Connection", isPresented: connectionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectionError ?? "Ollama connection is unavailable.")
        }
    }

    private var inspector: some View {
        TerminalFieldset(title: "\(row.account.displayName) details") {
            EmptyView()
        } content: {
            inspectorRows
        }
    }

    @ViewBuilder
    private var inspectorRows: some View {
        TerminalInspectorRow(
            label: "REFRESH",
            value: refreshText,
            valueColor: currentStateColor
        )
        TerminalRule()

        TerminalInspectorRow(
            label: "UPDATED",
            value: row.snapshot.map { preciseDate($0.lastUpdatedAt) } ?? "No usage data"
        )
        TerminalRule()

        if let snapshot = row.snapshot {
            TerminalInspectorRow(label: "SOURCE", value: snapshot.source)
            TerminalRule()
            TerminalInspectorRow(label: "CONFIDENCE", value: snapshot.confidence.displayName)

            if let planName = snapshot.planName {
                TerminalRule()
                TerminalInspectorRow(label: "PLAN", value: planName)
            }

            if snapshot.displayLimitWindows.isEmpty {
                TerminalRule()
                TerminalInspectorRow(
                    label: "USAGE",
                    value: snapshot.remainingLabel ?? snapshot.status.displayName,
                    valueColor: currentStateColor
                )
            }

            ForEach(snapshot.displayLimitWindows) { window in
                if let resetAt = window.resetAt {
                    TerminalRule()
                    TerminalInspectorRow(
                        label: "\(window.displayName.uppercased()) RESET",
                        value: preciseDate(resetAt)
                    )
                }
            }
        } else {
            TerminalInspectorRow(label: "SOURCE", value: currentAccount.sourceMode.displayName)
            TerminalRule()
            TerminalInspectorRow(label: "USAGE", value: emptyStateMessage, valueColor: TerminalTheme.secondary)
        }

        if hasDiagnostics {
            TerminalRule()
            TerminalNoteBox(title: "Diagnostics") {
                diagnosticsContent
            }
        }
    }

    @ViewBuilder
    private var diagnosticsContent: some View {
        if let issue = row.refreshIssue {
            diagnosticItem(
                title: "Last refresh failed",
                messages: issue.warnings.isEmpty ? ["No additional error details were provided."] : issue.warnings,
                date: issue.occurredAt,
                color: TerminalTheme.error
            )
        }

        if let snapshot = row.snapshot, appModel.isSnapshotStale(snapshot) {
            if row.refreshIssue != nil {
                TerminalRule()
            }
            diagnosticItem(
                title: "Stale data",
                messages: ["Snapshot is older than the configured freshness window."],
                date: nil,
                color: TerminalTheme.warning
            )
        }

        if let snapshot = row.snapshot, !diagnosticWarnings.isEmpty {
            if row.refreshIssue != nil || appModel.isSnapshotStale(snapshot) {
                TerminalRule()
            }
            diagnosticItem(
                title: "Warnings",
                messages: diagnosticWarnings,
                date: nil,
                color: snapshot.status == .error ? TerminalTheme.error : TerminalTheme.warning
            )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            if currentAccount.sourceMode == .ollamaWebPage {
                Button(ollamaConnectionTitle, action: beginOllamaConnection)
                    .disabled(appModel.ollamaWebPageClient == nil || actionsDisabled)
            }

            Button("Test Connection") {
                appModel.testConnection(providerID: row.account.providerID, accountID: row.account.accountID)
            }
            .disabled(actionsDisabled)

            Button("Open Usage") {
                if let url = usageURL {
                    openURL(url)
                }
            }
            .disabled(usageURL == nil)
        }
        .buttonStyle(TerminalTextButtonStyle())
    }

    private var usageURL: URL? {
        appModel.usageURL(providerID: row.account.providerID, accountID: row.account.accountID)
    }

    private var currentAccount: ProviderAccount {
        appModel.account(providerID: row.account.providerID, accountID: row.account.accountID) ?? row.account
    }

    private var ollamaConnectionTitle: String {
        currentAccount.webDataStoreID == nil ? "Connect" : "Reconnect"
    }

    private var emptyStateMessage: String {
        switch currentAccount.sourceMode {
        case .ollamaWebPage:
            "Connect Ollama to load the experimental settings-page source."
        case .appServer:
            "Refresh this account to read the experimental local Codex app-server source."
        case .manual, .claudeStatusLine:
            "Refresh or test this account to load a snapshot."
        }
    }

    private var hasDiagnostics: Bool {
        row.refreshIssue != nil ||
            row.snapshot.map { appModel.isSnapshotStale($0) } == true ||
            !diagnosticWarnings.isEmpty
    }

    private var diagnosticWarnings: [String] {
        guard let snapshot = row.snapshot else { return [] }
        if row.account.sourceMode.isExperimental && snapshot.status == .ok {
            return []
        }
        return snapshot.warnings
    }

    private var actionsDisabled: Bool {
        appModel.isRefreshing || row.refreshStatus == .refreshing || !row.account.isEnabled
    }

    private var currentStateColor: Color {
        switch dashboardPresentation.state {
        case .failed:
            TerminalTheme.error
        case .stale, .warning:
            TerminalTheme.warning
        case .normal:
            TerminalTheme.healthy
        case .refreshing, .manual, .unavailable, .noData:
            TerminalTheme.primary
        }
    }

    private var refreshText: String {
        switch row.refreshStatus {
        case .idle:
            currentStateText
        case .refreshing:
            "Refreshing"
        case let .succeeded(date):
            "Succeeded at \(preciseDate(date))"
        case let .failed(date):
            "Failed at \(preciseDate(date))"
        }
    }

    private var currentStateText: String {
        switch dashboardPresentation.state {
        case .normal:
            row.snapshot?.status.displayName ?? "No Data"
        case .refreshing:
            "Refreshing"
        case .stale:
            "Stale"
        case .failed:
            "Failed"
        case .warning:
            "Warning"
        case .manual:
            "Manual"
        case .unavailable:
            "Unavailable"
        case .noData:
            "No Data"
        }
    }

    private func beginOllamaConnection() {
        guard currentAccount.providerID == "ollama-cloud",
              appModel.ollamaWebPageClient != nil,
              appModel.prepareOllamaWebPageConnection(
                  providerID: currentAccount.providerID,
                  accountID: currentAccount.accountID
              ) != nil
        else {
            connectionError = "Save the account before connecting Ollama through AI Limitbar."
            return
        }
        isShowingOllamaConnection = true
    }

    private var connectionErrorBinding: Binding<Bool> {
        Binding(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
        )
    }

    private func diagnosticItem(title: String, messages: [String], date: Date?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(TerminalTheme.detailLabelFont)
                Spacer()
                if let date {
                    Text(preciseDate(date))
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.secondary)
                }
            }

            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(TerminalTheme.captionFont)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(color)
    }

    private func preciseDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct TerminalInspectorRow: View {
    let label: String
    let value: String
    var valueColor: Color = TerminalTheme.primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(TerminalTheme.detailLabelFont)
                .foregroundStyle(TerminalTheme.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(TerminalTheme.detailValueFont)
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
