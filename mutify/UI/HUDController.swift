import AppKit
import SwiftUI

/// Owns the toast HUD that briefly flashes "Muted" / "Unmuted" at the
/// bottom-right of the active screen, plus an optional persistent "label" HUD
/// used by the speaking-while-muted detector.
final class HUDController {
    static let shared = HUDController()

    // Toast (transient) HUD
    private let toastWindow: HUDWindow
    private let toastHost: NSHostingView<HUDContentView>
    private var dismissWorkItem: DispatchWorkItem?
    private let toastSize = NSSize(width: 140, height: 48)

    private let edgeMargin: CGFloat = 28

    private init() {
        let toastRect = NSRect(origin: .zero, size: toastSize)
        toastWindow = HUDWindow(contentRect: toastRect)
        toastHost = NSHostingView(rootView: HUDContentView(muted: false))
        toastHost.frame = toastRect
        toastWindow.contentView = toastHost
        toastWindow.alphaValue = 0
    }

    // MARK: - Toast (transient)

    /// Show "Muted" / "Unmuted" toast at the bottom-right of the active screen.
    func show(muted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.presentToast(muted: muted)
        }
        announce(muted ? "Microphone muted" : "Microphone live")
    }

    private func presentToast(muted: Bool) {
        toastHost.rootView = HUDContentView(muted: muted)
        repositionToActiveScreen(window: toastWindow, size: toastSize)

        dismissWorkItem?.cancel()
        if !toastWindow.isVisible {
            toastWindow.orderFrontRegardless()
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0 : 0.12
            toastWindow.animator().alphaValue = 1.0
        }

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOutToast()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func fadeOutToast() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0 : 0.20
            toastWindow.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            self?.toastWindow.orderOut(nil)
        }
    }

    // MARK: - Layout

    private func repositionToActiveScreen(window: NSWindow, size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: frame.maxX - size.width - edgeMargin,
            y: frame.minY + edgeMargin
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    // MARK: - VoiceOver

    private func announce(_ text: String) {
        guard Preferences.shared.voiceOverAnnouncements else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // The element MUST be a real accessibility object (NSView/NSWindow);
            // passing NSApp causes the announcement to be silently dropped.
            // Prefer the key window when present (so VoiceOver focus tracking
            // works), and fall back to our HUD toast window which is always
            // alive in the process.
            let element: Any = NSApp.keyWindow ?? self.toastWindow
            NSAccessibility.post(
                element: element,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: text,
                    .priority: NSNumber(value: NSAccessibilityPriorityLevel.high.rawValue),
                ]
            )
        }
    }
}
