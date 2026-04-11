import Foundation
import AppKit
import Sparkle

/// Lightweight Sparkle 2 wrapper. Owns a single `SPUStandardUpdaterController`
/// configured to start automatically and surface a "Check for Updates…" menu
/// item from `StatusBarController`.
///
/// Configuration lives in `Info.plist`:
///   • SUFeedURL — appcast.xml hosted alongside GitHub releases
///   • SUEnableInstallerLauncherService — YES (so updates work outside MAS)
///   • SUPublicEDKey — populated when the user generates a signing key
final class UpdaterController {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController

    private init() {
        // `startingUpdater: false` keeps Sparkle dormant on launch — no
        // background scheduler, no automatic check, no error toasts. We start
        // it on demand the first time the user clicks "Check for Updates…",
        // which is the safest behavior until an `appcast.xml` and EdDSA key
        // are published alongside the GitHub release.
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private var didStart = false

    private func ensureStarted() {
        guard !didStart else { return }
        controller.startUpdater()
        didStart = true
    }

    /// Wired to the menu bar's "Check for Updates…" item.
    @objc func checkForUpdates(_ sender: Any?) {
        ensureStarted()
        controller.checkForUpdates(sender)
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}
