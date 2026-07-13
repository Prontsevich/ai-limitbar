import SwiftUI

@main
struct AILimitBarApp: App {
    @StateObject private var appModel: AppModel

    init() {
        let ollamaClient = OllamaWebPageClientController()
        _appModel = StateObject(
            wrappedValue: AppModel(ollamaWebPageClient: ollamaClient)
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView(appModel: appModel)
        } label: {
            Label(appModel.menuBarTitle, systemImage: appModel.menuBarSystemImage)
                .accessibilityLabel("AI Limitbar")
                .accessibilityValue(appModel.menuBarAccessibilityValue)
        }
        .menuBarExtraStyle(.window)

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
    }
}
