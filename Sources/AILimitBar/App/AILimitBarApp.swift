import SwiftUI

@main
struct AILimitBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()
    @StateObject private var settingsWindowController = SettingsWindowController()

    var body: some Scene {
        MenuBarExtra(appModel.menuBarTitle, systemImage: appModel.menuBarSystemImage) {
            MenuBarPanelView(
                appModel: appModel,
                openSettings: {
                    settingsWindowController.show(appModel: appModel)
                }
            )
        }
        .menuBarExtraStyle(.window)
    }
}
