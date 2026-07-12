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

        Settings {
            SettingsView(appModel: appModel)
        }
    }
}
