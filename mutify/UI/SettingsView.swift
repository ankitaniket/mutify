import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle mute:", name: .toggleMute)
            } header: {
                Text("Global Shortcut")
            } footer: {
                Text("Press this combo from anywhere — even while screen sharing — to toggle your microphone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch Mutify at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLogin.isEnabled = newValue
                        // Re-read in case the system rejected the change.
                        DispatchQueue.main.async {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Quit Mutify") { NSApp.terminate(nil) }
                        .keyboardShortcut("q", modifiers: [.command])
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 320)
        .navigationTitle("Mutify Settings")
    }
}

#Preview {
    SettingsView()
}
