import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject, ObservableObject, NSPopoverDelegate {
    private let appModel: AppModel
    private let appLanguagePreference: AppLanguagePreference
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let panelPresentation: MenuBarPanelPresentationState
    private let hostingController: NSHostingController<AppLocaleScope<MenuBarPanelView>>
    private var modelObservation: AnyCancellable?
    private var languageObservation: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    init(appModel: AppModel, appLanguagePreference: AppLanguagePreference) {
        let panelPresentation = MenuBarPanelPresentationState()
        let popover = NSPopover()
        self.appModel = appModel
        self.appLanguagePreference = appLanguagePreference
        self.panelPresentation = panelPresentation
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = popover
        hostingController = NSHostingController(
            rootView: AppLocaleScope(languagePreference: appLanguagePreference) {
                MenuBarPanelView(
                    appModel: appModel,
                    onOpenSettings: { [weak appModel, weak appLanguagePreference] in
                        guard let appModel, let appLanguagePreference else { return }
                        ApplicationLifecycle.openSettings(
                            appModel: appModel,
                            appLanguagePreference: appLanguagePreference
                        )
                    },
                    onOpenAbout: { [weak appLanguagePreference] in
                        guard let appLanguagePreference else { return }
                        ApplicationLifecycle.openAbout(appLanguagePreference: appLanguagePreference)
                    },
                    onOpenOllamaConnection: { [weak appModel, weak appLanguagePreference] in
                        guard let appModel, let appLanguagePreference else { return }
                        ApplicationLifecycle.openOllamaConnection(
                            appModel: appModel,
                            appLanguagePreference: appLanguagePreference
                        )
                    },
                    onCloseDashboard: { [weak popover] in
                        popover?.performClose(nil)
                    },
                    panelPresentation: panelPresentation
                )
            }
        )
        super.init()
        configureStatusItem()
        configurePopover()
        observeModel()
        observeAppearance()
        refresh()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.title = ""
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("AI Limitbar")
        button.toolTip = "AI Limitbar"
    }

    private func configurePopover() {
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = hostingController
    }

    private func observeModel() {
        modelObservation = appModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
        languageObservation = appLanguagePreference.$effectiveLocale.sink { [weak self] _ in
            self?.refresh()
        }
    }

    private func observeAppearance() {
        appearanceObservation = NSApplication.shared.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        statusItem.button?.image = MenuBarStatusItemImageRenderer.image(
            for: appModel.menuBarIndicatorState
        )
        statusItem.button?.setAccessibilityValue(
            appModel.menuBarAccessibilityValue(locale: appLanguagePreference.effectiveLocale)
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        panelPresentation.isVisible = true
        AppTelemetry.menuBar.info("Dashboard popover opening")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hostingController.view.layoutSubtreeIfNeeded()
            self.popover.contentSize = self.hostingController.view.fittingSize
            self.activatePopoverForKeyboardInput()
        }
    }

    private func activatePopoverForKeyboardInput() {
        guard popover.isShown, let popoverWindow = hostingController.view.window else { return }

        NSApp.activate(ignoringOtherApps: true)
        popoverWindow.makeKey()
        let acceptedResponder = panelPresentation.keyboardResponder.map {
            popoverWindow.makeFirstResponder($0)
        } ?? false
        AppTelemetry.menuBar.info(
            "Dashboard keyboard activated: keyWindow=\(popoverWindow.isKeyWindow), responderAccepted=\(acceptedResponder)"
        )
    }

    func popoverDidClose(_ notification: Notification) {
        panelPresentation.isVisible = false
        AppTelemetry.menuBar.info("Dashboard popover closed")
    }
}

@MainActor
final class MenuBarPanelPresentationState: ObservableObject {
    @Published var isVisible = false
    weak var keyboardResponder: NSView?
}

enum MenuBarStatusItemImageRenderer {
    static let baseSystemImageName = "gauge.with.dots.needle.33percent"

    private static let canvasSize = NSSize(width: 20, height: 20)

    static func image(for state: MenuBarIndicatorState) -> NSImage {
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        drawBaseIcon(in: image)

        switch state {
        case .normal:
            break
        case .warning:
            drawBadge(color: TerminalTheme.warningNSColor)
        case .error:
            drawBadge(color: TerminalTheme.errorNSColor)
        }

        image.isTemplate = false
        return image
    }

    private static func drawBaseIcon(in image: NSImage) {
        guard let symbol = NSImage(systemSymbolName: baseSystemImageName, accessibilityDescription: nil) else {
            return
        }

        let configuration = NSImage.SymbolConfiguration(
            pointSize: 18,
            weight: .regular
        ).applying(
            NSImage.SymbolConfiguration(paletteColors: [NSColor.controlTextColor])
        )
        let configuredSymbol = symbol.withSymbolConfiguration(configuration) ?? symbol
        configuredSymbol.draw(
            in: NSRect(x: 0.5, y: 0.5, width: 19, height: 19),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    private static func drawBadge(color: NSColor) {
        let badgeRect = NSRect(x: 13.5, y: 13.5, width: 6, height: 6)

        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: -0.8, dy: -0.8)).fill()

        color.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
    }
}
