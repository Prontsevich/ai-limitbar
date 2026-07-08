import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(appModel: AppModel) {
        if let window {
            focus(window)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(appModel: appModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "AI Limitbar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 600))
        window.minSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.delegate = self
        window.center()

        self.window = window
        focus(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === window else {
            return
        }
        closingWindow.delegate = nil
        window = nil
    }

    private func focus(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
