import Foundation
import CoreAudio

/// Lightweight CoreAudio helpers for enumerating input devices and looking
/// them up by stable UID. The UID survives reboots and re-plugging, while
/// `AudioDeviceID` does not — so we persist UIDs in `Preferences`.
enum AudioDevices {

    struct InputDevice: Identifiable, Hashable {
        let id: AudioDeviceID
        let uid: String
        let name: String
        let supportsMute: Bool
    }

    /// Enumerate every device that has at least one input stream.
    static func listInputs() -> [InputDevice] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids
        ) == noErr else { return [] }

        return ids.compactMap { id in
            guard hasInputStream(id) else { return nil }
            guard let uid = stringProperty(id, selector: kAudioDevicePropertyDeviceUID) else { return nil }
            let name = stringProperty(id, selector: kAudioDevicePropertyDeviceNameCFString) ?? "Unknown"
            return InputDevice(
                id: id,
                uid: uid,
                name: name,
                supportsMute: deviceSupportsMute(id)
            )
        }
    }

    /// Look up a live `AudioDeviceID` for a stored UID. Returns nil when the
    /// device has been unplugged or removed.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        // Linear scan over current input devices is simpler than the
        // `kAudioHardwarePropertyDeviceForUID` translation API and avoids the
        // unsafe pointer dance. There are typically <10 devices.
        listInputs().first(where: { $0.uid == uid })?.id
    }

    static func uid(for deviceID: AudioDeviceID) -> String? {
        stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
    }

    // MARK: - Helpers

    private static func hasInputStream(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, bufferList) == noErr else {
            return false
        }
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        for buf in abl where buf.mNumberChannels > 0 { return true }
        return false
    }

    private static func deviceSupportsMute(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(id, &addr)
    }

    private static func stringProperty(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfString: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &cfString) { ptr in
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr else { return nil }
        return cfString as String
    }
}
