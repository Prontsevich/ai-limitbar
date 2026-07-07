import AILimitBarCore
import SwiftUI

struct ProviderRowView: View {
    let row: AccountSnapshotRow
    let isSelected: Bool
    let isStale: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: statusImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.account.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(row.providerDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryValue)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)

                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(isStale ? .orange : .secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(selectionBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var snapshot: UsageSnapshot? {
        row.snapshot
    }

    private var primaryValue: String {
        guard let snapshot else { return "--" }
        guard let usedPercent = snapshot.usedPercent else {
            return snapshot.status.displayName
        }
        return "\(Int(usedPercent.rounded()))%"
    }

    private var statusText: String {
        if row.refreshStatus == .refreshing {
            return row.refreshStatus.displayName
        }
        if row.refreshIssue != nil {
            return "Failed"
        }
        if snapshot == nil {
            return "No data"
        }
        if isStale {
            return "Stale"
        }
        return snapshot?.remainingLabel ?? snapshot?.status.displayName ?? "No data"
    }

    private var selectionBackground: Color {
        isSelected ? Color.accentColor.opacity(0.14) : Color.clear
    }

    private var statusImage: String {
        if row.refreshStatus == .refreshing {
            return "arrow.clockwise.circle"
        }
        if row.refreshIssue != nil {
            return "exclamationmark.arrow.triangle.2.circlepath"
        }
        guard let status = snapshot?.status else {
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
        guard let status = snapshot?.status else {
            return .secondary
        }
        switch status {
        case .ok: return .primary
        case .warning: return .orange
        case .error: return .red
        case .unavailable: return .secondary
        }
    }
}
