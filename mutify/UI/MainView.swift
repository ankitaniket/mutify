import SwiftUI
import KeyboardShortcuts

/// The simple main window — shows current mute state, the active shortcut,
/// launch-at-login toggle, and a Quit button.
struct MainView: View {
    @ObservedObject private var mic = MicrophoneController.shared
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            // Hero status block
            VStack(spacing: 12) {
                Image(systemName: mic.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(mic.isMuted ? Color.red : Color.green)
                    .symbolRenderingMode(.hierarchical)

                Text(mic.isMuted ? "Muted" : "Live")
                    .font(.system(size: 22, weight: .bold))

                Text(mic.isMuted ? "Your microphone is currently muted." : "Your microphone is active.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                LinearGradient(
                    colors: [
                        Color(.controlBackgroundColor),
                        Color(.windowBackgroundColor),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider()

            // Controls
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "command")
                        .foregroundStyle(.secondary)
                    Text("Toggle shortcut")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleMute)
                }

                Toggle(isOn: $launchAtLogin) {
                    HStack {
                        Image(systemName: "power")
                            .foregroundStyle(.secondary)
                        Text("Launch at login")
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.isEnabled = newValue
                    DispatchQueue.main.async {
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            }
            .padding(20)

            Divider()

            // Action row
            HStack {
                Button {
                    let nowMuted = MicrophoneController.shared.toggle()
                    HUDController.shared.show(muted: nowMuted)
                } label: {
                    Label(mic.isMuted ? "Unmute" : "Mute", systemImage: mic.isMuted ? "mic.fill" : "mic.slash.fill")
                        .frame(minWidth: 90)
                }
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("Quit Mutify") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 360)
        .fixedSize(horizontal: true, vertical: true)
    }
}

#Preview {
    MainView()
}
