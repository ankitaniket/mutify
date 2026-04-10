import SwiftUI
import KeyboardShortcuts

/// The simple main window — shows current mute state, the active shortcut,
/// and the launch-at-login toggle.
struct MainView: View {
    @ObservedObject private var mic = MicrophoneController.shared
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            // Hero status block — click anywhere here to toggle mute.
            Button(action: toggleMute) {
                VStack(spacing: 12) {
                    Image(systemName: mic.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(mic.isMuted ? Color.red : Color.green)
                        .symbolRenderingMode(.hierarchical)

                    Text(mic.isMuted ? "Muted" : "Live")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(mic.isMuted ? "Click to unmute" : "Click to mute")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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

                HStack(spacing: 12) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { newValue in
                            LaunchAtLogin.isEnabled = newValue
                            DispatchQueue.main.async {
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                        }
                    Button(action: openGitHub) {
                        Image("GitHubMark")
                            .resizable()
                            .renderingMode(.template)
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("View source on GitHub")
                }
            }
            .padding(20)
        }
        .frame(width: 360)
        .fixedSize(horizontal: true, vertical: true)
    }

    private func toggleMute() {
        let nowMuted = MicrophoneController.shared.toggle()
        HUDController.shared.show(muted: nowMuted)
    }

    private func openGitHub() {
        if let url = URL(string: "https://github.com/ankitaniket/mutify") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    MainView()
}
