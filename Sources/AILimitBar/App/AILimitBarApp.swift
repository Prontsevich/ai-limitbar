import SwiftUI

@main
struct AILimitBarApp: App {
    @StateObject private var appModel: AppModel
    @StateObject private var menuBarStatusItemController: MenuBarStatusItemController

    init() {
        let ollamaClient = OllamaWebPageClientController()
        let launchOptions = AppLaunchOptions()
        let model = AppModel(
            ollamaWebPageClient: ollamaClient,
            storageDirectory: launchOptions.storageDirectory
        )
        _appModel = StateObject(wrappedValue: model)
        _menuBarStatusItemController = StateObject(
            wrappedValue: MenuBarStatusItemController(appModel: model)
        )
    }

    var body: some Scene {
        Window(SettingsWindowConfiguration.title, id: SettingsWindowConfiguration.id) {
            SettingsView(appModel: appModel)
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

        Window(OllamaConnectionWindowConfiguration.title, id: OllamaConnectionWindowConfiguration.id) {
            OllamaWebPageConnectionWindow(appModel: appModel)
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
