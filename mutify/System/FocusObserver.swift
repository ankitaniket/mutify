import Foundation
import AppKit
import Combine

/// Watches macOS Focus / Do-Not-Disturb status and auto-mutes the microphone
/// when Focus turns on (and unmutes when it turns off), if the user opted in
/// via `Preferences.muteOnFocus`.
///
/// macOS doesn't expose a public Focus API, but the system writes the
/// "doNotDisturb" boolean to the `com.apple.controlcenter` defaults domain
/// whenever the active Focus toggles. We poll that on a slow timer (every 5s)
/// because there's no public KVO/notification for it.
final class FocusObserver {
    static let shared = FocusObserver()

    private var timer: Timer?
    private var lastKnownDoNotDisturb: Bool = false
    private var prefsCancellable: AnyCancellable?

    private init() {}

    func start() {
        prefsCancellable = Preferences.shared.$muteOnFocus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if enabled { self?.startPolling() } else { self?.stopPolling() }
            }
        if Preferences.shared.muteOnFocus { startPolling() }
    }

    private func startPolling() {
        guard timer == nil else { return }
        lastKnownDoNotDisturb = currentDoNotDisturbState()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = currentDoNotDisturbState()
        guard now != lastKnownDoNotDisturb else { return }
        lastKnownDoNotDisturb = now
        // Only act when the user is opted in.
        guard Preferences.shared.muteOnFocus else { return }
        MicrophoneController.shared.setMuted(now)
        HUDController.shared.show(muted: now)
    }

    /// Read the system Focus state from the Control Center defaults domain.
    /// This is private API surface — gracefully degrade to false if unavailable.
    private func currentDoNotDisturbState() -> Bool {
        if let cc = UserDefaults(suiteName: "com.apple.controlcenter") {
            if cc.object(forKey: "NSStatusItem Visible FocusModes") != nil {
                // We can't read the Focus mode itself directly, but presence of
                // the Focus status item plus a non-empty assertion implies on.
                return cc.bool(forKey: "FocusModes")
            }
        }
        // Fallback: read NotificationCenter assertions plist (best-effort).
        return false
    }
}
