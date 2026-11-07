import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import os

private let log = Logger(subsystem: "com.flyby.menubar", category: "scroll")

/// Reverses the scroll direction of the mouse, the trackpad, or both, independently.
///
/// macOS has a single "natural scrolling" switch for every device. This service sits
/// in front of it with a session event tap that flips the deltas of scroll-wheel events
/// coming from the chosen kind of device. Modifying events needs Accessibility access.
final class ScrollReverserService: ObservableObject {
    static let shared = ScrollReverserService()

    /// False while a reverse option is on but the user has not granted Accessibility yet.
    @Published private(set) var hasPermission = AXIsProcessTrusted()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var promptedForPermission = false

    // Read from the tap callback, which runs on the main run loop.
    fileprivate var reverseMouse = false
    fileprivate var reverseTrackpad = false

    private init() {
        let settings = AppSettings.shared
        settings.$reverseMouseScroll
            .combineLatest(settings.$reverseTrackpadScroll)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mouse, trackpad in
                self?.apply(mouse: mouse, trackpad: trackpad)
            }
            .store(in: &cancellables)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func stop() {
        removeTap()
        stopWaitingForPermission()
    }

    // MARK: - Lifecycle

    private func apply(mouse: Bool, trackpad: Bool) {
        reverseMouse = mouse
        reverseTrackpad = trackpad

        guard mouse || trackpad else {
            stop()
            hasPermission = AXIsProcessTrusted()
            return
        }
        if tap == nil { installTap() }
    }

    private func installTap() {
        log.notice("installTap trusted=\(AXIsProcessTrusted(), privacy: .public) mouse=\(self.reverseMouse, privacy: .public) trackpad=\(self.reverseTrackpad, privacy: .public)")
        guard AXIsProcessTrusted() else {
            hasPermission = false
            requestPermission()
            return
        }
        hasPermission = true
        stopWaitingForPermission()

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("event tap creation failed although trusted")
            // Trusted but the tap still failed (e.g. stale grant after an update): wait and retry.
            hasPermission = false
            waitForPermission()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        log.notice("event tap installed")
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    fileprivate func reenableTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    // MARK: - Accessibility permission

    private func requestPermission() {
        if !promptedForPermission {
            promptedForPermission = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        waitForPermission()
    }

    /// There is no notification for an Accessibility grant, so poll while waiting for one.
    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, AXIsProcessTrusted() else { return }
            self.stopWaitingForPermission()
            if self.tap == nil, self.reverseMouse || self.reverseTrackpad { self.installTap() }
        }
    }

    private func stopWaitingForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: - Event handling

    /// Trackpad (and Magic Mouse) scrolls always carry a gesture or momentum phase;
    /// mouse wheels never do, even the "smooth" continuous ones.
    fileprivate static func isTrackpad(_ event: CGEvent) -> Bool {
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        return continuous && (phase != 0 || momentum != 0)
    }

    fileprivate static func reverse(_ event: CGEvent) {
        // Read everything first: setting one delta field makes CoreGraphics recompute the others.
        let delta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let delta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixed2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let point2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -delta2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -point2)
    }
}

private func scrollTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<ScrollReverserService>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        log.notice("event tap disabled by system (\(type.rawValue, privacy: .public)), re-enabling")
        service.reenableTap()
    case .scrollWheel:
        let trackpad = ScrollReverserService.isTrackpad(event)
        if trackpad ? service.reverseTrackpad : service.reverseMouse {
            ScrollReverserService.reverse(event)
        }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
