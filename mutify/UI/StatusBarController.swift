import AppKit
import Combine

/// Always-present menu bar item that mirrors mute state and exposes the menu.
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = []  // Always visible; not user-removable on click.

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
        }

        rebuildMenu(muted: false)
        applyIcon(muted: false)

        MicrophoneController.shared.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] muted in
                self?.applyIcon(muted: muted)
                self?.rebuildMenu(muted: muted)
            }
            .store(in: &cancellables)
    }

    // MARK: - Icon

    private func applyIcon(muted: Bool) {
        guard let button = statusItem.button else { return }
        let symbolName = muted ? "mic.slash.fill" : "mic.fill"
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)

        if muted {
            // Render the glyph in red. We must disable template mode so the color
            // survives — template images on NSStatusItem buttons are always
            // re-tinted with the system menu-bar foreground color.
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            let merged = sizeConfig.applying(colorConfig)
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Muted")?
                .withSymbolConfiguration(merged)
            image?.isTemplate = false
            button.image = image
            button.contentTintColor = nil
        } else {
            // Live: use a template image so it adapts to light/dark menu bars.
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Unmuted")?
                .withSymbolConfiguration(sizeConfig)
            image?.isTemplate = true
            button.image = image
            button.contentTintColor = nil
        }

        button.toolTip = muted ? "Mutify — Microphone muted" : "Mutify — Microphone live"
    }

    // MARK: - Menu

    private func rebuildMenu(muted: Bool) {
        let menu = NSMenu()

        let toggleTitle = muted ? "Unmute Microphone" : "Mute Microphone"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(menuToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let showItem = NSMenuItem(title: "Show Mutify Window", action: #selector(showMain), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mutify", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = nil  // We attach on right-click only; left-click handled below.
        cachedMenu = menu
    }

    private var cachedMenu: NSMenu?

    // MARK: - Actions

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            MainWindowController.shared.show()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            MainWindowController.shared.show()
        }
    }

    private func showMenu() {
        guard let menu = cachedMenu else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Detach so the next left-click toggles instead of opening the menu.
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    private func performToggle() {
        let nowMuted = MicrophoneController.shared.toggle()
        HUDController.shared.show(muted: nowMuted)
    }

    @objc private func menuToggle() {
        performToggle()
    }

    @objc private func showMain() {
        MainWindowController.shared.show()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
