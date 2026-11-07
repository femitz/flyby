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

    var isShown: Bool { panel.isVisible }

    init(service: SystemMonitorService) {
        hosting = NSHostingController(rootView: PanelView(service: service, state: state))
        // No automatic sizing: on recent SDKs the hosting view resizing its own window
        // around a SwiftUI ScrollView (Preferences) overflowed the stack inside AppKit's
        // layout engine. PanelView reports its size and the panel is resized here instead.
        hosting.sizingOptions = []

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

        state.onSizeChange = { [weak self] size in
            // Outside the layout pass that reported it.
            DispatchQueue.main.async { self?.resizeKeepingTop(to: size) }
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
        state.showingDockProfiles = false

        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor
        let top = anchor.minY - 6
        state.availableHeight = top - visible.minY - 8
        hosting.view.layoutSubtreeIfNeeded()

        let size = hosting.view.fittingSize
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)

        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)

        OutputVolumeService.shared.startPolling()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak button] _ in
            DispatchQueue.main.async {
                // A click on the status item itself is handled by toggle(); closing here too
                // would make the button's action reopen the panel right after.
                if let button, let window = button.window,
                   window.convertToScreen(button.convert(button.bounds, to: nil)).contains(NSEvent.mouseLocation) {
                    return
                }
                self?.close()
            }
        }
    }

    private func resizeKeepingTop(to size: CGSize) {
        guard panel.isVisible, size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        guard abs(frame.height - size.height) > 0.5 || abs(frame.width - size.width) > 0.5 else { return }
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
