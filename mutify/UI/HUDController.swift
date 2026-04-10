import AppKit
import SwiftUI

/// Owns the singleton HUD window and animates it in/out at the bottom-right of
/// the active screen.
final class HUDController {
    static let shared = HUDController()

    private let window: HUDWindow
    private let host: NSHostingView<HUDContentView>
    private var dismissWorkItem: DispatchWorkItem?

    private let hudSize = NSSize(width: 140, height: 48)
    private let edgeMargin: CGFloat = 28

    private init() {
        let initial = NSRect(origin: .zero, size: hudSize)
        window = HUDWindow(contentRect: initial)
        host = NSHostingView(rootView: HUDContentView(muted: false))
        host.frame = initial
        window.contentView = host
        window.alphaValue = 0
    }

    /// Show "Muted" / "Unmuted" toast at the bottom-right of the active screen.
    func show(muted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.present(muted: muted)
        }
    }

    private func present(muted: Bool) {
        host.rootView = HUDContentView(muted: muted)
        repositionToActiveScreen()

        dismissWorkItem?.cancel()
        if !window.isVisible {
            window.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            window.animator().alphaValue = 1.0
        }

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            window.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            self?.window.orderOut(nil)
        }
    }

    private func repositionToActiveScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: frame.maxX - hudSize.width - edgeMargin,
            y: frame.minY + edgeMargin
        )
        window.setFrame(NSRect(origin: origin, size: hudSize), display: true)
    }
}
