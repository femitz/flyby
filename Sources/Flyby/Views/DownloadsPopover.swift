import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted after the Dock moved files to the Trash, so lists showing them can reload.
    static let flybyMovedToTrash = Notification.Name("flybyMovedToTrash")
}

/// The latest downloads, in a glass panel above the Dock's Downloads icon. Unlike a menu,
/// its files can be dragged: to the Trash, to Finder or into another app.
@MainActor
final class DownloadsPopover {
    private let panel: NSPanel
    private let model = RecentDownloadsModel()
    private var monitors: [Any] = []
    private var trashObserver: NSObjectProtocol?
    /// When outside clicks last closed it, so the click on the Downloads icon that caused
    /// it does not reopen it right away.
    private var closedByClickAt = Date.distantPast

    var isShown: Bool { panel.isVisible }

    init(level: NSWindow.Level) {
        panel = PopoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let view = RecentDownloadsView(model: model) { [weak self] in self?.close() }
        panel.contentView = FirstMouseHostingView(rootView: view)

        trashObserver = NotificationCenter.default.addObserver(forName: .flybyMovedToTrash, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.reload() }
        }
    }

    /// Opens above `anchor` (screen point: horizontal center, bottom edge), or closes if open.
    func toggle(above anchor: NSPoint, on screen: NSScreen?) {
        if isShown { close(); return }
        guard Date().timeIntervalSince(closedByClickAt) > 0.3 else { return }

        model.reload()
        let host = panel.contentView!
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let bounds = (screen ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        var x = anchor.x - size.width / 2
        x = min(max(x, bounds.minX + 8), bounds.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x.rounded(), y: anchor.y, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        startMonitoring()
    }

    func close() {
        guard isShown else { return }
        panel.orderOut(nil)
        stopMonitoring()
    }

    /// Clicks anywhere else close it: in other apps (global monitor) and in Flyby's other
    /// windows, the Dock included (local monitor).
    private func startMonitoring() {
        stopMonitoring()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            DispatchQueue.main.async { self?.closeFromOutsideClick() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            if let self, event.window !== self.panel { self.closeFromOutsideClick() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func closeFromOutsideClick() {
        guard isShown else { return }
        closedByClickAt = Date()
        close()
    }

    private func stopMonitoring() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

private final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Flyby is never the active app; without this the first click would be swallowed.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class RecentDownloadsModel: ObservableObject {
    /// nil: no access to the folder.
    @Published private(set) var files: [RecentDownload]? = []

    func reload() {
        files = DownloadsStack.recent()
    }
}

private struct RecentDownloadsView: View {
    @ObservedObject var model: RecentDownloadsModel
    let onDone: () -> Void

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(FileManager.default.displayName(atPath: DownloadsStack.folder.path))
                .font(Brand.sans(13, .semibold))
                .foregroundStyle(Brand.lua)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            if let files = model.files {
                if files.isEmpty {
                    placeholder("Nenhum download")
                }
                VStack(spacing: 0) {
                    ForEach(files) { file in
                        row(file)
                    }
                }
            } else {
                placeholder("Sem acesso à pasta Downloads")
            }

            Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1).padding(.horizontal, 8)

            Button {
                NSWorkspace.shared.open(DownloadsStack.folder)
                onDone()
            } label: {
                HStack {
                    Text("Abrir no Finder").font(Brand.sans(13, .medium))
                    Spacer()
                    Image(systemName: "arrow.up.forward").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Brand.lua)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressedDimStyle())
        }
        .padding(8)
        .frame(width: 320)
        .background(DockGlass(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Brand.mono(11))
            .foregroundStyle(Brand.poeira)
            .padding(.horizontal, 8)
            .frame(height: 36)
    }

    /// Click opens the file; dragging hands the file to wherever it lands (see FileDragSource).
    private func row(_ file: RecentDownload) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(FileManager.default.displayName(atPath: file.url.path))
                    .font(Brand.sans(13))
                    .foregroundStyle(Brand.lua)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Self.dateFormatter.localizedString(for: file.added, relativeTo: Date()))
                    .font(Brand.mono(11))
                    .foregroundStyle(Brand.poeira)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .overlay(FileDragSource(url: file.url) {
            NSWorkspace.shared.open(file.url)
            onDone()
        })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            NSWorkspace.shared.open(file.url)
            onDone()
        }
    }
}

private struct PressedDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0))
            )
    }
}

/// A clear AppKit layer over a file row. A click (press and release without moving) runs
/// `onClick`; moving while pressed starts a real AppKit drag of the file URL, which the
/// Dock's Trash, Finder and other apps all accept. SwiftUI's `onDrag` on a button did not
/// start drags here, in a panel of an app that is never active.
private struct FileDragSource: NSViewRepresentable {
    let url: URL
    let onClick: () -> Void

    func makeNSView(context: Context) -> FileDragView {
        FileDragView(url: url, onClick: onClick)
    }

    func updateNSView(_ view: FileDragView, context: Context) {
        view.url = url
        view.onClick = onClick
    }
}

private final class FileDragView: NSView, NSDraggingSource {
    var url: URL
    var onClick: () -> Void
    private var mouseDownEvent: NSEvent?

    init(url: URL, onClick: @escaping () -> Void) {
        self.url = url
        self.onClick = onClick
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent else { return }
        let start = down.locationInWindow, now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }
        mouseDownEvent = nil
        layer?.backgroundColor = nil

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let point = convert(start, from: nil)
        item.setDraggingFrame(NSRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32), contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        layer?.backgroundColor = nil
        guard mouseDownEvent != nil else { return }
        mouseDownEvent = nil
        onClick()
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move, .generic, .delete]
    }
}
