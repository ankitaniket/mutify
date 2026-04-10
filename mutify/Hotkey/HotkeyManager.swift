import Foundation
import KeyboardShortcuts

/// Wires the global ⌘⇧0 shortcut to the microphone toggle and the HUD.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private init() {}

    func register() {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) { [weak self] in
            self?.handleToggle()
        }
    }

    private func handleToggle() {
        let nowMuted = MicrophoneController.shared.toggle()
        HUDController.shared.show(muted: nowMuted)
    }
}
