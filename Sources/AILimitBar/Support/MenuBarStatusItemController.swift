import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject, ObservableObject {
    private let appModel: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let hostingController: NSHostingController<MenuBarPanelView>
    private var modelObservation: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        hostingController = NSHostingController(
            rootView: MenuBarPanelView(
                appModel: appModel,
                onOpenSettings: { [weak appModel] in
                    guard let appModel else { return }
                    ApplicationLifecycle.openSettings(appModel: appModel)
                },
                onOpenOllamaConnection: { [weak appModel] in
                    guard let appModel else { return }
                    ApplicationLifecycle.openOllamaConnection(appModel: appModel)
                }
            )
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
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
    }

    private func observeModel() {
        modelObservation = appModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
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
        statusItem.button?.setAccessibilityValue(appModel.menuBarAccessibilityValue)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hostingController.view.layoutSubtreeIfNeeded()
            self.popover.contentSize = self.hostingController.view.fittingSize
        }
    }
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
