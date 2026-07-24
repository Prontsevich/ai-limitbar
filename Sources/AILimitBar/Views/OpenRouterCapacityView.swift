import SwiftUI

struct OpenRouterCapacityDashboardContent: View {
    @Environment(\.locale) private var locale
    let presentation: OpenRouterCapacityPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if presentation.state != .current {
                Label(presentation.statusText, systemImage: statusSymbol)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(statusColor)
                    .accessibilityLabel(presentation.statusText)
            }

            capacitySectionTitle(
                AppStrings.OpenRouter.sharedCredits.localized(locale: locale)
            )
            OpenRouterCapacityMetricRow(
                metric: presentation.sharedCredits,
                showsFreshness: false
            )
            .accessibilityIdentifier(
                "dashboard.openrouter.shared.\(presentation.accountID)"
            )

            TerminalRule()
                .padding(.vertical, 1)

            capacitySectionTitle(
                AppStrings.OpenRouter.apiKeys.localized(locale: locale)
            )
            if presentation.credentials.isEmpty {
                Text(AppStrings.OpenRouter.noOrdinaryKeys.resource(locale: locale))
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(presentation.credentials.enumerated()), id: \.element.id) {
                    index,
                    credential in
                    if index > 0 {
                        TerminalRule()
                            .padding(.vertical, 1)
                    }
                    OpenRouterCredentialCapacityGroup(
                        credential: credential,
                        showsFreshness: false
                    )
                }
            }
        }
    }

    private func capacitySectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TerminalTheme.detailLabelFont)
            .foregroundStyle(TerminalTheme.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private var statusColor: Color {
        OpenRouterCapacityColors.color(for: presentation.state)
    }

    private var statusSymbol: String {
        OpenRouterCapacityColors.symbol(for: presentation.state)
    }
}

struct OpenRouterCapacityDetailsContent: View {
    @Environment(\.locale) private var locale
    let presentation: OpenRouterCapacityPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            OpenRouterCapacityMetricRow(
                metric: presentation.sharedCredits,
                showsFreshness: true
            )
            .accessibilityIdentifier("details.openrouter.shared")

            if presentation.credentials.isEmpty {
                TerminalRule()
                Text(AppStrings.OpenRouter.noOrdinaryKeys.resource(locale: locale))
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(presentation.credentials) { credential in
                    TerminalRule()
                    OpenRouterCredentialCapacityGroup(
                        credential: credential,
                        showsFreshness: true
                    )
                }
            }
        }
    }
}

private struct OpenRouterCredentialCapacityGroup: View {
    let credential: OpenRouterCredentialCapacityPresentation
    let showsFreshness: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(credential.displayName)
                    .font(TerminalTheme.emphasizedBodyFont)
                    .foregroundStyle(TerminalTheme.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(credential.statusText)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(
                        OpenRouterCapacityColors.color(for: credential.state)
                    )
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("openrouter.key.\(credential.id)")

            if credential.metrics.isEmpty {
                Text(credential.statusText)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(
                        OpenRouterCapacityColors.color(for: credential.state)
                    )
            } else {
                ForEach(credential.metrics) { metric in
                    OpenRouterCapacityMetricRow(
                        metric: metric,
                        showsFreshness: showsFreshness
                    )
                    .padding(.leading, 9)
                }
            }
        }
    }
}

private struct OpenRouterCapacityMetricRow: View {
    let metric: OpenRouterCapacityMetricPresentation
    let showsFreshness: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(metric.displayName)
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(metric.valueText)
                    .font(TerminalTheme.emphasizedBodyFont)
                    .foregroundStyle(
                        OpenRouterCapacityColors.color(for: metric.state)
                    )
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let resetText = metric.resetText {
                Text(resetText)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
            }
            if showsFreshness, let freshnessText = metric.freshnessText {
                Text(freshnessText)
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(
                        metric.state == .stale
                            ? TerminalTheme.warning
                            : TerminalTheme.secondary
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.displayName)
        .accessibilityValue(metric.accessibilityValue)
        .accessibilityIdentifier("openrouter.metric.\(metric.id)")
    }
}

private enum OpenRouterCapacityColors {
    static func color(for state: OpenRouterCapacityState) -> Color {
        switch state {
        case .current, .unlimited:
            TerminalTheme.healthy
        case .partial, .stale, .unknown, .recoveryRequired, .deletionPending:
            TerminalTheme.warning
        case .credentialError:
            TerminalTheme.error
        case .unavailable, .disabled:
            TerminalTheme.secondary
        }
    }

    static func symbol(for state: OpenRouterCapacityState) -> String {
        switch state {
        case .current, .unlimited:
            "checkmark.circle"
        case .partial:
            "exclamationmark.circle"
        case .stale:
            "clock.badge.exclamationmark"
        case .credentialError:
            "exclamationmark.triangle"
        case .unavailable, .unknown, .disabled, .recoveryRequired,
             .deletionPending:
            "info.circle"
        }
    }
}
