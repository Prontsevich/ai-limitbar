import AppKit
import SwiftUI

enum ApplicationLifecycle {
    @MainActor
    private static var directSettingsWindowController: NSWindowController?

    @MainActor
    private static var directOllamaWindowController: NSWindowController?

    @MainActor
    static func activate() {
        NSApplication.shared.activate()
    }

    @MainActor
    static func openSettings(using openWindow: OpenWindowAction) {
        if let settingsWindow = visibleSettingsWindow() {
            activate()
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let targetVisibleRect = menuBarPanelVisibleRect()
        activate()
        openWindow(id: SettingsWindowConfiguration.id)

        guard let targetVisibleRect else { return }
        centerNewSettingsWindow(in: targetVisibleRect, attemptsRemaining: 3)
    }

    @MainActor
    static func openSettings(appModel: AppModel) {
        if let settingsWindow = visibleSettingsWindow() {
            activate()
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(appModel: appModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = SettingsWindowConfiguration.title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(SettingsWindowConfiguration.preferredSize)
        window.contentMinSize = SettingsWindowConfiguration.preferredSize

        let controller = NSWindowController(window: window)
        directSettingsWindowController = controller

        activate()
        controller.showWindow(nil)
        if let visibleRect = menuBarPanelVisibleRect() {
            window.setFrame(
                SettingsWindowConfiguration.centeredWindowFrame(window.frame, in: visibleRect),
                display: true
            )
        }
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    static func openOllamaConnection(using openWindow: OpenWindowAction) {
        activate()

        if let connectionWindow = visibleOllamaConnectionWindow() {
            connectionWindow.makeKeyAndOrderFront(nil)
            return
        }

        openWindow(id: OllamaConnectionWindowConfiguration.id)
        DispatchQueue.main.async {
            visibleOllamaConnectionWindow()?.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor
    static func openOllamaConnection(appModel: AppModel) {
        activate()

        if let connectionWindow = visibleOllamaConnectionWindow() {
            connectionWindow.makeKeyAndOrderFront(nil)
            return
        }

        var controller: NSWindowController?
        let rootView = OllamaWebPageConnectionWindow(
            appModel: appModel,
            dismiss: {
                controller?.close()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = OllamaConnectionWindowConfiguration.title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(OllamaConnectionWindowConfiguration.preferredSize)

        controller = NSWindowController(window: window)
        directOllamaWindowController = controller
        controller?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    static func terminate() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor
    private static func menuBarPanelVisibleRect() -> CGRect? {
        if let screen = NSApplication.shared.keyWindow?.screen ?? NSApplication.shared.mainWindow?.screen {
            return screen.visibleFrame
        }

        let pointerLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(pointerLocation)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame
    }

    @MainActor
    private static func visibleSettingsWindow() -> NSWindow? {
        NSApplication.shared.windows.first { window in
            window.title == SettingsWindowConfiguration.title && window.isVisible
        }
    }

    @MainActor
    private static func visibleOllamaConnectionWindow() -> NSWindow? {
        NSApplication.shared.windows.first { window in
            window.title == OllamaConnectionWindowConfiguration.title && window.isVisible
        }
    }

    @MainActor
    private static func settingsWindow() -> NSWindow? {
        NSApplication.shared.windows.first { window in
            window.title == SettingsWindowConfiguration.title
        }
    }

    @MainActor
    private static func centerNewSettingsWindow(in visibleRect: CGRect, attemptsRemaining: Int) {
        DispatchQueue.main.async {
            guard let settingsWindow = settingsWindow() else {
                guard attemptsRemaining > 1 else { return }
                centerNewSettingsWindow(
                    in: visibleRect,
                    attemptsRemaining: attemptsRemaining - 1
                )
                return
            }

            let centeredFrame = SettingsWindowConfiguration.centeredWindowFrame(
                settingsWindow.frame,
                in: visibleRect
            )
            settingsWindow.setFrame(centeredFrame, display: true)
            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }
}
