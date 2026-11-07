import AppKit
import SwiftUI

/// The icon being dragged out of the Flyby Dock, in a small window of its own so it can
/// follow the pointer past the dock's edges. When releasing would remove the app, it dims
/// and says so above it.
@MainActor
final class DragGhost {
    private let panel: NSPanel
    private let model = DragGhostModel()

    private static let size = NSSize(width: 120, height: 92)

    init(level: NSWindow.Level) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true   // the drag keeps going to the dock underneath
        panel.level = NSWindow.Level(rawValue: level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: DragGhostView(model: model))
    }

    func show(_ session: DockDrag.Session) {
        if model.entry?.id != session.entry.id { model.entry = session.entry }
        if model.removing != session.removing { model.removing = session.removing }
        // The icon's center sits on the pointer; the label space is above it.
        let origin = NSPoint(
            x: session.screenLocation.x - Self.size.width / 2,
            y: session.screenLocation.y - 24 - 4
        )
        panel.setFrameOrigin(origin)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel.orderOut(nil)
        model.entry = nil
        model.removing = false
    }
}

@MainActor
private final class DragGhostModel: ObservableObject {
    @Published var entry: DockEntry?
    @Published var removing = false
}

private struct DragGhostView: View {
    @ObservedObject var model: DragGhostModel

    var body: some View {
        VStack(spacing: 6) {
            Text("Remover")
                .font(Brand.sans(12, .medium))
                .foregroundStyle(Brand.lua)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Brand.casco.opacity(0.94)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                .opacity(model.removing ? 1 : 0)
            if let entry = model.entry {
                Image(nsImage: entry.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .opacity(model.removing ? 0.55 : 1)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            }
        }
        .frame(width: 120, height: 92, alignment: .bottom)
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.12), value: model.removing)
    }
}
