import SwiftUI

@main
struct MutifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Empty Settings scene satisfies SwiftUI's "App must have a Scene" requirement.
        // The real UI is owned by AppDelegate via MainWindowController.
        Settings {
            SettingsView()
        }
    }
}
