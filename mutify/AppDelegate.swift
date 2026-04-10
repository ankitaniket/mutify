import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bootstrap singletons (order matters: audio first, then UI, then hotkey).
        _ = MicrophoneController.shared
        _ = HUDController.shared
        statusBar = StatusBarController()
        HotkeyManager.shared.register()

        // Show the main window on first launch.
        MainWindowController.shared.show()
    }

    /// Closing the main window must NOT quit the app — Mutify keeps running
    /// in the menu bar so the global shortcut still works.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Re-open the main window when the user clicks the Dock icon and no
    /// window is currently visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowController.shared.show()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
