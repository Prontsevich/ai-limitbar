import AppKit
import SwiftUI

enum ApplicationLifecycle {
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
