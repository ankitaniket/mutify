import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var mic = MicrophoneController.shared
    @ObservedObject private var stats = MuteStats.shared
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var devices: [AudioDevices.InputDevice] = []

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "command") }
            audioTab
                .tabItem { Label("Audio", systemImage: "mic") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            advancedTab
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 560, height: 460)
        .navigationTitle("Mutify Settings")
        .onAppear { devices = AudioDevices.listInputs() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch Mutify at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLogin.isEnabled = newValue
                        DispatchQueue.main.async {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                Toggle("Show menu bar icon", isOn: $prefs.showMenuBarIcon)
                Toggle("Show in Dock", isOn: $prefs.showDockIcon)
            } header: { Text("Visibility") }

            Section {
                HStack {
                    Text("Today")
                    Spacer()
                    Text("\(stats.todayMuteCount) toggles · \(stats.formattedMutedDuration) muted")
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Statistics") }

            Section {
                HStack {
                    Spacer()
                    Button("Quit Mutify") { NSApp.terminate(nil) }
                        .keyboardShortcut("q", modifiers: [.command])
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
                KeyboardShortcuts.Recorder("Force mute:", name: .forceMute)
                KeyboardShortcuts.Recorder("Force unmute:", name: .forceUnmute)
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text("Force-mute and force-unmute are optional. They eliminate any ambiguity about your current state when you don't want a toggle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Audio

    private var audioTab: some View {
        Form {
            Section {
                Picker("Input device", selection: Binding(
                    get: { prefs.pinnedDeviceUID ?? "" },
                    set: { newValue in
                        prefs.pinnedDeviceUID = newValue.isEmpty ? nil : newValue
                    }
                )) {
                    Text("Follow system default").tag("")
                    ForEach(devices, id: \.uid) { d in
                        Text(d.name + (d.supportsMute ? "" : "  (no mute support)"))
                            .tag(d.uid)
                    }
                }
                if let name = mic.activeDeviceName {
                    HStack {
                        Text("Active")
                        Spacer()
                        Text(name).foregroundStyle(.secondary)
                    }
                }
                Button("Refresh device list") { devices = AudioDevices.listInputs() }
            } header: { Text("Microphone") }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Icon style", selection: $prefs.iconStyle) {
                    ForEach(Preferences.IconStyle.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show \"MUTED\" label next to icon", isOn: $prefs.showMutedLabel)
            } header: { Text("Menu Bar") }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section {
                Toggle("Mute when Focus / Do Not Disturb is on", isOn: $prefs.muteOnFocus)
            } header: { Text("Focus") }

            Section {
                Toggle("Announce mute changes via VoiceOver", isOn: $prefs.voiceOverAnnouncements)
            } header: { Text("Accessibility") }

            Section {
                Button("Check for Updates…") {
                    UpdaterController.shared.checkForUpdates(nil)
                }
            } header: { Text("Updates") }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
