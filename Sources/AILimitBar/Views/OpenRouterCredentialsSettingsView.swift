import AILimitBarCore
import SwiftUI

struct OpenRouterCredentialsSettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount

    @State private var editor: OpenRouterCredentialEditorConfiguration?
    @State private var pendingDeletion: ProviderCredentialContext?
    @State private var presentedError: OpenRouterSettingsError?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ordinaryCredentialsFieldset
            managementCredentialFieldset
        }
        .sheet(item: $editor) { configuration in
            OpenRouterCredentialEditorSheet(
                appModel: appModel,
                account: currentAccount,
                configuration: configuration
            )
        }
        .alert(
            AppStrings.OpenRouter.deleteCredentialTitle.localized(locale: locale),
            isPresented: deletionConfirmationBinding,
            presenting: pendingDeletion
        ) { credential in
            Button(
                AppStrings.Common.delete.localized(locale: locale),
                role: .destructive
            ) {
                deleteCredential(credential)
            }
            Button(AppStrings.Common.cancel.localized(locale: locale), role: .cancel) {
                pendingDeletion = nil
            }
        } message: { credential in
            Text(
                AppStrings.OpenRouter.deleteCredentialMessage.formatted(
                    locale: locale,
                    displayName(for: credential)
                )
            )
        }
        .alert(
            AppStrings.OpenRouter.errorTitle.localized(locale: locale),
            isPresented: errorBinding
        ) {
            Button(AppStrings.Common.ok.localized(locale: locale), role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private var ordinaryCredentialsFieldset: some View {
        TerminalFieldset(
            title: AppStrings.OpenRouter.credentialsTitle.localized(locale: locale)
        ) {
            Button {
                editor = OpenRouterCredentialEditorConfiguration(
                    mode: .addOrdinary
                )
            } label: {
                SettingsActionIcon(systemName: "plus")
            }
            .settingsIconButton(
                help: AppStrings.OpenRouter.addKey.localized(locale: locale)
            )
            .accessibilityLabel(
                AppStrings.OpenRouter.addKey.localized(locale: locale)
            )
            .accessibilityIdentifier("settings.openrouter.add-key")
        } content: {
            Text(AppStrings.OpenRouter.ordinaryDisclosure.resource(locale: locale))
                .font(TerminalTheme.captionFont)
                .foregroundStyle(TerminalTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if ordinaryCredentials.isEmpty {
                Text(AppStrings.OpenRouter.noOrdinaryKeys.resource(locale: locale))
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
            } else {
                ForEach(Array(ordinaryCredentials.enumerated()), id: \.element.id) {
                    index,
                    credential in
                    if index > 0 {
                        TerminalRule()
                    }
                    credentialRow(credential)
                }
            }

            Text(AppStrings.OpenRouter.storedSecurely.resource(locale: locale))
                .font(TerminalTheme.captionFont)
                .foregroundStyle(TerminalTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var managementCredentialFieldset: some View {
        TerminalFieldset(
            title: AppStrings.OpenRouter.managementTitle.localized(locale: locale)
        ) {
            if managementCredential == nil {
                Button {
                    editor = OpenRouterCredentialEditorConfiguration(
                        mode: .addManagement
                    )
                } label: {
                    SettingsActionIcon(systemName: "plus")
                }
                .settingsIconButton(
                    help: AppStrings.OpenRouter.addManagement.localized(
                        locale: locale
                    )
                )
                .accessibilityLabel(
                    AppStrings.OpenRouter.addManagement.localized(locale: locale)
                )
                .accessibilityIdentifier("settings.openrouter.add-management")
            }
        } content: {
            Text(AppStrings.OpenRouter.managementDisclosure.resource(locale: locale))
                .font(TerminalTheme.captionFont)
                .foregroundStyle(TerminalTheme.warning)
                .fixedSize(horizontal: false, vertical: true)

            if let managementCredential {
                credentialRow(managementCredential)
            } else {
                Text(AppStrings.OpenRouter.managementUnavailable.resource(locale: locale))
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func credentialRow(
        _ credential: ProviderCredentialContext
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: credential))
                        .font(TerminalTheme.emphasizedBodyFont)
                        .foregroundStyle(TerminalTheme.primary)
                    Text(statusText(for: credential))
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(statusColor(for: credential))
                }

                Spacer()

                Toggle(
                    AppStrings.Common.enabled.resource(locale: locale),
                    isOn: enabledBinding(for: credential)
                )
                .labelsHidden()
                .toggleStyle(TerminalToggleStyle())
                .accessibilityLabel(
                    AppStrings.Common.enabled.localized(locale: locale)
                )
                .disabled(credential.slot.lifecycleState != .active)
                .accessibilityIdentifier(
                    "settings.openrouter.enabled.\(credential.context.contextID)"
                )
            }
            .accessibilityElement(children: .contain)

            HStack(spacing: 8) {
                if credential.slot.role == .ordinary {
                    Button(AppStrings.OpenRouter.rename.localized(locale: locale)) {
                        editor = OpenRouterCredentialEditorConfiguration(
                            mode: .rename(
                                contextID: credential.context.contextID,
                                currentName: displayName(for: credential)
                            )
                        )
                    }
                    .buttonStyle(TerminalTextButtonStyle())
                }

                Button(
                    credential.slot.lifecycleState == .pendingCreation
                        ? AppStrings.OpenRouter.recover.localized(locale: locale)
                        : AppStrings.OpenRouter.replace.localized(locale: locale)
                ) {
                    editor = OpenRouterCredentialEditorConfiguration(
                        mode: .replace(
                            slotID: credential.slot.slotID,
                            displayName: displayName(for: credential),
                            isManagement: credential.slot.role == .management,
                            isRecovery: credential.slot.lifecycleState
                                == .pendingCreation
                        )
                    )
                }
                .buttonStyle(TerminalTextButtonStyle())
                .disabled(credential.slot.lifecycleState == .pendingDeletion)

                Button(
                    AppStrings.OpenRouter.removeCredential.localized(locale: locale),
                    role: .destructive
                ) {
                    pendingDeletion = credential
                }
                .buttonStyle(TerminalTextButtonStyle())
            }
        }
        .accessibilityIdentifier(
            "settings.openrouter.credential.\(credential.context.contextID)"
        )
    }

    private var currentAccount: ProviderAccount {
        appModel.account(
            providerID: account.providerID,
            accountID: account.accountID
        ) ?? account
    }

    private var credentialContexts: [ProviderCredentialContext] {
        appModel.openRouterCredentialContexts(for: currentAccount)
    }

    private var ordinaryCredentials: [ProviderCredentialContext] {
        credentialContexts
            .filter { $0.slot.role == .ordinary }
            .sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(
                    displayName(for: $1)
                ) == .orderedAscending
            }
    }

    private var managementCredential: ProviderCredentialContext? {
        credentialContexts.first { $0.slot.role == .management }
    }

    private var capacityPresentation: OpenRouterCapacityPresentation? {
        appModel.openRouterCapacityPresentation(
            for: currentAccount,
            locale: locale
        )
    }

    private func displayName(
        for credential: ProviderCredentialContext
    ) -> String {
        if credential.slot.role == .management {
            return AppStrings.OpenRouter.managementCredential.localized(
                locale: locale
            )
        }
        return credential.context.displayName
            ?? AppStrings.OpenRouter.unnamedKey.localized(locale: locale)
    }

    private func statusText(
        for credential: ProviderCredentialContext
    ) -> String {
        if credential.slot.role == .ordinary,
           let presentation = capacityPresentation?.credentials.first(where: {
               $0.slotID == credential.slot.slotID
           }) {
            return presentation.statusText
        }
        switch credential.slot.lifecycleState {
        case .pendingCreation:
            return AppStrings.OpenRouter.recoveryRequired.localized(locale: locale)
        case .pendingDeletion:
            return AppStrings.OpenRouter.deletionPending.localized(locale: locale)
        case .active:
            if !credential.slot.isEnabled {
                return AppStrings.OpenRouter.disabled.localized(locale: locale)
            }
            if let diagnostic = appModel
                .openRouterCredentialDiagnostics(for: currentAccount)
                .first(where: { $0.slotID == credential.slot.slotID }) {
                return diagnosticText(diagnostic.code)
            }
            return AppStrings.OpenRouter.current.localized(locale: locale)
        }
    }

    private func statusColor(
        for credential: ProviderCredentialContext
    ) -> Color {
        if credential.slot.lifecycleState != .active {
            return TerminalTheme.warning
        }
        if !credential.slot.isEnabled {
            return TerminalTheme.secondary
        }
        let hasDiagnostic = appModel
            .openRouterCredentialDiagnostics(for: currentAccount)
            .contains { $0.slotID == credential.slot.slotID }
        return hasDiagnostic ? TerminalTheme.error : TerminalTheme.healthy
    }

    private func diagnosticText(
        _ code: CredentialContextDiagnosticCode
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

    private func enabledBinding(
        for credential: ProviderCredentialContext
    ) -> Binding<Bool> {
        Binding(
            get: {
                appModel.openRouterCredentialContexts(for: currentAccount)
                    .first(where: {
                        $0.slot.slotID == credential.slot.slotID
                    })?.slot.isEnabled ?? false
            },
            set: { isEnabled in
                do {
                    try appModel.setOpenRouterCredentialEnabled(
                        isEnabled,
                        for: currentAccount,
                        slotID: credential.slot.slotID
                    )
                } catch {
                    presentedError = error as? OpenRouterSettingsError
                        ?? .storageUnavailable
                }
            }
        )
    }

    private func deleteCredential(_ credential: ProviderCredentialContext) {
        defer { pendingDeletion = nil }
        do {
            try appModel.deleteOpenRouterCredential(
                for: currentAccount,
                slotID: credential.slot.slotID
            )
        } catch {
            presentedError = error as? OpenRouterSettingsError
                ?? .storageUnavailable
        }
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: {
                if !$0 {
                    pendingDeletion = nil
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: {
                if !$0 {
                    presentedError = nil
                }
            }
        )
    }

    private var errorText: String {
        (presentedError ?? .storageUnavailable)
            .localizedDescription(locale: locale)
    }
}

struct OpenRouterCredentialEditorConfiguration: Identifiable {
    enum Mode {
        case addOrdinary
        case addManagement
        case rename(contextID: String, currentName: String)
        case replace(
            slotID: String,
            displayName: String,
            isManagement: Bool,
            isRecovery: Bool
        )
    }

    let id = UUID()
    let mode: Mode
}

private struct OpenRouterCredentialEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @ObservedObject var appModel: AppModel
    let account: ProviderAccount
    let configuration: OpenRouterCredentialEditorConfiguration

    @State private var name: String
    @State private var credentialValue = ""
    @State private var presentedError: OpenRouterSettingsError?

    init(
        appModel: AppModel,
        account: ProviderAccount,
        configuration: OpenRouterCredentialEditorConfiguration
    ) {
        self.appModel = appModel
        self.account = account
        self.configuration = configuration
        let initialName: String
        switch configuration.mode {
        case let .rename(_, currentName):
            initialName = currentName
        case .addOrdinary, .addManagement, .replace:
            initialName = ""
        }
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(TerminalTheme.titleFont)
                .foregroundStyle(TerminalTheme.primary)

            TerminalFieldset(title: fieldsetTitle) {
                EmptyView()
            } content: {
                if needsName {
                    SettingsCredentialEditorRow(
                        title: AppStrings.OpenRouter.keyName.localized(
                            locale: locale
                        )
                    ) {
                        TerminalTextField(
                            AppStrings.OpenRouter.keyName.localized(locale: locale),
                            text: $name
                        )
                        .accessibilityIdentifier("settings.openrouter.key-name")
                    }
                }

                if needsCredential {
                    SettingsCredentialEditorRow(
                        title: AppStrings.OpenRouter.credential.localized(
                            locale: locale
                        )
                    ) {
                        TerminalSecureField(
                            AppStrings.OpenRouter.credentialPlaceholder.localized(
                                locale: locale
                            ),
                            text: $credentialValue
                        )
                        .accessibilityIdentifier("settings.openrouter.credential-value")
                    }

                    Text(
                        AppStrings.OpenRouter.saveWithoutReadback.resource(
                            locale: locale
                        )
                    )
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if isManagement {
                    Text(
                        AppStrings.OpenRouter.managementDisclosure.resource(
                            locale: locale
                        )
                    )
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let presentedError {
                    Text(presentedError.localizedDescription(locale: locale))
                        .font(TerminalTheme.captionFont)
                        .foregroundStyle(TerminalTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.openrouter.editor-error")
                }
            }

            HStack {
                Spacer()
                Button(AppStrings.Common.cancel.localized(locale: locale)) {
                    clearSecret()
                    dismiss()
                }
                .buttonStyle(TerminalActionButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button(AppStrings.Common.save.localized(locale: locale), action: submit)
                    .buttonStyle(TerminalActionButtonStyle(isProminent: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        (needsName && name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty)
                            || (needsCredential && credentialValue.isEmpty)
                    )
                    .accessibilityIdentifier("settings.openrouter.editor-save")
            }
        }
        .padding(20)
        .frame(width: 520)
        .background(TerminalTheme.surface)
        .onDisappear(perform: clearSecret)
    }

    private var title: String {
        switch configuration.mode {
        case .addOrdinary:
            AppStrings.OpenRouter.addKeyTitle.localized(locale: locale)
        case .addManagement:
            AppStrings.OpenRouter.addManagementTitle.localized(locale: locale)
        case .rename:
            AppStrings.OpenRouter.renameKeyTitle.localized(locale: locale)
        case let .replace(_, _, _, isRecovery):
            isRecovery
                ? AppStrings.OpenRouter.recoverCredentialTitle.localized(
                    locale: locale
                )
                : AppStrings.OpenRouter.replaceCredentialTitle.localized(
                    locale: locale
                )
        }
    }

    private var fieldsetTitle: String {
        isManagement
            ? AppStrings.OpenRouter.managementTitle.localized(locale: locale)
            : AppStrings.OpenRouter.credentialsTitle.localized(locale: locale)
    }

    private var needsName: Bool {
        switch configuration.mode {
        case .addOrdinary, .rename:
            true
        case .addManagement, .replace:
            false
        }
    }

    private var needsCredential: Bool {
        switch configuration.mode {
        case .addOrdinary, .addManagement, .replace:
            true
        case .rename:
            false
        }
    }

    private var isManagement: Bool {
        if case .addManagement = configuration.mode {
            return true
        }
        if case let .replace(_, _, isManagement, _) = configuration.mode {
            return isManagement
        }
        return false
    }

    private func submit() {
        do {
            switch configuration.mode {
            case .addOrdinary:
                _ = try appModel.createOpenRouterOrdinaryCredential(
                    for: account,
                    displayName: name,
                    credentialValue: credentialValue
                )
            case .addManagement:
                _ = try appModel.createOpenRouterManagementCredential(
                    for: account,
                    credentialValue: credentialValue
                )
            case let .rename(contextID, _):
                try appModel.renameOpenRouterOrdinaryCredential(
                    for: account,
                    contextID: contextID,
                    displayName: name
                )
            case let .replace(slotID, _, _, _):
                try appModel.replaceOpenRouterCredential(
                    for: account,
                    slotID: slotID,
                    credentialValue: credentialValue
                )
            }
            clearSecret()
            dismiss()
        } catch {
            presentedError = error as? OpenRouterSettingsError
                ?? .storageUnavailable
            clearSecret()
        }
    }

    private func clearSecret() {
        credentialValue.removeAll(keepingCapacity: false)
    }
}

private struct SettingsCredentialEditorRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(TerminalTheme.detailLabelFont)
                .foregroundStyle(TerminalTheme.secondary)
                .frame(width: 120, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension OpenRouterSettingsError {
    func localizedDescription(locale: Locale) -> String {
        switch self {
        case .invalidAccount:
            AppStrings.OpenRouter.invalidAccountError.localized(locale: locale)
        case .invalidName:
            AppStrings.OpenRouter.invalidNameError.localized(locale: locale)
        case .duplicateName:
            AppStrings.OpenRouter.duplicateNameError.localized(locale: locale)
        case .emptyCredential:
            AppStrings.OpenRouter.emptyCredentialError.localized(locale: locale)
        case .managementCredentialExists:
            AppStrings.OpenRouter.managementExistsError.localized(locale: locale)
        case .pendingDeletion:
            AppStrings.OpenRouter.pendingDeletionError.localized(locale: locale)
        case .credentialUnavailable:
            AppStrings.OpenRouter.unavailableCredentialError.localized(locale: locale)
        case .keychainUnavailable:
            AppStrings.OpenRouter.keychainError.localized(locale: locale)
        case .storageUnavailable:
            AppStrings.OpenRouter.storageError.localized(locale: locale)
        }
    }
}
