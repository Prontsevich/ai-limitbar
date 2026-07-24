import AILimitBarCore
import Foundation

enum OpenRouterCapacityState: Equatable {
    case current
    case partial
    case stale
    case unavailable
    case unknown
    case unlimited
    case credentialError
    case disabled
    case recoveryRequired
    case deletionPending
}

struct OpenRouterCapacityMetricPresentation: Identifiable, Equatable {
    let id: String
    let displayName: String
    let valueText: String
    let resetText: String?
    let freshnessText: String?
    let state: OpenRouterCapacityState
    let accessibilityValue: String
}

struct OpenRouterCredentialCapacityPresentation: Identifiable, Equatable {
    let id: String
    let slotID: String
    let displayName: String
    let isEnabled: Bool
    let lifecycleState: CredentialLifecycleState
    let state: OpenRouterCapacityState
    let statusText: String
    let metrics: [OpenRouterCapacityMetricPresentation]
}

struct OpenRouterCapacityPresentation: Equatable {
    let accountID: String
    let accountName: String
    let state: OpenRouterCapacityState
    let statusText: String
    let sharedCredits: OpenRouterCapacityMetricPresentation
    let credentials: [OpenRouterCredentialCapacityPresentation]

    init(
        account: ProviderAccount,
        snapshot: CapacitySnapshot?,
        credentialContexts: [ProviderCredentialContext],
        refreshStates: [CredentialContextRefreshState],
        diagnostics: [CredentialContextDiagnostic],
        now: Date = Date(),
        locale: Locale = Locale(identifier: "en_US")
    ) {
        accountID = account.accountID
        accountName = account.displayName
        let ordinaryCredentials = credentialContexts
            .filter { $0.slot.role == .ordinary }
            .sorted {
                ($0.context.displayName ?? "").localizedCaseInsensitiveCompare(
                    $1.context.displayName ?? ""
                ) == .orderedAscending
            }
        let managementCredential = credentialContexts.first {
            $0.slot.role == .management
                && $0.slot.lifecycleState == .active
                && $0.slot.isEnabled
        }
        let refreshStateBySlot = Dictionary(
            uniqueKeysWithValues: refreshStates.map { ($0.slotID, $0) }
        )
        let diagnosticBySlot = Dictionary(
            uniqueKeysWithValues: diagnostics.map { ($0.slotID, $0) }
        )
        let metricsByContext = Dictionary(
            grouping: snapshot?.metrics ?? [],
            by: \.accountContextID
        )

        let rootContextID = snapshot?.accountContexts.first(where: {
            $0.parentContextID == nil
        })?.contextID
        let sharedMetric = managementCredential.flatMap { _ in
            (rootContextID.flatMap { metricsByContext[$0] } ?? [])
                .first(where: {
                    $0.metricID == "account-credits"
                        && $0.sourceID
                            == OpenRouterProviderContract.managementSourceID
                })
        }
        sharedCredits = Self.metricPresentation(
            sharedMetric,
            fallbackID: "account-credits",
            locale: locale,
            now: now
        )

        credentials = ordinaryCredentials.map { credential in
            let diagnostic = diagnosticBySlot[credential.slot.slotID]
            let metrics = (metricsByContext[credential.context.contextID] ?? [])
                .sorted {
                    Self.metricOrder($0.metricID)
                        < Self.metricOrder($1.metricID)
                }
                .map {
                    Self.metricPresentation(
                        $0,
                        fallbackID: $0.metricID,
                        locale: locale,
                        now: now
                    )
                }
            let state = Self.credentialState(
                credential,
                metrics: metrics,
                diagnostic: diagnostic
            )
            return OpenRouterCredentialCapacityPresentation(
                id: credential.context.contextID,
                slotID: credential.slot.slotID,
                displayName: credential.context.displayName
                    ?? AppStrings.OpenRouter.unnamedKey.localized(locale: locale),
                isEnabled: credential.slot.isEnabled,
                lifecycleState: credential.slot.lifecycleState,
                state: state,
                statusText: Self.credentialStatusText(
                    state: state,
                    diagnostic: diagnostic,
                    refreshState: refreshStateBySlot[credential.slot.slotID],
                    locale: locale
                ),
                metrics: metrics
            )
        }

        let managementDiagnostic = managementCredential.flatMap {
            diagnosticBySlot[$0.slot.slotID]
        }
        let aggregateCredentials = credentials.filter {
            $0.lifecycleState == .active && $0.isEnabled
        }
        state = Self.accountState(
            sharedCredits: sharedCredits,
            credentials: aggregateCredentials,
            managementDiagnostic: managementDiagnostic
        )
        statusText = Self.statusText(for: state, locale: locale)
    }

    private static func accountState(
        sharedCredits: OpenRouterCapacityMetricPresentation,
        credentials: [OpenRouterCredentialCapacityPresentation],
        managementDiagnostic: CredentialContextDiagnostic?
    ) -> OpenRouterCapacityState {
        let visibleMetrics = credentials.flatMap(\.metrics)
        let hasUsableMetrics = visibleMetrics.contains {
            [.current, .stale, .unlimited].contains($0.state)
        } || [.current, .stale, .unlimited].contains(sharedCredits.state)
        let hasUnknownMetrics = sharedCredits.state == .unknown
            || credentials.contains { $0.state == .unknown }
        let hasCredentialError = credentials.contains {
            [.partial, .credentialError, .recoveryRequired, .deletionPending]
                .contains($0.state)
        } || managementDiagnostic != nil
        if hasCredentialError && hasUsableMetrics {
            return .partial
        }
        if hasCredentialError {
            return .credentialError
        }
        if visibleMetrics.contains(where: { $0.state == .stale })
            || sharedCredits.state == .stale {
            return .stale
        }
        if hasUsableMetrics {
            return .current
        }
        if hasUnknownMetrics {
            return .unknown
        }
        return .unavailable
    }

    private static func credentialState(
        _ credential: ProviderCredentialContext,
        metrics: [OpenRouterCapacityMetricPresentation],
        diagnostic: CredentialContextDiagnostic?
    ) -> OpenRouterCapacityState {
        switch credential.slot.lifecycleState {
        case .pendingCreation:
            return .recoveryRequired
        case .pendingDeletion:
            return .deletionPending
        case .active:
            break
        }
        guard credential.slot.isEnabled else {
            return .disabled
        }
        if diagnostic != nil {
            return metrics.isEmpty ? .credentialError : .partial
        }
        if metrics.contains(where: { $0.state == .stale }) {
            return .stale
        }
        if metrics.contains(where: { $0.state == .current }) {
            return .current
        }
        if metrics.contains(where: { $0.state == .unlimited }) {
            return .unlimited
        }
        if metrics.contains(where: { $0.state == .unknown }) {
            return .unknown
        }
        return .unavailable
    }

    private static func credentialStatusText(
        state: OpenRouterCapacityState,
        diagnostic: CredentialContextDiagnostic?,
        refreshState: CredentialContextRefreshState?,
        locale: Locale
    ) -> String {
        if let diagnostic {
            return diagnosticText(diagnostic.code, locale: locale)
        }
        switch state {
        case .current:
            if let date = refreshState?.lastSuccessfulRefreshAt {
                return AppStrings.OpenRouter.updated.formatted(
                    locale: locale,
                    AppFormatters.shortDate(date, locale: locale)
                )
            }
            return AppStrings.OpenRouter.current.localized(locale: locale)
        case .partial:
            return AppStrings.OpenRouter.partial.localized(locale: locale)
        case .stale:
            return AppStrings.Common.stale.localized(locale: locale)
        case .unavailable:
            return AppStrings.Common.unavailable.localized(locale: locale)
        case .unknown:
            return AppStrings.Common.unknown.localized(locale: locale)
        case .unlimited:
            return AppStrings.Common.unlimited.localized(locale: locale)
        case .credentialError:
            return AppStrings.OpenRouter.credentialUnavailable.localized(locale: locale)
        case .disabled:
            return AppStrings.OpenRouter.disabled.localized(locale: locale)
        case .recoveryRequired:
            return AppStrings.OpenRouter.recoveryRequired.localized(locale: locale)
        case .deletionPending:
            return AppStrings.OpenRouter.deletionPending.localized(locale: locale)
        }
    }

    private static func statusText(
        for state: OpenRouterCapacityState,
        locale: Locale
    ) -> String {
        switch state {
        case .current:
            AppStrings.OpenRouter.current.localized(locale: locale)
        case .partial:
            AppStrings.OpenRouter.partial.localized(locale: locale)
        case .stale:
            AppStrings.Common.stale.localized(locale: locale)
        case .unavailable:
            AppStrings.Common.unavailable.localized(locale: locale)
        case .unknown:
            AppStrings.Common.unknown.localized(locale: locale)
        case .unlimited:
            AppStrings.Common.unlimited.localized(locale: locale)
        case .credentialError:
            AppStrings.Common.error.localized(locale: locale)
        case .disabled:
            AppStrings.OpenRouter.disabled.localized(locale: locale)
        case .recoveryRequired:
            AppStrings.OpenRouter.recoveryRequired.localized(locale: locale)
        case .deletionPending:
            AppStrings.OpenRouter.deletionPending.localized(locale: locale)
        }
    }

    private static func metricPresentation(
        _ metric: CapacityMetric?,
        fallbackID: String,
        locale: Locale,
        now: Date
    ) -> OpenRouterCapacityMetricPresentation {
        guard let metric else {
            let value = AppStrings.Common.unavailable.localized(locale: locale)
            return OpenRouterCapacityMetricPresentation(
                id: fallbackID,
                displayName: metricName(fallbackID, locale: locale),
                valueText: value,
                resetText: nil,
                freshnessText: nil,
                state: .unavailable,
                accessibilityValue: value
            )
        }

        let isStale = now.timeIntervalSince(metric.freshness.observedAt)
            > TimeInterval(OpenRouterProviderContract.maximumAgeSeconds)
        let state: OpenRouterCapacityState = switch metric.availability {
        case .known:
            isStale ? .stale : .current
        case .unlimited:
            isStale ? .stale : .unlimited
        case .unavailable:
            .unavailable
        case .unknown:
            .unknown
        case .manual:
            .unknown
        }
        let name = metricName(metric.metricID, locale: locale)
        let value = metricValue(metric, locale: locale)
        let reset = resetText(metric.window, now: now, locale: locale)
        let freshness: String? = switch metric.availability {
        case .known, .unlimited:
            isStale
                ? AppStrings.OpenRouter.staleUpdated.formatted(
                    locale: locale,
                    AppFormatters.shortDate(metric.freshness.observedAt, locale: locale)
                )
                : AppStrings.OpenRouter.updated.formatted(
                    locale: locale,
                    AppFormatters.shortDate(metric.freshness.observedAt, locale: locale)
                )
        case .unavailable, .manual, .unknown:
            nil
        }
        let accessibility = [value, reset, freshness]
            .compactMap { $0 }
            .joined(separator: ", ")
        return OpenRouterCapacityMetricPresentation(
            id: "\(metric.accountContextID):\(metric.sourceID):\(metric.metricID)",
            displayName: name,
            valueText: value,
            resetText: reset,
            freshnessText: freshness,
            state: state,
            accessibilityValue: accessibility
        )
    }

    private static func metricValue(
        _ metric: CapacityMetric,
        locale: Locale
    ) -> String {
        switch metric.availability {
        case .unavailable:
            return AppStrings.Common.unavailable.localized(locale: locale)
        case .unknown:
            return AppStrings.Common.unknown.localized(locale: locale)
        case .unlimited:
            return AppStrings.Common.unlimited.localized(locale: locale)
        case .manual:
            return AppStrings.Common.manual.localized(locale: locale)
        case .known:
            break
        }

        guard metric.unit.kind == .currency,
              let code = metric.unit.currencyCode,
              let values = metric.values else {
            return AppStrings.Common.unknown.localized(locale: locale)
        }
        let consumed = values.consumed.map {
            AppFormatters.currency($0.value, code: code, locale: locale)
        }
        let remaining = values.remaining.map {
            AppFormatters.currency($0.value, code: code, locale: locale)
        }
        let limit = values.limit.map {
            AppFormatters.currency($0.value, code: code, locale: locale)
        }
        if metric.metricID == "account-credits",
           let remaining, let consumed, let limit {
            return AppStrings.OpenRouter.creditSummary.formatted(
                locale: locale,
                remaining,
                consumed,
                limit
            )
        }
        if let remaining, let limit {
            return AppStrings.OpenRouter.remainingOf.formatted(
                locale: locale,
                remaining,
                limit
            )
        }
        if let remaining {
            return AppStrings.OpenRouter.remaining.formatted(
                locale: locale,
                remaining
            )
        }
        if let limit {
            return AppStrings.OpenRouter.limit.formatted(
                locale: locale,
                limit
            )
        }
        if let consumed {
            return AppStrings.OpenRouter.used.formatted(
                locale: locale,
                consumed
            )
        }
        return AppStrings.Common.unknown.localized(locale: locale)
    }

    private static func resetText(
        _ window: CapacityWindow,
        now: Date,
        locale: Locale
    ) -> String? {
        if let transition = window.nextTransition {
            let relative = AppFormatters.relativeDate(
                transition.at,
                relativeTo: now,
                locale: locale
            )
            return transition.at >= now
                ? AppStrings.OpenRouter.resets.formatted(
                    locale: locale,
                    relative
                )
                : AppStrings.OpenRouter.reset.formatted(
                    locale: locale,
                    relative
                )
        }
        return switch window.kind {
        case .lifetime:
            AppStrings.OpenRouter.noReset.localized(locale: locale)
        case .fixed, .billingCycle, .rolling, .unknown:
            AppStrings.OpenRouter.resetUnknown.localized(locale: locale)
        case .none:
            nil
        }
    }

    private static func metricName(
        _ metricID: String,
        locale: Locale
    ) -> String {
        switch metricID {
        case "account-credits":
            AppStrings.OpenRouter.accountCredits.localized(locale: locale)
        case "key-credit-limit":
            AppStrings.OpenRouter.keyCreditLimit.localized(locale: locale)
        case "key-total-usage":
            AppStrings.OpenRouter.totalUsage.localized(locale: locale)
        case "key-daily-usage":
            AppStrings.OpenRouter.dailyUsage.localized(locale: locale)
        case "key-weekly-usage":
            AppStrings.OpenRouter.weeklyUsage.localized(locale: locale)
        case "key-monthly-usage":
            AppStrings.OpenRouter.monthlyUsage.localized(locale: locale)
        case "key-total-byok-usage":
            AppStrings.OpenRouter.totalBYOKUsage.localized(locale: locale)
        case "key-daily-byok-usage":
            AppStrings.OpenRouter.dailyBYOKUsage.localized(locale: locale)
        case "key-weekly-byok-usage":
            AppStrings.OpenRouter.weeklyBYOKUsage.localized(locale: locale)
        case "key-monthly-byok-usage":
            AppStrings.OpenRouter.monthlyBYOKUsage.localized(locale: locale)
        default:
            AppStrings.Common.unknown.localized(locale: locale)
        }
    }

    private static func diagnosticText(
        _ code: CredentialContextDiagnosticCode,
        locale: Locale
    ) -> String {
        switch code {
        case .authentication:
            AppStrings.OpenRouter.authenticationFailed.localized(locale: locale)
        case .insufficientPrivilege:
            AppStrings.OpenRouter.privilegeInsufficient.localized(locale: locale)
        case .throttled:
            AppStrings.OpenRouter.throttled.localized(locale: locale)
        case .transientFailure:
            AppStrings.OpenRouter.temporaryFailure.localized(locale: locale)
        case .credentialDisabled:
            AppStrings.OpenRouter.disabled.localized(locale: locale)
        case .credentialMissing:
            AppStrings.OpenRouter.credentialUnavailable.localized(locale: locale)
        }
    }

    private static func metricOrder(_ metricID: String) -> Int {
        switch metricID {
        case "key-credit-limit": 0
        case "key-daily-usage": 1
        case "key-weekly-usage": 2
        case "key-monthly-usage": 3
        case "key-total-usage": 4
        case "key-daily-byok-usage": 5
        case "key-weekly-byok-usage": 6
        case "key-monthly-byok-usage": 7
        case "key-total-byok-usage": 8
        default: 100
        }
    }
}
