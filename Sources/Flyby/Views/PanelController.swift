import AppKit
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

/// Shows the Flyby panel under the status item. A borderless panel (instead of NSPopover)
/// lets the SwiftUI view draw its own surface, border, radius and shadow.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let hosting: NSHostingController<PanelView>
    private let state = PanelState()
    private var clickMonitor: Any?
    private var sizeObservation: NSKeyValueObservation?

    var isShown: Bool { panel.isVisible }

    init(service: SystemMonitorService) {
        hosting = NSHostingController(rootView: PanelView(service: service, state: state))
        hosting.sizingOptions = [.preferredContentSize]

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.delegate = self

        sizeObservation = hosting.observe(\.preferredContentSize) { [weak self] _, _ in
            DispatchQueue.main.async { self?.resizeKeepingTop() }
        }
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        isShown ? close() : show(relativeTo: button)
    }

    func close() {
        panel.close()
    }

    private func show(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }

        state.showingPreferences = false
        hosting.view.layoutSubtreeIfNeeded()

        let size = hosting.preferredContentSize == .zero ? hosting.view.fittingSize : hosting.preferredContentSize
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor

        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let top = anchor.minY - 6

        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)

        OutputVolumeService.shared.startPolling()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.close() }
        }
    }

    private func resizeKeepingTop() {
        guard panel.isVisible else { return }
        let size = hosting.preferredContentSize
        guard size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    func windowWillClose(_ notification: Notification) {
        OutputVolumeService.shared.stopPolling()
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
