import Foundation
import CoreAudio
import Combine

/// Controls the active input device's mute state via CoreAudio.
///
/// Setting `kAudioDevicePropertyMute` on the input scope mutes the device at the
/// OS level, so every running app (Zoom, Meet, Teams, browsers, etc.) instantly
/// sees silence. No per-app integration required.
///
/// The active device is either the system default input (when the user hasn't
/// pinned anything) or the device whose UID matches `Preferences.pinnedDeviceUID`.
/// Per-device mute state is remembered in `UserDefaults` so re-plugging a USB
/// mic restores the last intended state.
final class MicrophoneController: ObservableObject {
    static let shared = MicrophoneController()

    @Published private(set) var isMuted: Bool = false
    @Published private(set) var hasInputDevice: Bool = false
    @Published private(set) var activeDeviceUID: String?
    @Published private(set) var activeDeviceName: String?

    private var deviceID: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
    private var muteListener: AudioObjectPropertyListenerBlock?
    private var prefsCancellable: AnyCancellable?

    private let perDeviceMuteKey = "mic.perDeviceMute"

    private init() {
        installDefaultDeviceListener()
        rebindActiveDevice()

        // React to user pinning a different device.
        prefsCancellable = Preferences.shared.$pinnedDeviceUID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebindActiveDevice() }
    }

    // MARK: - Public API

    @discardableResult
    func toggle() -> Bool {
        let next = !isMuted
        setMuted(next)
        return next
    }

    func setMuted(_ value: Bool) {
        guard hasInputDevice else { return }
        guard writeMute(deviceID, muted: value) else { return }
        rememberMuteState(value, for: activeDeviceUID)
        DispatchQueue.main.async { self.isMuted = value }
    }

    /// Force a re-resolve of the active device. Useful when the user changes
    /// the pinned-device preference, or after device hot-plug events.
    func refreshActiveDevice() {
        rebindActiveDevice()
    }

    // MARK: - Per-device mute memory

    private func rememberMuteState(_ muted: Bool, for uid: String?) {
        guard let uid else { return }
        var dict = UserDefaults.standard.dictionary(forKey: perDeviceMuteKey) as? [String: Bool] ?? [:]
        dict[uid] = muted
        UserDefaults.standard.set(dict, forKey: perDeviceMuteKey)
    }

    private func recalledMuteState(for uid: String?) -> Bool? {
        guard let uid else { return nil }
        let dict = UserDefaults.standard.dictionary(forKey: perDeviceMuteKey) as? [String: Bool] ?? [:]
        return dict[uid]
    }

    // MARK: - Default-device tracking

    private func installDefaultDeviceListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Only react if the user hasn't pinned a specific device.
            guard let self, Preferences.shared.pinnedDeviceUID == nil else { return }
            self.rebindActiveDevice()
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
    }

    private func rebindActiveDevice() {
        // Tear down listener bound to the previous device.
        if deviceID != AudioDeviceID(kAudioObjectUnknown), let block = muteListener {
            var addr = muteAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &addr, DispatchQueue.main, block)
        }
        muteListener = nil

        let resolved = resolveActiveDeviceID()
        guard let newID = resolved else {
            DispatchQueue.main.async {
                self.hasInputDevice = false
                self.deviceID = AudioDeviceID(kAudioObjectUnknown)
                self.activeDeviceUID = nil
                self.activeDeviceName = nil
            }
            return
        }

        deviceID = newID
        let uid = AudioDevices.uid(for: newID)
        let name = AudioDevices.listInputs().first(where: { $0.id == newID })?.name

        // Restore last-known mute state for this device, if any. Otherwise read
        // the live property.
        let liveMuted = readMute(newID)
        let restored = recalledMuteState(for: uid) ?? liveMuted
        if restored != liveMuted {
            _ = writeMute(newID, muted: restored)
        }

        DispatchQueue.main.async {
            self.hasInputDevice = true
            self.activeDeviceUID = uid
            self.activeDeviceName = name
            self.isMuted = restored
        }

        // Bind a fresh listener so external mute changes update our state.
        var addr = muteAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            let m = self.readMute(self.deviceID)
            DispatchQueue.main.async { self.isMuted = m }
        }
        muteListener = block
        AudioObjectAddPropertyListenerBlock(newID, &addr, DispatchQueue.main, block)
    }

    private func resolveActiveDeviceID() -> AudioDeviceID? {
        if let pinned = Preferences.shared.pinnedDeviceUID,
           let id = AudioDevices.deviceID(forUID: pinned) {
            return id
        }
        return readDefaultInputDevice()
    }

    // MARK: - CoreAudio plumbing

    private var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func readDefaultInputDevice() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &dev
        )
        guard status == noErr, dev != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        return dev
    }

    private func readMute(_ id: AudioDeviceID) -> Bool {
        var addr = muteAddress
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &muted)
        return status == noErr && muted == 1
    }

    @discardableResult
    private func writeMute(_ id: AudioDeviceID, muted: Bool) -> Bool {
        var addr = muteAddress
        guard AudioObjectHasProperty(id, &addr) else {
            NSLog("Mutify: device \(id) does not support kAudioDevicePropertyMute")
            return false
        }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(id, &addr, &settable)
        guard settable.boolValue else {
            NSLog("Mutify: mute property not settable on device \(id)")
            return false
        }
        var v: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(id, &addr, 0, nil, size, &v)
        if status != noErr {
            NSLog("Mutify: AudioObjectSetPropertyData failed: \(status)")
            return false
        }
        return true
    }
}
