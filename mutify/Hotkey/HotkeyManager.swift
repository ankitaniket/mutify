import Foundation
import KeyboardShortcuts

/// Wires the global mute shortcuts to the microphone controller and HUD.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private init() {}

    func register() {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) { [weak self] in
            self?.handleToggle()
        }
        KeyboardShortcuts.onKeyDown(for: .forceMute) { [weak self] in
            self?.handleForce(muted: true)
        }
        KeyboardShortcuts.onKeyDown(for: .forceUnmute) { [weak self] in
            self?.handleForce(muted: false)
        }
    }

    private func handleToggle() {
        let nowMuted = MicrophoneController.shared.toggle()
        HUDController.shared.show(muted: nowMuted)
    }

    private func handleForce(muted: Bool) {
        // No-op if already in the desired state — still flash the HUD so the
        // user gets confirmation their key fired.
        MicrophoneController.shared.setMuted(muted)
        HUDController.shared.show(muted: muted)
    }
}
