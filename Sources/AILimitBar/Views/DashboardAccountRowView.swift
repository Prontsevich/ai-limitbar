import SwiftUI

struct DashboardAccountRowView: View {
    @ObservedObject var appModel: AppModel
    let row: AccountSnapshotRow
    let isStale: Bool

    @State private var isShowingDetails = false

    private var presentation: DashboardAccountPresentation {
        DashboardAccountPresentation(
            row: row,
            isStale: isStale,
            isGlobalRefresh: appModel.isRefreshing
        )
    }

    var body: some View {
        TerminalFieldset(
            title: presentation.accountName,
            titleAccessibilityLabel: presentation.accountName
        ) {
            accountControls
        } content: {
            accountContent
        }
    }

    @ViewBuilder
    private var accountControls: some View {
        HStack(spacing: 7) {
            Button {
                appModel.refreshAccount(
                    providerID: row.account.providerID,
                    accountID: row.account.accountID
                )
            } label: {
                refreshIndicator
            }
            .buttonStyle(TerminalIconButtonStyle())
            .disabled(!presentation.canRefresh)
            .help(presentation.refreshHelp)
            .accessibilityLabel("Refresh \(presentation.accountName)")
            .accessibilityValue(presentation.isRefreshing ? "Refreshing" : "Ready")

            Button {
                isShowingDetails.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(TerminalIconButtonStyle())
            .help("Show account details")
            .accessibilityLabel("Show details for \(presentation.accountName)")
            .popover(isPresented: $isShowingDetails, arrowEdge: .trailing) {
                AccountDetailsView(appModel: appModel, row: row)
                    .frame(width: 360)
            }
        }
    }

    @ViewBuilder
    private var accountContent: some View {
        if !presentation.windows.isEmpty {
            ForEach(presentation.windows) { window in
                LimitWindowProgressRow(window: window, tint: progressTint)

                if window.id != presentation.windows.last?.id ?? "" {
                    TerminalRule()
                        .padding(.vertical, 1)
                }
            }
        }

        if let bodyMessage = presentation.bodyMessage {
            Text(bodyMessage)
                .font(TerminalTheme.bodyFont)
                .foregroundStyle(messageColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let statusText = presentation.statusText {
            Label(statusText, systemImage: statusSymbol)
                .font(TerminalTheme.captionFont)
                .foregroundStyle(statusColor)
                .accessibilityLabel(statusText)
        }
    }

    private var progressTint: Color {
        TerminalTheme.border
    }

    private var refreshIndicator: some View {
        Group {
            if presentation.isRefreshing {
                ProgressView()
                    .controlSize(.mini)
                    .tint(TerminalTheme.secondary)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .frame(width: 14, height: 14)
    }

    private var messageColor: Color {
        switch presentation.state {
        case .failed:
            TerminalTheme.error
        case .warning, .stale:
            TerminalTheme.warning
        case .normal, .refreshing, .manual, .unavailable, .noData:
            TerminalTheme.secondary
        }
    }

    private var statusColor: Color {
        switch presentation.state {
        case .failed:
            TerminalTheme.error
        case .warning, .stale:
            TerminalTheme.warning
        case .normal, .refreshing, .manual, .unavailable, .noData:
            TerminalTheme.secondary
        }
    }

    private var statusSymbol: String {
        switch presentation.state {
        case .failed:
            "exclamationmark.triangle"
        case .stale:
            "clock.badge.exclamationmark"
        case .warning:
            "exclamationmark.circle"
        case .normal, .refreshing, .manual, .unavailable, .noData:
            "info.circle"
        }
    }
}

private struct LimitWindowProgressRow: View {
    let window: DashboardLimitWindowPresentation
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.displayName)
                    .font(TerminalTheme.emphasizedBodyFont)
                    .foregroundStyle(TerminalTheme.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(window.usedText)
                    .font(TerminalTheme.emphasizedBodyFont)
                    .foregroundStyle(TerminalTheme.primary)
                    .lineLimit(1)
            }

            TerminalStatusMeter(
                value: window.usedPercent,
                tint: tint,
                accessibilityLabel: window.accessibilityLabel,
                accessibilityValue: window.accessibilityValue
            )

            if let resetText = window.resetText {
                Text(resetText)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .lineLimit(1)
            }
        }
    }
}
