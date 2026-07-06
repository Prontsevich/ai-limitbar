import SwiftUI

@main
struct AILimitBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra(appModel.menuBarTitle, systemImage: appModel.menuBarSystemImage) {
            MenuBarPanelView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appModel)
        }
    }
}
