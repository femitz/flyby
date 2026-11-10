import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Flyby Dock: native-looking glass with the app icons. The running-app dot is the one
/// brand accent (Brand.ignicao), marking where something is happening.
struct DockView: View {
    @ObservedObject var service: DockService
    @ObservedObject var pointer: DockPointer
    @ObservedObject var drag: DockDrag
    /// The Downloads icon was clicked; the controller shows the recent files above it.
    let onDownloads: () -> Void

    @State private var dropTargeted = false
    @State private var iconFrames: [DockIconFrame] = []
    /// Redraws the dock when the hover effect changes (it sets the headroom).
    @ObservedObject private var settings = AppSettings.shared

    private let cornerRadius: CGFloat = 18
    static let iconSize: CGFloat = 48

    /// How far the hovered icon stays above its slot with the chosen effect.
    static var hoverRise: CGFloat {
        (AppSettings.shared.activeDockHoverEffect?.rise(for: iconSize) ?? 0).rounded(.up)
    }

    /// Clear space above the glass where hover labels (and a raised icon) appear. It is part
    /// of the window, but clicks on its transparent pixels go through to the windows behind.
    static var labelHeadroom: CGFloat { 32 + hoverRise }

    /// The icon under the pointer, if any. None while an icon is dragged.
    private var hovered: DockIconFrame? {
        guard drag.session == nil, let location = pointer.location else { return nil }
        return iconFrames.last { $0.frame.contains(location) }
    }

    var body: some View {
        let hovered = hovered
        return dock
            .padding(.top, Self.labelHeadroom)
            .environment(\.dockHoveredID, hovered?.id)
            .coordinateSpace(name: DockSlots.space)
            .onPreferenceChange(DockSlots.self) { drag.slots = $0 }
            .onPreferenceChange(DockIconFrames.self) { iconFrames = $0 }
            // Drawn here rather than on each icon, so the clipped profile row cannot cut it off.
            .overlay {
                if let hovered {
                    HoverLabel(text: hovered.name)
                        .position(x: hovered.frame.midX, y: hovered.frame.minY - 18 - Self.hoverRise)
                }
            }
    }

    /// The rows as drawn: while an icon is dragged over the profile row it already sits at
    /// its landing spot (invisible, leaving a gap) and leaves the row it came from; about to
    /// be removed, its gap closes. The icon itself follows the pointer in DragGhost.
    private var rows: (profile: [DockEntry], running: [DockEntry]) {
        var profile = service.profileApps
        var running = service.running
        if let session = drag.session {
            if session.removing {
                profile.removeAll { $0.id == session.entry.id }
            } else if let target = session.targetIndex {
                profile.removeAll { $0.id == session.entry.id }
                running.removeAll { $0.id == session.entry.id }
                profile.insert(session.entry, at: min(target, profile.count))
            }
        }
        return (profile, running)
    }

    private var dock: some View {
        let rows = rows
        return HStack(spacing: 2) {
            ForEach(service.fixed) { entry in
                DockIcon(entry: entry, service: service, section: .fixed, isDragged: false)
            }
            profileSection(rows.profile)
            divider
            if !rows.running.isEmpty {
                ForEach(rows.running) { entry in
                    DockIcon(entry: entry, service: service, section: .running, isDragged: entry.id == drag.session?.entry.id)
                }
                divider
            }
            DownloadsIcon(action: onDownloads)
            TrashIcon(service: service)
            if service.profiles.count > 1 {
                ProfileDots(count: service.profiles.count, active: service.activeProfileIndex)
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 3)
        .background(DockGlass(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        // While an app from Finder hovers over the dock, the border marks where it will land.
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Brand.ignicao, lineWidth: 1.5)
                .opacity(dropTargeted ? 1 : 0)
        )
        .fixedSize()
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            let profileID = service.activeProfileID
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.pathExtension == "app" else { return }
                    Task { @MainActor in DockService.shared.addApps([url], to: profileID) }
                }
            }
            return true
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 44)
            .padding(.horizontal, 6)
    }

    /// The active profile's apps. A new identity per profile makes SwiftUI swap the whole
    /// row, sliding in from the side the scroll went towards.
    private func profileSection(_ apps: [DockEntry]) -> some View {
        let forward = service.lastSwitch == .forward
        // The ZStack holds the outgoing and incoming rows during the swap and clips both
        // to the dock's height.
        return ZStack {
            HStack(spacing: 2) {
                ForEach(apps) { entry in
                    DockIcon(entry: entry, service: service, section: .profile, isDragged: entry.id == drag.session?.entry.id)
                }
            }
            .id(service.activeProfileID)
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .bottom : .top).combined(with: .opacity),
                removal: .move(edge: forward ? .top : .bottom).combined(with: .opacity)
            ))
        }
        // Clipped to the row only while the rows slide; otherwise a hovered icon may grow
        // past it, up into the headroom and over its neighbours.
        .clipShape(service.isSwitching ? OverflowClip.none : OverflowClip(top: Self.labelHeadroom, sides: 24, bottom: 6))
    }
}

/// One dot per profile, stacked vertically like the scroll that switches them.
private struct ProfileDots: View {
    let count: Int
    let active: Int

    /// Not read, but observing it redraws the view (its texts) when the language changes.
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == active ? Brand.lua : Brand.poeira.opacity(0.45))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.profilePosition(active + 1, of: count))
    }
}

private struct DockIcon: View {
    let entry: DockEntry
    let service: DockService
    let section: DockDrag.Section
    /// The slot of the icon being dragged: kept for the layout, drawn by the floating copy.
    let isDragged: Bool

    /// Not read, but observing it redraws the view (its texts) when the language changes.
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Button { service.open(entry) } label: {
            VStack(spacing: 3) {
                Image(nsImage: entry.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: DockView.iconSize, height: DockView.iconSize)
                    .dockHover(entry.id)
                Circle()
                    .fill(Brand.ignicao)
                    .frame(width: 4, height: 4)
                    .opacity(entry.isRunning ? 1 : 0)
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(DockIconButtonStyle())
        .opacity(isDragged ? 0 : 1)
        .contextMenu { menu }
        .background(GeometryReader { proxy in
            Color.clear.preference(
                key: DockSlots.self,
                value: [DockDrag.Slot(id: entry.id, section: section, frame: proxy.frame(in: .named(DockSlots.space)))]
            )
        })
        .dockLabel(id: entry.id, name: entry.name)
        .accessibilityLabel(entry.name)
        .accessibilityValue(entry.isRunning ? L10n.running : "")
    }
}

extension DockIcon {
    @ViewBuilder
    fileprivate var menu: some View {
        let profile = service.activeProfile
        if service.isInActiveProfile(entry) {
            Button(L10n.removeFrom(profile.name)) { service.removeApp(entry.id, from: profile.id) }
        } else if !service.isFixed(entry) {
            Button(L10n.keepIn(profile.name)) { service.addApps([entry.url], to: profile.id) }
        }
        Button(L10n.showInFinder) { service.revealInFinder(entry) }
        if entry.isRunning && !service.isFixed(entry) {
            Divider()
            Button(L10n.quit) { service.quit(entry) }
        }
    }
}

/// Opens the Trash; files dropped on it go to the Trash, like on the native Dock.
/// Always the empty icon: macOS keeps ~/.Trash private, so Flyby cannot see if it is full.
private struct TrashIcon: View {
    static let hoverID = "flyby.trash"
    let service: DockService
    @State private var targeted = false
    /// Not read, but observing it redraws the view (its texts) when the language changes.
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Button { service.openTrash() } label: {
            VStack(spacing: 3) {
                Image(nsImage: NSImage(named: NSImage.trashEmptyName) ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: DockView.iconSize, height: DockView.iconSize)
                    .brightness(targeted ? 0.15 : 0)
                    .dockHover(Self.hoverID)
                Color.clear.frame(width: 4, height: 4)
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(DockIconButtonStyle())
        .contextMenu {
            Button(L10n.openInFinder) { service.openTrash() }
            Divider()
            // After the menu closes, so the confirmation is not run from inside its tracking.
            Button(L10n.emptyTrash + "…") { DispatchQueue.main.async { service.emptyTrash() } }
        }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in DockService.shared.moveToTrash([url]) }
                }
            }
            return true
        }
        .dockLabel(id: Self.hoverID, name: L10n.trash)
        .accessibilityLabel(L10n.trash)
    }
}

/// The Downloads folder: a click shows the latest files above it (see DownloadsPopover).
private struct DownloadsIcon: View {
    static let hoverID = "flyby.downloads"
    let action: () -> Void
    private let folder = DownloadsStack.folder

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: DockView.iconSize, height: DockView.iconSize)
                    .dockHover(Self.hoverID)
                Color.clear.frame(width: 4, height: 4)
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(DockIconButtonStyle())
        .dockLabel(id: Self.hoverID, name: FileManager.default.displayName(atPath: folder.path))
        .accessibilityLabel(FileManager.default.displayName(atPath: folder.path))
    }
}

/// The name bubble above a hovered icon, like the native Dock's.
private struct HoverLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Brand.sans(12, .medium))
            .foregroundStyle(Brand.lua)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Brand.casco.opacity(0.94)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            .fixedSize()
            .allowsHitTesting(false)
    }
}

/// Where each icon is, in the dock view's coordinates, to find the one under the pointer
/// (for its label and hover effect).
private struct DockIconFrame: Equatable {
    let id: String
    let name: String
    let frame: CGRect
}

/// Icon positions for dragging, in the dock view's coordinates (which match the hosting
/// view's, where the mouse events arrive).
private struct DockSlots: PreferenceKey {
    static let space = "dock"
    static let defaultValue: [DockDrag.Slot] = []
    static func reduce(value: inout [DockDrag.Slot], nextValue: () -> [DockDrag.Slot]) {
        value.append(contentsOf: nextValue())
    }
}

private struct DockIconFrames: PreferenceKey {
    static let defaultValue: [DockIconFrame] = []
    static func reduce(value: inout [DockIconFrame], nextValue: () -> [DockIconFrame]) {
        value.append(contentsOf: nextValue())
    }
}

private extension View {
    func dockLabel(id: String, name: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(
                key: DockIconFrames.self,
                value: [DockIconFrame(id: id, name: name, frame: proxy.frame(in: .named(DockSlots.space)))]
            )
        })
    }

    /// The chosen hover effect, played while the pointer is over the icon with this id.
    func dockHover(_ id: String) -> some View {
        modifier(DockIconHover(id: id))
    }
}

private struct DockHoveredIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private extension EnvironmentValues {
    /// The id of the icon under the pointer, set by DockView.
    var dockHoveredID: String? {
        get { self[DockHoveredIDKey.self] }
        set { self[DockHoveredIDKey.self] = newValue }
    }
}

private struct DockIconHover: ViewModifier {
    let id: String
    @Environment(\.dockHoveredID) private var hoveredID
    @ObservedObject private var settings = AppSettings.shared

    func body(content: Content) -> some View {
        content.dockHoverEffect(settings.activeDockHoverEffect, active: hoveredID == id, side: DockView.iconSize)
    }
}

/// The view's own rectangle grown by the given margins, so content may overflow it that far.
private struct OverflowClip: Shape {
    var top: CGFloat = 0
    var sides: CGFloat = 0
    var bottom: CGFloat = 0

    static let none = OverflowClip()

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX - sides,
            y: rect.minY - top,
            width: rect.width + sides * 2,
            height: rect.height + top + bottom
        ))
    }
}

private struct DockIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.brightness(configuration.isPressed ? -0.3 : 0)
    }
}

/// Behind-window blur like the native Dock. The rounded shape comes from a mask image,
/// which clips the blur itself (a SwiftUI clipShape would not).
struct DockGlass: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active   // the dock's window is never key, keep the glass on anyway
        view.maskImage = Self.mask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}

    private static func mask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
