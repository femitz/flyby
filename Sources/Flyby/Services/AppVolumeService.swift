import AppKit
import AudioToolbox
import Combine
import CoreAudio
import Darwin
import Foundation

/// An application that currently has audio sessions open.
struct AudioApp: Identifiable {
    let id: String          // bundle identifier of the owning app
    let name: String
    let icon: NSImage?
    let processObjectIDs: [AudioObjectID]
    let isPlaying: Bool
}

/// Per-app volume control built on Core Audio process taps (macOS 14.2+).
///
/// For an app whose volume is not 100%, a private tap mutes the app's own output and
/// feeds its audio to an aggregate device, whose IOProc plays it on the default output
/// device scaled by the chosen gain. At 100% the tap is removed, so audio is untouched.
final class AppVolumeService: ObservableObject {
    static let shared = AppVolumeService()

    static let maxVolume = 1.5

    @Published private(set) var apps: [AudioApp] = []
    @Published private(set) var volumes: [String: Double] = [:]
    @Published private(set) var errorMessage: String?

    var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var taps: [String: Any] = [:]   // AppTap (macOS 14.2+), type-erased
    private var outputListener: AudioObjectPropertyListenerBlock?

    private init() {
        AppSettings.shared.$monitorAppVolume
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                enabled ? self?.start() : self?.stop()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    private func start() {
        guard isSupported, timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        listenForOutputDeviceChanges()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        removeAllTaps()
        volumes.removeAll()
        apps = []
        errorMessage = nil
        stopListeningForOutputDeviceChanges()
    }

    // MARK: - Public API

    func volume(for appID: String) -> Double {
        volumes[appID] ?? 1.0
    }

    func setVolume(_ value: Double, for appID: String) {
        guard #available(macOS 14.2, *) else { return }
        let clamped = min(max(value, 0), Self.maxVolume)
        volumes[appID] = clamped

        if abs(clamped - 1.0) < 0.01 {
            // Back to 100%: remove the tap so the app plays normally again.
            (taps[appID] as? AppTap)?.stop()
            taps[appID] = nil
            volumes[appID] = nil
            return
        }

        if let tap = taps[appID] as? AppTap {
            tap.gain = Float(clamped)
        } else if let app = apps.first(where: { $0.id == appID }) {
            createTap(for: app, gain: Float(clamped))
        }
    }

    // MARK: - Tap management

    @available(macOS 14.2, *)
    private func createTap(for app: AudioApp, gain: Float) {
        do {
            taps[app.id] = try AppTap(processObjectIDs: app.processObjectIDs, gain: gain)
            errorMessage = nil
        } catch {
            volumes[app.id] = nil
            errorMessage = "Could not control \(app.name): \(error.localizedDescription) "
                + "Allow Flyby under System Settings → Privacy & Security → Screen & System Audio Recording."
        }
    }

    private func removeAllTaps() {
        if #available(macOS 14.2, *) {
            for case let tap as AppTap in taps.values { tap.stop() }
        }
        taps.removeAll()
    }

    /// Rebuilds every active tap, e.g. after the default output device changed.
    private func rebuildTaps() {
        guard #available(macOS 14.2, *) else { return }
        let active = taps.keys.compactMap { id in apps.first { $0.id == id }.map { ($0, volume(for: id)) } }
        removeAllTaps()
        for (app, gain) in active { createTap(for: app, gain: Float(gain)) }
    }

    // MARK: - Discovery

    private func refresh() {
        let discovered = Self.discoverApps()
        var merged = discovered

        // Keep adjusted apps visible (and their sliders reachable) even if they went quiet.
        let discoveredIDs = Set(discovered.map(\.id))
        merged += apps.filter { volumes[$0.id] != nil && !discoveredIDs.contains($0.id) }
        apps = merged.sorted { ($0.isPlaying ? 0 : 1, $0.name.lowercased()) < ($1.isPlaying ? 0 : 1, $1.name.lowercased()) }

        // New helper processes (e.g. a new browser tab) must be added to the tap.
        if #available(macOS 14.2, *) {
            for app in apps {
                guard let tap = taps[app.id] as? AppTap,
                      Set(tap.processObjectIDs) != Set(app.processObjectIDs) else { continue }
                let gain = Float(volume(for: app.id))
                tap.stop()
                taps[app.id] = nil
                createTap(for: app, gain: gain)
            }
        }
    }

    private static func discoverApps() -> [AudioApp] {
        var grouped: [String: (app: NSRunningApplication, objects: [AudioObjectID], playing: Bool)] = [:]

        for object in processObjects() {
            guard let pid = pid(of: object),
                  pid != ProcessInfo.processInfo.processIdentifier,
                  let owner = owningApp(of: pid),
                  let bundleID = owner.bundleIdentifier else { continue }

            var entry = grouped[bundleID] ?? (owner, [], false)
            entry.objects.append(object)
            entry.playing = entry.playing || isRunningOutput(object)
            grouped[bundleID] = entry
        }

        return grouped.map { bundleID, entry in
            AudioApp(
                id: bundleID,
                name: entry.app.localizedName ?? bundleID,
                icon: entry.app.icon,
                processObjectIDs: entry.objects,
                isPlaying: entry.playing
            )
        }
    }

    /// Walks up the process tree (browser helpers → browser) to the regular GUI app.
    private static func owningApp(of pid: pid_t) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<8 {
            if let app = NSRunningApplication(processIdentifier: current), app.activationPolicy == .regular {
                return app
            }
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(current, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
            let parent = pid_t(info.pbi_ppid)
            if parent <= 1 || parent == current { return nil }
            current = parent
        }
        return nil
    }

    private static func processObjects() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }
        return objects
    }

    private static func pid(of object: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func isRunningOutput(_ object: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    // MARK: - Output device changes

    private func listenForOutputDeviceChanges() {
        guard outputListener == nil else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.rebuildTaps()
        }
        outputListener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener)
    }

    private func stopListeningForOutputDeviceChanges() {
        guard let listener = outputListener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener)
        outputListener = nil
    }
}

// MARK: - Tap

@available(macOS 14.2, *)
private final class AppTap {
    struct TapError: LocalizedError {
        let operation: String
        let status: OSStatus
        var errorDescription: String? { "\(operation) failed (error \(status))." }
    }

    let processObjectIDs: [AudioObjectID]

    /// Linear gain applied by the IOProc. Written from the main thread and read from the
    /// audio thread; an aligned Float load/store is sufficient here.
    var gain: Float {
        get { gainStorage.pointee }
        set { gainStorage.pointee = newValue }
    }

    private let gainStorage = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(processObjectIDs: [AudioObjectID], gain: Float) throws {
        self.processObjectIDs = processObjectIDs
        gainStorage.initialize(to: gain)

        do {
            try setUp()
        } catch {
            stop()
            throw error
        }
    }

    private func setUp() throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        description.uuid = UUID()
        description.muteBehavior = .mutedWhenTapped   // silence the original output
        description.isPrivate = true

        var status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw TapError(operation: "Creating the audio tap", status: status) }

        let outputUID = try Self.defaultOutputDeviceUID()
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Flyby App Volume",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString
            ]]
        ]

        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard status == noErr else { throw TapError(operation: "Creating the aggregate device", status: status) }

        let gainPointer = gainStorage
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { _, inputData, _, outputData, _ in
            let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            let output = UnsafeMutableAudioBufferListPointer(outputData)
            let gain = gainPointer.pointee

            for index in 0..<output.count {
                guard let destination = output[index].mData else { continue }
                guard index < input.count,
                      let source = input[index].mData,
                      input[index].mDataByteSize == output[index].mDataByteSize else {
                    memset(destination, 0, Int(output[index].mDataByteSize))
                    continue
                }
                let samples = Int(output[index].mDataByteSize) / MemoryLayout<Float>.size
                let src = source.assumingMemoryBound(to: Float.self)
                let dst = destination.assumingMemoryBound(to: Float.self)
                for i in 0..<samples { dst[i] = src[i] * gain }
            }
        }
        guard status == noErr else { throw TapError(operation: "Creating the audio callback", status: status) }

        status = AudioDeviceStart(aggregateID, ioProcID)
        guard status == noErr else { throw TapError(operation: "Starting audio", status: status) }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    deinit {
        stop()
        gainStorage.deallocate()
    }

    private static func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr else { throw TapError(operation: "Finding the output device", status: status) }

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid)
        guard status == noErr, let uid else { throw TapError(operation: "Reading the output device", status: status) }
        return uid.takeRetainedValue() as String
    }
}
