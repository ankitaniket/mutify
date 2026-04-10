import AppKit
import SwiftUI

/// Hosts the SwiftUI `MainView` inside a regular AppKit window so we have full
/// control over show/hide/reopen behavior. SwiftUI's `Window` scene cannot be
/// re-opened from AppKit code once the user closes it, which breaks our
/// menu-bar "Show Mutify" item.
final class MainWindowController: NSWindowController, NSWindowDelegate {

    static let shared = MainWindowController()

    private init() {
        let hosting = NSHostingController(rootView: MainView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Mutify"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false  // critical: keep window alive after close
        window.titlebarAppearsTransparent = false
        window.center()
        window.setFrameAutosaveName("MutifyMainWindow")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Bring the window to the front, creating-and-showing it if necessary.
    func show() {
        guard let window = self.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }
}
