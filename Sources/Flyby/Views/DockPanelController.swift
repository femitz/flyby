import AppKit
import Combine
import SwiftUI

/// Never takes keyboard focus, so clicking the dock leaves the frontmost app's typing alone.
private final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Where the pointer is over the dock, in the dock view's coordinates (top-left origin).
/// Drives the hover labels.
@MainActor
final class DockPointer: ObservableObject {
    @Published var location: CGPoint?
}

/// Dragging an icon of the dock: reorders the active profile, pins an open app dropped among
/// the profile's apps, or removes a profile app dropped well outside the dock.
@MainActor
final class DockDrag: ObservableObject {
    enum Section { case fixed, profile, running }

    /// Where each icon is, in the dock view's coordinates; reported by DockView.
    struct Slot: Equatable {
        let id: String
        let section: Section
        let frame: CGRect
    }

    struct Session {
        let entry: DockEntry
        let origin: Section
        /// Left edge of the profile row and the width of one icon, taken when the drag
        /// starts. Icons are all the same width, so slot positions stay valid while the row
        /// reflows around the dragged icon.
        let profileStart: CGFloat
        let slotWidth: CGFloat
        /// Profile apps other than the dragged one.
        let otherCount: Int
        var location: CGPoint
        /// The pointer on screen, for the floating icon's window.
        var screenLocation: NSPoint
        /// Where it would land in the profile; nil when it is outside the profile row.
        var targetIndex: Int?
        /// A profile app far enough outside the dock: releasing removes it from the profile.
        var removing = false
    }

    /// How far outside the glass a profile app must go before releasing removes it, so a
    /// drag that only slips off the row cancels instead.
    private static let removeMargin = CGSize(width: 24, height: 50)

    var slots: [Slot] = []
    @Published var session: Session?

    /// A press on a profile or open app; nil for Finder, Downloads, the Trash or empty space.
    func begin(at point: CGPoint, screen: NSPoint, service: DockService) -> Bool {
        guard let slot = slots.first(where: { $0.section != .fixed && $0.frame.contains(point) }),
              let entry = (service.profileApps + service.running).first(where: { $0.id == slot.id })
        else { return false }

        let profileSlots = slots.filter { $0.section == .profile }.sorted { $0.frame.minX < $1.frame.minX }
        let start = profileSlots.first?.frame.minX
            ?? slots.filter { $0.section == .fixed }.map(\.frame.maxX).max().map { $0 + 2 }
            ?? slot.frame.minX
        session = Session(
            entry: entry,
            origin: slot.section,
            profileStart: start,
            slotWidth: slot.frame.width + 2,
            otherCount: profileSlots.count - (slot.section == .profile ? 1 : 0),
            location: point,
            screenLocation: screen,
            targetIndex: slot.section == .profile ? profileSlots.firstIndex { $0.id == slot.id } : nil
        )
        return true
    }

    /// `glass` is the dock's visible body in the view's coordinates (below the label headroom).
    func move(to point: CGPoint, screen: NSPoint, glass: CGRect) {
        guard var current = session else { return }
        current.location = point
        current.screenLocation = screen
        let wasRemoving = current.removing
        current.removing = current.origin == .profile
            && !glass.insetBy(dx: -Self.removeMargin.width, dy: -Self.removeMargin.height).contains(point)
        // Position in slots from the row's left edge. With the dragged icon in it the row has
        // otherCount + 1 slots, and the one under the pointer becomes the gap: slot k spans
        // [k, k + 1), so pressing an icon and starting to drag leaves it where it was.
        let position = (point.x - current.profileStart) / current.slotWidth
        let inRow = position >= -0.5 && position < CGFloat(current.otherCount + 1) + 0.5 && point.y > -60
        let target = inRow && !current.removing ? min(max(Int(position.rounded(.down)), 0), current.otherCount) : nil
        if target != current.targetIndex || current.removing != wasRemoving {
            current.targetIndex = target
            withAnimation(.easeOut(duration: 0.15)) { session = current }
        } else {
            session = current
        }
    }

    func end(service: DockService) {
        if let current = session {
            if current.removing {
                service.removeAppWithPoof(current.entry)
            } else if let index = current.targetIndex {
                service.placeApp(current.entry, at: index, in: service.activeProfileID)
            }
        }
        withAnimation(.easeOut(duration: 0.15)) { session = nil }
    }
}

/// Hosts the dock view: accepts the first click, tracks the pointer, drags icons around and
/// turns Ctrl + scroll into profile switches.
///
/// Icon drags are handled here in AppKit: SwiftUI drags did not start in this never-active
/// window. A press goes to SwiftUI as usual (so clicks and menus work); once it moves a few
/// points over an app, the button's press is cancelled and the drag takes over.
private final class DockHostingView<Content: View>: NSHostingView<Content> {
    var onProfileStep: ((Int) -> Void)?
    var pointer: DockPointer?
    var drag: DockDrag?
    private var gesture = ProfileScrollGesture()
    private var pointerArea: NSTrackingArea?
    private var mouseDownEvent: NSEvent?

    /// Flyby is a background app, so its windows are always inactive; without this the first
    /// click on an icon would only "activate" the window instead of opening the app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// `.activeAlways`: hover must work although Flyby is never the active app.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerArea { removeTrackingArea(pointerArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        pointerArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        pointer?.location = convert(event.locationInWindow, from: nil)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        pointer?.location = nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return super.mouseDragged(with: event) }
        let point = convert(event.locationInWindow, from: nil)
        let screen = window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        pointer?.location = point
        let glass = bounds.divided(atDistance: DockView.labelHeadroom, from: .minYEdge).remainder

        if drag.session != nil {
            drag.move(to: point, screen: screen, glass: glass)
            return
        }
        if let down = mouseDownEvent {
            let start = convert(down.locationInWindow, from: nil)
            if hypot(point.x - start.x, point.y - start.y) > 4,
               drag.begin(at: start, screen: screen, service: .shared) {
                mouseDownEvent = nil
                cancelButtonPress(event)
                drag.move(to: point, screen: screen, glass: glass)
                return
            }
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        if let drag, drag.session != nil {
            drag.end(service: .shared)
            return
        }
        super.mouseUp(with: event)
    }

    /// A release far outside every button ends SwiftUI's press without firing its action.
    private func cancelButtonPress(_ event: NSEvent) {
        guard let window,
              let release = NSEvent.mouseEvent(
                with: .leftMouseUp, location: NSPoint(x: -10_000, y: -10_000),
                modifierFlags: [], timestamp: event.timestamp, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 0
              )
        else { return }
        super.mouseUp(with: release)
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.control) else {
            super.scrollWheel(with: event)
            return
        }
        if let step = gesture.step(for: event) {
            onProfileStep?(step)
        }
    }
}

/// Turns scroll events into at most one profile step per gesture.
///
/// A trackpad swipe sends dozens of events plus momentum; it switches once, when the swipe
/// passes `threshold`, and ignores the rest until the fingers lift. A mouse wheel has no
/// phases, so each notch switches, with a short cooldown so a fast spin does not skip profiles.
struct ProfileScrollGesture {
    private var accumulated: CGFloat = 0
    private var firedThisGesture = false
    private var lastWheelStep = Date.distantPast

    private let threshold: CGFloat = 24
    private let wheelCooldown: TimeInterval = 0.18

    mutating func step(for event: NSEvent) -> Int? {
        // Momentum after the fingers lift never switches.
        if !event.momentumPhase.isEmpty { return nil }

        let delta = event.scrollingDeltaY
        if event.phase.isEmpty {
            // Mouse wheel.
            guard delta != 0, Date().timeIntervalSince(lastWheelStep) > wheelCooldown else { return nil }
            lastWheelStep = Date()
            return direction(delta)
        }

        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            accumulated = 0
            firedThisGesture = false
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            firedThisGesture = false
            return nil
        }
        guard !firedThisGesture else { return nil }
        accumulated += delta
        guard abs(accumulated) >= threshold else { return nil }
        firedThisGesture = true
        return direction(accumulated)
    }

    /// Scrolling down (content moving up) goes to the next profile. `scrollingDeltaY` already
    /// follows the user's natural-scrolling setting, so this matches how lists move for them.
    private func direction(_ delta: CGFloat) -> Int { delta < 0 ? 1 : -1 }
}

/// Places the Flyby Dock at the bottom of a screen, above other windows.
///
/// With auto-hide on, it stays hidden until the pointer touches the bottom edge of any
/// screen, appears on that screen (like the native Dock with several monitors), and hides
/// again shortly after the pointer leaves it. The edge is polled: a global mouse monitor
/// would need the Accessibility permission. The poll runs in the default run-loop mode only,
/// so the dock never hides while one of its context menus is open.
@MainActor
final class DockPanelController {
    private let panel: DockPanel
    private let hostingView: DockHostingView<DockView>
    private var observers: [NSObjectProtocol] = []
    private var settingsObservation: AnyCancellable?
    private var dragObservation: AnyCancellable?
    private var ghostObservation: AnyCancellable?
    private lazy var ghost = DragGhost(level: panel.level)
    private let drag = DockDrag()
    private lazy var downloads = DownloadsPopover(level: panel.level)

    private var isShown = false
    private var autoHide = AppSettings.shared.dockAutoHide
    private var revealed = false
    private var dockScreen: NSScreen?
    private var pointerLastInside = Date()
    private var poll: Timer?

    private let hideDelay: TimeInterval = 0.6
    private let slide: CGFloat = 12

    init() {
        panel = DockPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 70),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        // No .fullScreenAuxiliary: like the native Dock, it stays out of full-screen spaces.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let pointer = DockPointer()
        // The view needs the action before `self` exists; the closure is filled in below.
        var showDownloads: () -> Void = {}
        // The hosting view resizes the panel to fit the icons; every resize re-centers it.
        hostingView = DockHostingView(rootView: DockView(service: .shared, pointer: pointer, drag: drag, onDownloads: { showDownloads() }))
        hostingView.pointer = pointer
        hostingView.drag = drag
        hostingView.onProfileStep = { DockService.shared.switchProfile(by: $0) }
        panel.contentView = hostingView

        let center = NotificationCenter.default
        for (name, object) in [
            (NSWindow.didResizeNotification, panel as AnyObject?),
            (NSApplication.didChangeScreenParametersNotification, nil),
        ] {
            observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            })
        }

        showDownloads = { [weak self] in self?.toggleDownloads() }

        // Re-center once a drag ends; during it the dock keeps its left edge (see reposition).
        dragObservation = drag.$session
            .map { $0 == nil }
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reposition(animated: true) }

        ghostObservation = drag.$session
            .sink { [weak self] session in
                guard let self else { return }
                if let session { self.ghost.show(session) } else { self.ghost.hide() }
            }

        settingsObservation = AppSettings.shared.$dockAutoHide
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.setAutoHide($0) }
    }

    func show() {
        isShown = true
        if autoHide {
            startPolling()
        } else {
            reveal(animated: false)
        }
    }

    /// Above the clicked icon (the pointer is on it), a little over the glass.
    private func toggleDownloads() {
        let anchor = NSPoint(x: NSEvent.mouseLocation.x, y: panel.frame.maxY - DockView.labelHeadroom + 8)
        downloads.toggle(above: anchor, on: panel.screen)
    }

    func hide() {
        downloads.close()
        isShown = false
        stopPolling()
        revealed = false
        panel.orderOut(nil)
    }

    private func setAutoHide(_ enabled: Bool) {
        autoHide = enabled
        guard isShown else { return }
        if enabled {
            pointerLastInside = Date()   // hides once the pointer is away from it
            startPolling()
        } else {
            stopPolling()
            dockScreen = nil
            reveal(animated: !revealed)
        }
    }

    // MARK: Auto-hide

    private func startPolling() {
        guard poll == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .default)
        poll = timer
    }

    private func stopPolling() {
        poll?.invalidate()
        poll = nil
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        if !revealed {
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }),
                  mouse.y <= screen.frame.minY + 1 else { return }
            dockScreen = screen
            pointerLastInside = Date()
            reveal(animated: true)
            return
        }

        // The dock plus the strip under it, down to the screen edge the pointer came from.
        var zone = panel.frame.insetBy(dx: -10, dy: 0)
        let bottom = (dockScreen ?? panel.screen)?.frame.minY ?? zone.minY
        zone.size.height = zone.maxY - bottom
        zone.origin.y = bottom
        // The Downloads panel and icon drags keep the dock up: files must reach the Trash, and
        // an icon may wander above the dock while it is being placed.
        if NSMouseInRect(mouse, zone, false) || downloads.isShown || drag.session != nil {
            pointerLastInside = Date()
        } else if Date().timeIntervalSince(pointerLastInside) > hideDelay {
            conceal()
        }
    }

    private func reveal(animated: Bool) {
        guard let target = targetFrame() else { return }
        revealed = true
        guard animated else {
            panel.alphaValue = 1
            panel.setFrame(target, display: true)
            panel.orderFrontRegardless()
            panel.invalidateShadow()
            return
        }
        panel.alphaValue = 0
        panel.setFrame(target.offsetBy(dx: 0, dy: -slide), display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.invalidateShadow() }
        }
    }

    private func conceal() {
        revealed = false
        let frame = panel.frame.offsetBy(dx: 0, dy: -slide)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.revealed else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    // MARK: Layout

    /// Centered on the dock's screen (the menu bar screen unless auto-hide picked another),
    /// on top of `visibleFrame` so it never overlaps a visible native Dock.
    private func targetFrame() -> NSRect? {
        guard let screen = dockScreen ?? NSScreen.screens.first else { return nil }
        let size = hostingView.fittingSize
        guard size.width > 0 else { return nil }
        let origin = NSPoint(
            x: (screen.frame.midX - size.width / 2).rounded(),
            y: screen.visibleFrame.minY + 4
        )
        return NSRect(origin: origin, size: size)
    }

    private func reposition(animated: Bool = false) {
        guard revealed, var target = targetFrame() else { return }
        // While an icon is dragged the width can change; re-centering would slide the dock
        // under the pointer and move the landing spot, so the left edge stays put.
        if drag.session != nil { target.origin.x = panel.frame.origin.x }
        guard panel.frame != target else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().setFrame(target, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated { self?.panel.invalidateShadow() }
            }
        } else {
            panel.setFrame(target, display: true)
            panel.invalidateShadow()
        }
    }
}
