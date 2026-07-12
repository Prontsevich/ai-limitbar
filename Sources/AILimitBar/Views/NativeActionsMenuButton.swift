import AppKit
import SwiftUI

struct NativeActionsMenuButton: View {
    let isTestEnabled: Bool
    let isUsageEnabled: Bool
    let onTest: () -> Void
    let onOpenUsage: () -> Void

    @State private var menuRequest: UInt = 0

    var body: some View {
        ZStack {
            Button {
                menuRequest &+= 1
            } label: {
                SettingsGlassIcon(systemName: "ellipsis", verticalOffset: -1)
            }
            .settingsGlassIconButton(help: "More account actions")
            .accessibilityLabel("More account actions")

            NativeActionsMenuAnchor(
                request: $menuRequest,
                isTestEnabled: isTestEnabled,
                isUsageEnabled: isUsageEnabled,
                onTest: onTest,
                onOpenUsage: onOpenUsage
            )
            .frame(width: 40, height: 40)
            .allowsHitTesting(false)
        }
    }
}

private struct NativeActionsMenuAnchor: NSViewRepresentable {
    @Binding var request: UInt
    let isTestEnabled: Bool
    let isUsageEnabled: Bool
    let onTest: () -> Void
    let onOpenUsage: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AnchorView {
        AnchorView()
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        context.coordinator.update(
            isTestEnabled: isTestEnabled,
            isUsageEnabled: isUsageEnabled,
            onTest: onTest,
            onOpenUsage: onOpenUsage
        )

        guard request != context.coordinator.lastRequest else { return }
        context.coordinator.lastRequest = request
        DispatchQueue.main.async {
            context.coordinator.present(from: nsView)
        }
    }

    final class AnchorView: NSView {
        override var isOpaque: Bool { false }
    }

    @MainActor
    final class Coordinator: NSObject {
        var lastRequest: UInt = 0
        private var targets: [MenuActionTarget] = []
        private var isPresenting = false

        func update(
            isTestEnabled: Bool,
            isUsageEnabled: Bool,
            onTest: @escaping () -> Void,
            onOpenUsage: @escaping () -> Void
        ) {
            targets = []
            let testTarget = MenuActionTarget(action: onTest)
            let usageTarget = MenuActionTarget(action: onOpenUsage)
            targets = [testTarget, usageTarget]
            testEnabled = isTestEnabled
            usageEnabled = isUsageEnabled
        }

        private var testEnabled = false
        private var usageEnabled = false

        func present(from view: NSView) {
            guard !isPresenting else { return }
            isPresenting = true
            defer { isPresenting = false }

            let menu = NSMenu()
            menu.autoenablesItems = false

            let testItem = NSMenuItem(
                title: "Test Connection",
                action: #selector(MenuActionTarget.invoke(_:)),
                keyEquivalent: ""
            )
            testItem.target = targets.first
            testItem.isEnabled = testEnabled
            testItem.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            menu.addItem(testItem)

            let usageItem = NSMenuItem(
                title: "Open Usage",
                action: #selector(MenuActionTarget.invoke(_:)),
                keyEquivalent: ""
            )
            usageItem.target = targets.dropFirst().first
            usageItem.isEnabled = usageEnabled
            usageItem.image = NSImage(systemSymbolName: "arrow.up.forward.square", accessibilityDescription: nil)
            menu.addItem(usageItem)

            menu.popUp(
                positioning: nil,
                at: NSEvent.mouseLocation,
                in: nil
            )
        }
    }
}

@MainActor
private final class MenuActionTarget: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func invoke(_ sender: Any?) {
        action()
    }
}
