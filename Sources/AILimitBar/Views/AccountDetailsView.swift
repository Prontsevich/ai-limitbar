import AILimitBarCore
import SwiftUI

struct AccountDetailsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var appModel: AppModel
    let row: AccountSnapshotRow

    @State private var isShowingOllamaConnection = false
    @State private var connectionError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(12)

            Divider()

            ScrollView {
                detailsContent
                    .padding(12)
            }
            .scrollBounceBehavior(.basedOnSize)

            Divider()

            actionBar
                .padding(12)
        }
        .frame(maxHeight: 520)
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

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let issue = row.refreshIssue {
                warningBlock(
                    title: "Last refresh failed",
                    messages: issue.warnings.isEmpty ? ["No additional error details were provided."] : issue.warnings,
                    date: issue.occurredAt,
                    color: .red
                )
            }

            if let snapshot = row.snapshot {
                snapshotDetails(snapshot)
            } else {
                emptyState
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.account.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(row.providerDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.weight(.medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func snapshotDetails(_ snapshot: UsageSnapshot) -> some View {
        let windows = snapshot.displayLimitWindows
        if !windows.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(windows) { window in
                    detailLimitWindow(window)
                }
            }
        } else {
            Text(snapshot.remainingLabel ?? snapshot.status.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(snapshot.status == .error ? .red : .primary)
        }

        VStack(alignment: .leading, spacing: 6) {
            if let planName = snapshot.planName {
                detailRow("Plan", planName)
            }
            if let periodLabel = snapshot.periodLabel {
                detailRow("Period", periodLabel)
            }

            detailRow("Source", snapshot.source)
            detailRow("Confidence", snapshot.confidence.displayName)
            detailRow("Updated", updatedText(for: snapshot))
            detailRow("Refresh", refreshText)
        }

        if isStale(snapshot) {
            warningBlock(
                title: "Stale data",
                messages: ["Snapshot is older than the configured freshness window."],
                date: nil,
                color: .orange
            )
        }

        if !snapshot.warnings.isEmpty {
            warningBlock(
                title: "Warnings",
                messages: snapshot.warnings,
                date: nil,
                color: snapshot.status == .error ? .red : .secondary
            )
        }
    }

    private func detailLimitWindow(_ window: UsageLimitWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                if let usedPercent = window.usedPercent {
                    Text("\(Int(usedPercent.rounded()))% used")
                        .font(.caption.monospacedDigit().weight(.semibold))
                } else {
                    Text(window.remainingLabel ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let usedPercent = window.usedPercent {
                ProgressView(value: usedPercent, total: 100)
                    .accessibilityLabel(window.displayName)
                    .accessibilityValue("\(Int(usedPercent.rounded())) percent used")
            }

            if let remainingLabel = window.remainingLabel {
                Text(remainingLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let resetAt = window.resetAt {
                Text("Resets \(resetAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No usage data")
                .font(.subheadline.weight(.semibold))
            Text(emptyStateMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            if currentAccount.sourceMode == .ollamaWebPage {
                Button(action: beginOllamaConnection) {
                    Label(ollamaConnectionTitle, systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(appModel.ollamaWebPageClient == nil || actionsDisabled)
            }

            Button {
                appModel.refreshAccount(providerID: row.account.providerID, accountID: row.account.accountID)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(actionsDisabled)

            Button {
                appModel.testConnection(providerID: row.account.providerID, accountID: row.account.accountID)
            } label: {
                Label("Test", systemImage: "checkmark.circle")
            }
            .disabled(actionsDisabled)

            Button {
                if let url = usageURL {
                    openURL(url)
                }
            } label: {
                Label("Usage", systemImage: "arrow.up.forward.square")
            }
            .disabled(usageURL == nil)
        }
        .labelStyle(.titleAndIcon)
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
        case .manual, .localSnapshot:
            "Refresh or test this account to load a snapshot."
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

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func warningBlock(title: String, messages: [String], date: Date?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                if let date {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(color)
        .padding(8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var actionsDisabled: Bool {
        appModel.isRefreshing || row.refreshStatus == .refreshing || !row.account.isEnabled
    }

    private var statusText: String {
        if row.refreshStatus == .refreshing {
            return row.refreshStatus.displayName
        }
        if row.refreshIssue != nil {
            return "Failed"
        }
        guard let snapshot = row.snapshot else {
            return "No Data"
        }
        if isStale(snapshot) {
            return "Stale"
        }
        return snapshot.status.displayName
    }

    private var statusColor: Color {
        if row.refreshStatus == .refreshing {
            return .secondary
        }
        if row.refreshIssue != nil {
            return .red
        }
        guard let snapshot = row.snapshot else {
            return .secondary
        }
        if isStale(snapshot) {
            return .orange
        }
        switch snapshot.status {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        case .unavailable: return .secondary
        }
    }

    private var refreshText: String {
        switch row.refreshStatus {
        case .idle:
            return "Idle"
        case .refreshing:
            return "Refreshing"
        case let .succeeded(date):
            return "Succeeded \(relativeText(since: date))"
        case let .failed(date):
            return "Failed \(relativeText(since: date))"
        }
    }

    private func updatedText(for snapshot: UsageSnapshot) -> String {
        if isStale(snapshot) {
            return "Stale, \(relativeText(since: snapshot.lastUpdatedAt))"
        }
        return relativeText(since: snapshot.lastUpdatedAt)
    }

    private func relativeText(since date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 60 {
            return "just now"
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = elapsed < 3_600 ? [.minute] : [.hour, .minute]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .abbreviated

        let formatted = formatter.string(from: elapsed) ?? "recently"
        return "\(formatted) ago"
    }

    private func isStale(_ snapshot: UsageSnapshot) -> Bool {
        appModel.isSnapshotStale(snapshot)
    }
}
