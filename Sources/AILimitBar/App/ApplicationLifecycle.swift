import AppKit

enum ApplicationLifecycle {
    @MainActor
    static func terminate() {
        NSApplication.shared.terminate(nil)
    }
}
