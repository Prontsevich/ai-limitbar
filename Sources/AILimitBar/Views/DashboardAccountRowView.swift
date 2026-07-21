import AppKit
import SwiftUI

struct DashboardLimitWindowFocusTarget: Hashable {
    let providerID: String
    let accountID: String
    let windowID: String
}

struct DashboardAccountRowView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var appModel: AppModel
    let row: AccountSnapshotRow
    let isStale: Bool
    let onOpenOllamaConnection: (() -> Void)?
    @Binding var focusedLimitWindow: DashboardLimitWindowFocusTarget?
    @Binding var showsKeyboardFocus: Bool
    let onClearLimitWindowFocus: () -> Void

    @State private var isShowingDetails = false

    private var presentation: DashboardAccountPresentation {
        DashboardAccountPresentation(
            row: row,
            isStale: isStale,
            isGlobalRefresh: appModel.isRefreshing,
            displayModeForWindow: {
                appModel.usageDisplayMode(for: row.account, windowID: $0.id)
            },
            locale: locale
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
            .accessibilityLabel(
                AppStrings.Dashboard.refreshAccount.formatted(locale: locale, presentation.accountName)
            )
            .accessibilityValue(
                presentation.isRefreshing
                    ? AppStrings.Common.refreshing.localized(locale: locale)
                    : AppStrings.Common.ready.localized(locale: locale)
            )

            Button {
                isShowingDetails.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(TerminalIconButtonStyle())
            .help(AppStrings.Dashboard.showDetails.localized(locale: locale))
            .accessibilityLabel(
                AppStrings.Dashboard.showDetailsForAccount.formatted(
                    locale: locale,
                    presentation.accountName
                )
            )
            .popover(isPresented: $isShowingDetails, arrowEdge: .trailing) {
                AccountDetailsView(
                    appModel: appModel,
                    row: row,
                    onOpenOllamaConnection: onOpenOllamaConnection
                )
                    .frame(width: 360)
            }
        }
    }

    @ViewBuilder
    private var accountContent: some View {
        if let statusText = presentation.statusText {
            Label(statusText, systemImage: statusSymbol)
                .font(TerminalTheme.captionFont)
                .foregroundStyle(statusColor)
                .accessibilityLabel(statusText)
        }

        if !presentation.windows.isEmpty {
            ForEach(presentation.windows) { window in
                LimitWindowProgressRow(
                    window: window,
                    tint: progressTint,
                    onToggle: {
                        appModel.toggleUsageDisplayMode(for: row.account, windowID: window.id)
                    },
                    focusTarget: DashboardLimitWindowFocusTarget(
                        providerID: row.account.providerID,
                        accountID: row.account.accountID,
                        windowID: window.id
                    ),
                    focusedLimitWindow: $focusedLimitWindow,
                    showsKeyboardFocus: $showsKeyboardFocus,
                    onClearFocus: onClearLimitWindowFocus
                )

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
    let onToggle: () -> Void
    let focusTarget: DashboardLimitWindowFocusTarget
    @Binding var focusedLimitWindow: DashboardLimitWindowFocusTarget?
    @Binding var showsKeyboardFocus: Bool
    let onClearFocus: () -> Void

    private var showsFocusOutline: Bool {
        showsKeyboardFocus && focusedLimitWindow == focusTarget
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(window.displayName)
                        .font(TerminalTheme.emphasizedBodyFont)
                        .foregroundStyle(TerminalTheme.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(window.displayText)
                        .font(TerminalTheme.emphasizedBodyFont)
                        .foregroundStyle(TerminalTheme.primary)
                        .lineLimit(1)
                }

                TerminalStatusMeter(value: window.displayPercent, tint: tint)

                if let resetText = window.resetText {
                    Text(resetText)
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(LimitWindowProgressButtonStyle())
        .simultaneousGesture(
            TapGesture().onEnded {
                onClearFocus()
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(
                    showsFocusOutline ? TerminalTheme.primary : .clear,
                    lineWidth: 2
                )
        }
        .help(window.toggleHelp)
        .accessibilityLabel(window.accessibilityLabel)
        .accessibilityValue(window.accessibilityValue)
        .accessibilityHint(window.toggleAccessibilityHint)
        .accessibilityIdentifier(
            "dashboard.meter.\(focusTarget.providerID).\(focusTarget.accountID).\(focusTarget.windowID)"
        )
    }
}

private struct LimitWindowProgressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LimitWindowProgressButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed
        )
    }
}

private struct LimitWindowProgressButtonSurface<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @State private var isHovering = false
    @State private var hasPushedCursor = false

    private var fill: Color {
        if isPressed {
            return TerminalTheme.primary.opacity(0.16)
        }
        if isHovering {
            return TerminalTheme.primary.opacity(0.08)
        }
        return .clear
    }

    private var borderOpacity: Double {
        if isPressed {
            return 0.92
        }
        if isHovering {
            return 0.72
        }
        return 0
    }

    var body: some View {
        label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .background(fill)
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(TerminalTheme.border.opacity(borderOpacity), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .onHover(perform: updateHoverState)
            .onDisappear(perform: restoreCursorIfNeeded)
    }

    private func updateHoverState(_ isHovering: Bool) {
        self.isHovering = isHovering

        if isHovering, !hasPushedCursor {
            NSCursor.pointingHand.push()
            hasPushedCursor = true
        } else if !isHovering {
            restoreCursorIfNeeded()
        }
    }

    private func restoreCursorIfNeeded() {
        guard hasPushedCursor else { return }
        NSCursor.pop()
        hasPushedCursor = false
    }
}
