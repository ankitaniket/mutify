import AppKit
import SwiftUI

/// Hosts `SettingsView` in a regular AppKit window. We do this instead of
/// relying on SwiftUI's `Settings` scene + `showSettingsWindow:` selector
/// because that selector has no responder when the app runs in `.accessory`
/// activation policy (no Dock icon, no app menu), so right-click → Settings…
/// from the menu bar item silently fails.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Mutify Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        // Remove the hairline separator under the title bar so the TabView's
        // tinted header sits flush with the chrome.
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("MutifySettingsWindow")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = self.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }
}
