import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut for toggling the microphone mute state.
    /// Default: ⌘⇧0
    static let toggleMute = Self(
        "toggleMute",
        default: .init(.zero, modifiers: [.command, .shift])
    )
}
