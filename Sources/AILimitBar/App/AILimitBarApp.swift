import SwiftUI

@main
struct AILimitBarApp: App {
    @StateObject private var appModel: AppModel
    @StateObject private var appLanguagePreference: AppLanguagePreference
    @StateObject private var menuBarStatusItemController: MenuBarStatusItemController

    init() {
        let ollamaClient = OllamaWebPageClientController()
        let launchOptions = AppLaunchOptions()
        let languagePreference = AppLanguagePreference()
        let model = AppModel(
            ollamaWebPageClient: ollamaClient,
            storageDirectory: launchOptions.storageDirectory
        )
        _appModel = StateObject(wrappedValue: model)
        _appLanguagePreference = StateObject(wrappedValue: languagePreference)
        _menuBarStatusItemController = StateObject(
            wrappedValue: MenuBarStatusItemController(
                appModel: model,
                appLanguagePreference: languagePreference
            )
        )
    }

    var body: some Scene {
        Window(
            AppStrings.Window.settingsTitle.localized(locale: appLanguagePreference.effectiveLocale),
            id: SettingsWindowConfiguration.id
        ) {
            AppLocaleScope(languagePreference: appLanguagePreference) {
                SettingsView(
                    appModel: appModel,
                    appLanguagePreference: appLanguagePreference
                )
            }
                .windowMinimizeBehavior(.disabled)
                .windowResizeBehavior(.disabled)
                .windowFullScreenBehavior(.disabled)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowResizability(.contentMinSize)
        .defaultWindowPlacement { content, context in
            let contentSize = content.sizeThatFits(.unspecified)
            let placement = SettingsWindowConfiguration.defaultPlacement(
                contentSize: contentSize,
                visibleRect: context.defaultDisplay.visibleRect
            )
            return WindowPlacement(placement.position, size: placement.size)
        }

        Window(
            AppStrings.Window.ollamaTitle.localized(locale: appLanguagePreference.effectiveLocale),
            id: OllamaConnectionWindowConfiguration.id
        ) {
            AppLocaleScope(languagePreference: appLanguagePreference) {
                OllamaWebPageConnectionWindow(appModel: appModel)
            }
                .windowMinimizeBehavior(.disabled)
                .windowResizeBehavior(.disabled)
                .windowFullScreenBehavior(.disabled)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowResizability(.contentMinSize)
        .defaultWindowPlacement { content, context in
            let size = OllamaConnectionWindowConfiguration.defaultSize(
                contentSize: content.sizeThatFits(.unspecified),
                visibleRect: context.defaultDisplay.visibleRect
            )
            return WindowPlacement(size: size)
        }
    }
}
