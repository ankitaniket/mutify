import Foundation
import CoreAudio
import Combine

/// Controls the system default input device's mute state via CoreAudio.
///
/// Setting `kAudioDevicePropertyMute` on the input scope mutes the device at the
/// OS level, which means every running app (Zoom, Meet, Teams, browsers, etc.)
/// instantly sees silence. No per-app integration required.
final class MicrophoneController: ObservableObject {
    static let shared = MicrophoneController()

    @Published private(set) var isMuted: Bool = false
    @Published private(set) var hasInputDevice: Bool = false

    private var deviceID: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
    private var muteListener: AudioObjectPropertyListenerBlock?

    private init() {
        installDefaultDeviceListener()
        rebindToDefaultDevice()
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
        DispatchQueue.main.async { self.isMuted = value }
    }

    // MARK: - Default-device tracking

    private func installDefaultDeviceListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.rebindToDefaultDevice()
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
    }

    private func rebindToDefaultDevice() {
        // Tear down listener bound to old device.
        if deviceID != AudioDeviceID(kAudioObjectUnknown), let block = muteListener {
            var addr = muteAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &addr, DispatchQueue.main, block)
        }
        muteListener = nil

        guard let newID = readDefaultInputDevice() else {
            DispatchQueue.main.async {
                self.hasInputDevice = false
                self.deviceID = AudioDeviceID(kAudioObjectUnknown)
            }
            return
        }

        deviceID = newID
        let muted = readMute(newID)
        DispatchQueue.main.async {
            self.hasInputDevice = true
            self.isMuted = muted
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
