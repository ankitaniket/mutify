import AppKit
import SwiftUI

/// Borderless, click-through floating panel used as a toast HUD.
///
/// Implemented as an `NSPanel` with the `.nonactivatingPanel` style mask — the
/// same approach the system volume / brightness HUDs use. That combo guarantees:
///   • The window floats above every other app, including full-screen apps.
///   • It does NOT steal focus from whatever the user is typing into.
///   • It joins every Space (so it appears regardless of the active Space).
///
/// `sharingType = .none` keeps it out of screen recordings / Zoom screen-shares,
/// so meeting participants never see the "Muted" / "Unmuted" toast.
final class HUDWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        // .popUpMenu (101) sits above .statusBar (25) and floats over browsers,
        // terminals, full-screen apps, etc.
        level = .popUpMenu
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
            .transient,
        ]
        sharingType = .none
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SwiftUI body of the toast.
struct HUDContentView: View {
    let muted: Bool

    var body: some View {
        Text(muted ? "Muted" : "Unmuted")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

/// Persistent "label" HUD used for the opt-in speaking-while-muted indicator.
/// Smaller, warning-tinted, sticks around until the controller dismisses it.
struct HUDLabelView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .foregroundStyle(.white)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color(red: 0.78, green: 0.24, blue: 0.24).opacity(0.85)
            }
            .clipShape(Capsule(style: .continuous))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}

/// Bridge to NSVisualEffectView for the blurred toast background.
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
