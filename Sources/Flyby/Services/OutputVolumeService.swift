import AudioToolbox
import CoreAudio
import Foundation

/// Master volume / mute of the default output device (the mixer's "Saída geral" row).
final class OutputVolumeService: ObservableObject {
    static let shared = OutputVolumeService()

    /// nil until a device is read, or when it has no name; the panel then shows a generic one.
    @Published private(set) var deviceName: String?
    @Published private(set) var volume: Double = 0
    @Published private(set) var isMuted = false
    @Published private(set) var isAvailable = false

    private var timer: Timer?
    private var volumeBeforeMute: Double?

    private init() {}

    /// Polls while the panel is visible so the slider follows the keyboard volume keys.
    func startPolling() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let device = Self.defaultOutputDevice() else {
            isAvailable = false
            return
        }
        deviceName = Self.name(of: device)

        guard let current = Self.readVolume(device) else {
            isAvailable = false
            return
        }
        isAvailable = true
        volume = Double(current)
        isMuted = Self.hasMute(device) ? Self.readMute(device) : volumeBeforeMute != nil
    }

    func setVolume(_ value: Double) {
        guard let device = Self.defaultOutputDevice() else { return }
        let clamped = min(max(value, 0), 1)
        Self.writeVolume(device, Float32(clamped))
        volume = clamped
        if clamped > 0, isMuted { setMuted(false) }
    }

    func setMuted(_ muted: Bool) {
        guard let device = Self.defaultOutputDevice() else { return }
        if Self.hasMute(device) {
            Self.writeMute(device, muted)
        } else if muted {
            // Device without a mute switch: emulate it with volume 0.
            volumeBeforeMute = volume
            Self.writeVolume(device, 0)
            volume = 0
        } else if let previous = volumeBeforeMute {
            volumeBeforeMute = nil
            Self.writeVolume(device, Float32(previous))
            volume = previous
        }
        isMuted = muted
    }

    // MARK: - Core Audio

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static func name(of device: AudioObjectID) -> String? {
        var address = address(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    private static func readVolume(_ device: AudioObjectID) -> Float32? {
        var address = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func writeVolume(_ device: AudioObjectID, _ value: Float32) {
        var address = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var value = value
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    private static func hasMute(_ device: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyMute)
        return AudioObjectHasProperty(device, &address)
    }

    private static func readMute(_ device: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyMute)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr && value != 0
    }

    private static func writeMute(_ device: AudioObjectID, _ muted: Bool) {
        var address = address(kAudioDevicePropertyMute)
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }
}
