import AILimitBarCore
import SwiftUI

struct ProviderRowView: View {
    let snapshot: UsageSnapshot
    let refreshStatus: ProviderRefreshStatus
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(snapshot.displayName, systemImage: statusImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                Spacer()

                Text(primaryValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            ProgressView(value: progressValue, total: 100)
                .opacity(snapshot.usedPercent == nil ? 0.25 : 1)

            HStack(spacing: 8) {
                Text(snapshot.remainingLabel ?? snapshot.status.displayName)
                Spacer()
                if isStale {
                    Label("Stale", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
                refreshStatusView
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(snapshot.confidence.displayName)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())

                Text(snapshot.source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let warning = snapshot.warnings.first {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(isStale ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isStale {
                Text("Snapshot is older than the configured freshness window.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var primaryValue: String {
        guard let usedPercent = snapshot.usedPercent else {
            return snapshot.status.displayName
        }
        return "\(Int(usedPercent.rounded()))%"
    }

    private var progressValue: Double {
        snapshot.usedPercent ?? 0
    }

    @ViewBuilder
    private var refreshStatusView: some View {
        switch refreshStatus {
        case .refreshing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text(refreshStatus.displayName)
            }
        case .succeeded:
            Label {
                Text(snapshot.lastUpdatedAt, style: .relative)
            } icon: {
                Image(systemName: "arrow.clockwise.circle")
            }
        case .failed:
            Label(refreshStatus.displayName, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        case .idle:
            Text(snapshot.lastUpdatedAt, style: .relative)
        }
    }

    private var statusImage: String {
        switch snapshot.status {
        case .ok: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        case .unavailable: "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .ok: .primary
        case .warning: .orange
        case .error: .red
        case .unavailable: .secondary
        }
    }
}
