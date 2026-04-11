import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bootstrap singletons (order matters: audio first, then UI, then hotkey).
        _ = MicrophoneController.shared
        _ = HUDController.shared
        _ = MuteStats.shared
        statusBar = StatusBarController()
        HotkeyManager.shared.register()

        // Apply user-controlled Dock-icon visibility and react to changes live.
        applyActivationPolicy(showDock: Preferences.shared.showDockIcon)
        Preferences.shared.$showDockIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showDock in
                self?.applyActivationPolicy(showDock: showDock)
            }
            .store(in: &cancellables)

        // Optional features.
        FocusObserver.shared.start()

        // Initialize Sparkle (kicks off background update checks per its prefs).
        _ = UpdaterController.shared

        // Show the main window on first launch.
        MainWindowController.shared.show()
    }

    private func applyActivationPolicy(showDock: Bool) {
        // .accessory keeps the app menu-bar-only (current behavior).
        // .regular puts an icon in the Dock and adds an app menu.
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
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
