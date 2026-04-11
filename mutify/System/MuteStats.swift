import Foundation
import Combine

/// Tracks lightweight local mute statistics for the user-facing "today" view.
/// Pure local — no telemetry leaves the machine.
final class MuteStats: ObservableObject {
    static let shared = MuteStats()

    @Published private(set) var todayMuteCount: Int = 0
    @Published private(set) var todayMutedSeconds: TimeInterval = 0

    private let defaults = UserDefaults.standard
    private var muteStartedAt: Date?
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let dayStamp = "stats.dayStamp"
        static let muteCount = "stats.todayMuteCount"
        static let mutedSeconds = "stats.todayMutedSeconds"
    }

    private init() {
        rolloverIfNeeded()
        todayMuteCount = defaults.integer(forKey: Keys.muteCount)
        todayMutedSeconds = defaults.double(forKey: Keys.mutedSeconds)

        // Subscribe to mute changes and tally durations.
        MicrophoneController.shared.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] muted in
                self?.handleMuteChange(muted)
            }
            .store(in: &cancellables)
    }

    private func handleMuteChange(_ muted: Bool) {
        rolloverIfNeeded()
        if muted {
            muteStartedAt = Date()
            todayMuteCount += 1
            defaults.set(todayMuteCount, forKey: Keys.muteCount)
        } else if let started = muteStartedAt {
            let dur = Date().timeIntervalSince(started)
            todayMutedSeconds += dur
            defaults.set(todayMutedSeconds, forKey: Keys.mutedSeconds)
            muteStartedAt = nil
        }
    }

    private func rolloverIfNeeded() {
        let today = Self.dayStamp(for: Date())
        let stored = defaults.string(forKey: Keys.dayStamp)
        if stored != today {
            defaults.set(today, forKey: Keys.dayStamp)
            defaults.set(0, forKey: Keys.muteCount)
            defaults.set(0.0, forKey: Keys.mutedSeconds)
            todayMuteCount = 0
            todayMutedSeconds = 0
        }
    }

    private static func dayStamp(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Human-readable formatted muted-duration ("1h 14m" / "32s").
    var formattedMutedDuration: String {
        let total = Int(todayMutedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
