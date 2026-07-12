import AILimitBarCore
import SwiftUI

struct DashboardAccountRowView: View {
    @ObservedObject var appModel: AppModel
    let row: AccountSnapshotRow
    let isStale: Bool

    @State private var isShowingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header

            if let snapshot = row.snapshot {
                let windows = snapshot.displayLimitWindows
                if windows.isEmpty {
                    unavailableText(snapshot.remainingLabel ?? snapshot.status.displayName)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(windows) { window in
                            LimitWindowProgressRow(window: window)
                        }
                    }
                }
            } else {
                unavailableText("No usage data")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 9)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: statusImage)
                .foregroundStyle(statusColor)
                .frame(width: 16)

            Text(row.account.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)

            Button {
                isShowingDetails.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .imageScale(.medium)
            }
            .buttonStyle(.glass)
            .help("Show account details")
            .accessibilityLabel("Show details for \(row.account.displayName)")
            .popover(isPresented: $isShowingDetails, arrowEdge: .trailing) {
                AccountDetailsView(appModel: appModel, row: row)
                    .frame(width: 340)
            }
        }
    }

    private func unavailableText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(row.snapshot?.status == .error ? .red : .secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        if isStale {
            return "Stale"
        }
        if snapshot.status != .ok && !snapshot.warnings.isEmpty {
            return "Warning"
        }
        return snapshot.status.displayName
    }

    private var statusImage: String {
        if row.refreshStatus == .refreshing {
            return "arrow.clockwise.circle"
        }
        if row.refreshIssue != nil {
            return "exclamationmark.arrow.triangle.2.circlepath"
        }
        guard let status = row.snapshot?.status else {
            return "circle.dashed"
        }
        switch status {
        case .ok: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .unavailable: return "questionmark.circle"
        }
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
        if isStale {
            return .orange
        }
        switch snapshot.status {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        case .unavailable: return .secondary
        }
    }
}

private struct LimitWindowProgressRow: View {
    let window: UsageLimitWindow

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(valueText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let usedPercent = window.usedPercent {
                ProgressView(value: usedPercent, total: 100)
                    .controlSize(.small)
                    .accessibilityLabel(window.displayName)
                    .accessibilityValue(valueText)
            }

            if let detailText {
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var valueText: String {
        guard let usedPercent = window.usedPercent else {
            return window.remainingLabel ?? "Unknown"
        }
        return "\(Int(usedPercent.rounded()))%"
    }

    private var detailText: String? {
        if let remainingLabel = window.remainingLabel, let resetText {
            return "\(remainingLabel) - \(resetText)"
        }
        return window.remainingLabel ?? resetText
    }

    private var resetText: String? {
        guard let resetAt = window.resetAt else { return nil }
        return "resets \(Self.relativeDateFormatter.localizedString(for: resetAt, relativeTo: Date()))"
    }
}
