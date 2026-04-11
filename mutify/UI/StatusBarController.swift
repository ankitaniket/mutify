import AppKit
import Combine

/// Menu bar item that mirrors mute state and exposes the menu.
///
/// Visibility, icon style, and "MUTED" label are all driven by `Preferences`.
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var cachedMenu: NSMenu?

    init() {
        // Show on launch only if the user wants the menu bar icon visible.
        if Preferences.shared.showMenuBarIcon {
            install()
        }

        // React to mute state changes.
        MicrophoneController.shared.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] muted in
                self?.applyIcon(muted: muted)
                self?.rebuildMenu(muted: muted)
            }
            .store(in: &cancellables)

        // React to active device changes (refresh menu).
        MicrophoneController.shared.$activeDeviceName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu(muted: MicrophoneController.shared.isMuted)
            }
            .store(in: &cancellables)

        // React to preference changes.
        Preferences.shared.$showMenuBarIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                if visible { self?.install() } else { self?.uninstall() }
            }
            .store(in: &cancellables)

        Preferences.shared.$iconStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyIcon(muted: MicrophoneController.shared.isMuted)
            }
            .store(in: &cancellables)

        Preferences.shared.$showMutedLabel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyIcon(muted: MicrophoneController.shared.isMuted)
            }
            .store(in: &cancellables)
    }

    // MARK: - Install / uninstall

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = []
        if let button = item.button {
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeft
        }
        statusItem = item
        rebuildMenu(muted: MicrophoneController.shared.isMuted)
        applyIcon(muted: MicrophoneController.shared.isMuted)
    }

    private func uninstall() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // MARK: - Icon

    private func applyIcon(muted: Bool) {
        guard let item = statusItem, let button = item.button else { return }
        let symbolName = muted ? "mic.slash.fill" : "mic.fill"
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let style = Preferences.shared.iconStyle

        switch style {
        case .template:
            if muted {
                let mutedRed = NSColor(calibratedRed: 0.78, green: 0.24, blue: 0.24, alpha: 1.0)
                let colorConfig = NSImage.SymbolConfiguration(paletteColors: [mutedRed])
                let merged = sizeConfig.applying(colorConfig)
                let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Muted")?
                    .withSymbolConfiguration(merged)
                image?.isTemplate = false
                button.image = image
            } else {
                let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Unmuted")?
                    .withSymbolConfiguration(sizeConfig)
                image?.isTemplate = true
                button.image = image
            }
        case .colorful:
            let color = muted
                ? NSColor(calibratedRed: 0.85, green: 0.20, blue: 0.20, alpha: 1.0)
                : NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.30, alpha: 1.0)
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [color])
            let merged = sizeConfig.applying(colorConfig)
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: muted ? "Muted" : "Unmuted")?
                .withSymbolConfiguration(merged)
            image?.isTemplate = false
            button.image = image
        case .monochrome:
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: muted ? "Muted" : "Unmuted")?
                .withSymbolConfiguration(sizeConfig)
            image?.isTemplate = true
            button.image = image
        }
        button.contentTintColor = nil

        // Optional "MUTED" label next to the icon.
        if Preferences.shared.showMutedLabel && muted {
            button.title = " MUTED"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor(calibratedRed: 0.85, green: 0.20, blue: 0.20, alpha: 1.0),
            ]
            button.attributedTitle = NSAttributedString(string: " MUTED", attributes: attrs)
        } else {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
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

        // Active device line + device picker submenu.
        if let name = MicrophoneController.shared.activeDeviceName {
            let active = NSMenuItem(title: "Active: \(name)", action: nil, keyEquivalent: "")
            active.isEnabled = false
            menu.addItem(active)
        }
        let deviceItem = NSMenuItem(title: "Input Device", action: nil, keyEquivalent: "")
        deviceItem.submenu = buildDeviceSubmenu()
        menu.addItem(deviceItem)

        menu.addItem(.separator())

        let showItem = NSMenuItem(title: "Show Mutify Window", action: #selector(showMain), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(UpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = UpdaterController.shared
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mutify", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = nil
        cachedMenu = menu
    }

    private func buildDeviceSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let pinned = Preferences.shared.pinnedDeviceUID

        let follow = NSMenuItem(
            title: "Follow System Default",
            action: #selector(pickFollowDefault),
            keyEquivalent: ""
        )
        follow.target = self
        follow.state = (pinned == nil) ? .on : .off
        submenu.addItem(follow)

        submenu.addItem(.separator())

        for device in AudioDevices.listInputs() {
            let item = NSMenuItem(
                title: device.name + (device.supportsMute ? "" : "  (no mute)"),
                action: #selector(pickDevice(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = device.uid
            item.state = (pinned == device.uid) ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    // MARK: - Actions

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        // Both left- and right-click open the menu. The Main window is reachable
        // from the "Show Mutify Window" menu item.
        showMenu()
    }

    private func showMenu() {
        guard let menu = cachedMenu, let item = statusItem else { return }
        item.menu = menu
        item.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
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
        SettingsWindowController.shared.show()
    }

    @objc private func pickFollowDefault() {
        Preferences.shared.pinnedDeviceUID = nil
    }

    @objc private func pickDevice(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        Preferences.shared.pinnedDeviceUID = uid
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
