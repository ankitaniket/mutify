import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut for toggling the microphone mute state.
    /// Default: ⌘⇧0
    static let toggleMute = Self(
        "toggleMute",
        default: .init(.zero, modifiers: [.command, .shift])
    )

    /// Optional: explicit "force mute" shortcut (no default).
    static let forceMute = Self("forceMute")

    /// Optional: explicit "force unmute" shortcut (no default).
    static let forceUnmute = Self("forceUnmute")
}
