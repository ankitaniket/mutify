import SwiftUI
import KeyboardShortcuts

/// Settings window content. Uses a custom segmented header instead of SwiftUI's
/// TabView so we can give the chrome a uniform window-color background — the
/// native TabView paints its own slightly-tinted content area which leaves a
/// visible seam line below the tab strip.
struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var mic = MicrophoneController.shared
    @ObservedObject private var stats = MuteStats.shared
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var devices: [AudioDevices.InputDevice] = []
    @State private var selection: Tab = .general

    enum Tab: String, CaseIterable, Identifiable {
        case general, shortcuts, audio, appearance, advanced
        var id: String { rawValue }
        var label: String {
            switch self {
            case .general: return "General"
            case .shortcuts: return "Shortcuts"
            case .audio: return "Audio"
            case .appearance: return "Appearance"
            case .advanced: return "Advanced"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "command"
            case .audio: return "mic"
            case .appearance: return "paintbrush"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView {
                Group {
                    switch selection {
                    case .general: generalTab
                    case .shortcuts: shortcutsTab
                    case .audio: audioTab
                    case .appearance: appearanceTab
                    case .advanced: advancedTab
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 560, height: 460)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { devices = AudioDevices.listInputs() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 16, weight: .regular))
                Text(tab.label)
                    .font(.system(size: 11))
            }
            .frame(minWidth: 70)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section helpers (uniform look across tabs)

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
    }

    @ViewBuilder
    private func row<Content: View>(_ label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 16)
            trailing()
        }
        .padding(.vertical, 6)
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Visibility")
                card {
                    row("Launch Mutify at login") {
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: launchAtLogin) { newValue in
                                LaunchAtLogin.isEnabled = newValue
                                DispatchQueue.main.async {
                                    launchAtLogin = LaunchAtLogin.isEnabled
                                }
                            }
                    }
                    Divider()
                    row("Show menu bar icon") {
                        Toggle("", isOn: $prefs.showMenuBarIcon)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    Divider()
                    row("Show in Dock") {
                        Toggle("", isOn: $prefs.showDockIcon)
                            .labelsHidden().toggleStyle(.switch)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Statistics")
                card {
                    row("Today") {
                        Text("\(stats.todayMuteCount) toggles · \(stats.formattedMutedDuration) muted")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Quit Mutify") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Global Shortcuts")
                card {
                    row("Toggle mute") { KeyboardShortcuts.Recorder(for: .toggleMute) }
                    Divider()
                    row("Force mute") { KeyboardShortcuts.Recorder(for: .forceMute) }
                    Divider()
                    row("Force unmute") { KeyboardShortcuts.Recorder(for: .forceUnmute) }
                }
                Text("Force-mute and force-unmute are optional. They eliminate any ambiguity about your current state when you don't want a toggle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Audio

    private var audioTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Microphone")
                card {
                    row("Input device") {
                        Picker("", selection: Binding(
                            get: { prefs.pinnedDeviceUID ?? "" },
                            set: { prefs.pinnedDeviceUID = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Follow system default").tag("")
                            ForEach(devices, id: \.uid) { d in
                                Text(d.name + (d.supportsMute ? "" : "  (no mute support)"))
                                    .tag(d.uid)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                    if let name = mic.activeDeviceName {
                        Divider()
                        row("Active") {
                            Text(name).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Refresh device list") { devices = AudioDevices.listInputs() }
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Menu Bar")
                card {
                    row("Icon style") {
                        Picker("", selection: $prefs.iconStyle) {
                            ForEach(Preferences.IconStyle.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }
                    Divider()
                    row("Show \"MUTED\" label next to icon") {
                        Toggle("", isOn: $prefs.showMutedLabel)
                            .labelsHidden().toggleStyle(.switch)
                    }
                }
            }
        }
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Focus")
                card {
                    row("Mute when Focus / Do Not Disturb is on") {
                        Toggle("", isOn: $prefs.muteOnFocus)
                            .labelsHidden().toggleStyle(.switch)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Accessibility")
                card {
                    row("Speak mute changes aloud") {
                        Toggle("", isOn: $prefs.voiceOverAnnouncements)
                            .labelsHidden().toggleStyle(.switch)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Updates")
                card {
                    row("Check for the latest version") {
                        Button("Check for Updates…") {
                            UpdaterController.shared.checkForUpdates(nil)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
