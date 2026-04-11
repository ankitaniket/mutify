import Foundation
import AppKit
import Combine

/// Central observable store for user-facing preferences. Backed by `UserDefaults`.
///
/// Every property exposed here is `@Published`, so SwiftUI views and Combine
/// subscribers can react to changes without having to listen on UserDefaults
/// notifications directly.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    // MARK: - Visibility

    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    @Published var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Keys.showDockIcon) }
    }

    // MARK: - Icon style

    enum IconStyle: String, CaseIterable, Identifiable {
        case template   // Adapts to light/dark menu bar (current behavior)
        case colorful   // Green when live, red when muted
        case monochrome // Always white-on-dark / black-on-light, no template tinting
        var id: String { rawValue }
        var label: String {
            switch self {
            case .template: return "Adaptive"
            case .colorful: return "Colorful"
            case .monochrome: return "Monochrome"
            }
        }
    }

    @Published var iconStyle: IconStyle {
        didSet { defaults.set(iconStyle.rawValue, forKey: Keys.iconStyle) }
    }

    @Published var showMutedLabel: Bool {
        didSet { defaults.set(showMutedLabel, forKey: Keys.showMutedLabel) }
    }

    // MARK: - Device pinning

    /// nil means "follow system default input device".
    @Published var pinnedDeviceUID: String? {
        didSet { defaults.set(pinnedDeviceUID, forKey: Keys.pinnedDeviceUID) }
    }

    // MARK: - Focus mode integration

    @Published var muteOnFocus: Bool {
        didSet { defaults.set(muteOnFocus, forKey: Keys.muteOnFocus) }
    }

    // MARK: - Accessibility

    @Published var voiceOverAnnouncements: Bool {
        didSet { defaults.set(voiceOverAnnouncements, forKey: Keys.voiceOverAnnouncements) }
    }

    // MARK: - Stats (read/write through MuteStats)

    private init() {
        defaults.register(defaults: [
            Keys.showMenuBarIcon: true,
            Keys.showDockIcon: false,
            Keys.iconStyle: IconStyle.template.rawValue,
            Keys.showMutedLabel: false,
            Keys.muteOnFocus: false,
            Keys.voiceOverAnnouncements: false,
        ])

        showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        showDockIcon = defaults.bool(forKey: Keys.showDockIcon)
        iconStyle = IconStyle(rawValue: defaults.string(forKey: Keys.iconStyle) ?? "") ?? .template
        showMutedLabel = defaults.bool(forKey: Keys.showMutedLabel)
        pinnedDeviceUID = defaults.string(forKey: Keys.pinnedDeviceUID)
        muteOnFocus = defaults.bool(forKey: Keys.muteOnFocus)
        voiceOverAnnouncements = defaults.bool(forKey: Keys.voiceOverAnnouncements)
    }

    private enum Keys {
        static let showMenuBarIcon = "pref.showMenuBarIcon"
        static let showDockIcon = "pref.showDockIcon"
        static let iconStyle = "pref.iconStyle"
        static let showMutedLabel = "pref.showMutedLabel"
        static let pinnedDeviceUID = "pref.pinnedDeviceUID"
        static let muteOnFocus = "pref.muteOnFocus"
        static let voiceOverAnnouncements = "pref.voiceOverAnnouncements"
    }
}
