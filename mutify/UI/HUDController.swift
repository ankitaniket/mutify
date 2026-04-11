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

    // Label (persistent) HUD
    private let labelWindow: HUDWindow
    private let labelHost: NSHostingView<HUDLabelView>
    private let labelSize = NSSize(width: 220, height: 36)

    private let edgeMargin: CGFloat = 28

    private init() {
        let toastRect = NSRect(origin: .zero, size: toastSize)
        toastWindow = HUDWindow(contentRect: toastRect)
        toastHost = NSHostingView(rootView: HUDContentView(muted: false))
        toastHost.frame = toastRect
        toastWindow.contentView = toastHost
        toastWindow.alphaValue = 0

        let labelRect = NSRect(origin: .zero, size: labelSize)
        labelWindow = HUDWindow(contentRect: labelRect)
        labelHost = NSHostingView(rootView: HUDLabelView(text: "You're muted"))
        labelHost.frame = labelRect
        labelWindow.contentView = labelHost
        labelWindow.alphaValue = 0
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
        repositionToActiveScreen(window: toastWindow, size: toastSize, raise: 0)

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

    // MARK: - Label (persistent)

    /// Show a persistent "you're muted" indicator. Caller must dismiss with
    /// `hideLabel()` when the user stops speaking or unmutes.
    func showLabel(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.labelHost.rootView = HUDLabelView(text: text)
            self.repositionToActiveScreen(
                window: self.labelWindow,
                size: self.labelSize,
                raise: self.toastSize.height + 12
            )
            if !self.labelWindow.isVisible {
                self.labelWindow.orderFrontRegardless()
            }
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = reduceMotion ? 0 : 0.15
                self.labelWindow.animator().alphaValue = 1.0
            }
        }
        announce(text)
    }

    func hideLabel() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = reduceMotion ? 0 : 0.20
                self.labelWindow.animator().alphaValue = 0.0
            } completionHandler: {
                self.labelWindow.orderOut(nil)
            }
        }
    }

    // MARK: - Layout

    private func repositionToActiveScreen(window: NSWindow, size: NSSize, raise: CGFloat) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: frame.maxX - size.width - edgeMargin,
            y: frame.minY + edgeMargin + raise
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    // MARK: - VoiceOver

    private func announce(_ text: String) {
        guard Preferences.shared.voiceOverAnnouncements else { return }
        DispatchQueue.main.async {
            NSAccessibility.post(
                element: NSApp.mainWindow ?? NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: text,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
    }
}
