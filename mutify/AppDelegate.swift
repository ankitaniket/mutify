import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bootstrap the singletons (order matters: audio first, then UI, then hotkey).
        _ = MicrophoneController.shared
        _ = HUDController.shared
        statusBar = StatusBarController()
        HotkeyManager.shared.register()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
