import AppKit
import Combine
import SwiftUI

/// An app pinned to a dock profile. The bundle ID finds the app even after it moves;
/// the path is the fallback for apps without one.
struct DockItem: Codable, Hashable {
    var bundleID: String
    var path: String
}

struct DockProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var items: [DockItem]
}

/// A resolved app, ready to draw in the dock.
struct DockEntry: Identifiable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage
    let isRunning: Bool
}

/// Profiles of the Flyby Dock and the running apps it shows.
@MainActor
final class DockService: ObservableObject {
    static let shared = DockService()

    /// Apps shown in every profile (Finder).
    @Published private(set) var fixed: [DockEntry] = []
    /// The active profile's apps.
    @Published private(set) var profileApps: [DockEntry] = []
    /// Running apps that are not pinned, shown after the divider (like the native Dock).
    @Published private(set) var running: [DockEntry] = []

    @Published private(set) var profiles: [DockProfile]
    @Published private(set) var activeProfileID: UUID
    /// Direction of the last switch, so the swap slides the way the scroll went.
    @Published private(set) var lastSwitch: SwitchDirection = .forward

    enum SwitchDirection { case forward, backward }

    /// Shown in every profile.
    private let fixedItems = [DockItem(bundleID: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app")]

    private let defaults = UserDefaults.standard
    private var iconCache: [String: NSImage] = [:]
    private var runningObservation: NSKeyValueObservation?
    private var settingsObservation: AnyCancellable?

    private static let profilesKey = "dockProfiles"
    private static let activeProfileKey = "dockActiveProfile"

    private init() {
        let stored = defaults.data(forKey: Self.profilesKey)
            .flatMap { try? JSONDecoder().decode([DockProfile].self, from: $0) }
            .flatMap { $0.isEmpty ? nil : $0 }
        let profiles = stored ?? Self.defaultProfiles()
        self.profiles = profiles

        let storedActive = defaults.string(forKey: Self.activeProfileKey).flatMap(UUID.init(uuidString:))
        activeProfileID = profiles.first { $0.id == storedActive }?.id ?? profiles[0].id

        if stored == nil { save() }

        runningObservation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
        settingsObservation = AppSettings.shared.$dockShowRunningFromOtherProfiles
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
        refresh()
    }

    var activeProfile: DockProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles[0]
    }

    var activeProfileIndex: Int {
        profiles.firstIndex { $0.id == activeProfileID } ?? 0
    }

    /// Moves to the next (+1) or previous (-1) profile, wrapping around at the ends.
    func switchProfile(by offset: Int) {
        guard profiles.count > 1, offset != 0 else { return }
        let index = (activeProfileIndex + offset % profiles.count + profiles.count) % profiles.count
        lastSwitch = offset > 0 ? .forward : .backward
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            activeProfileID = profiles[index].id
            refresh()
        }
        save()
    }

    // MARK: Editing

    func activateProfile(_ id: UUID) {
        guard let target = profiles.firstIndex(where: { $0.id == id }) else { return }
        switchProfile(by: target - activeProfileIndex)
    }

    func addProfile() {
        profiles.append(DockProfile(id: UUID(), name: L10n.defaultProfileName(profiles.count + 1), items: []))
        commit()
    }

    /// The last profile cannot be removed; removing the active one moves to its neighbor.
    func removeProfile(_ id: UUID) {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: index)
        if activeProfileID == id {
            activeProfileID = profiles[min(index, profiles.count - 1)].id
        }
        commit()
    }

    func renameProfile(_ id: UUID, to name: String) {
        update(id) { $0.name = name }
    }

    /// Adds apps at the end of a profile, skipping non-apps, duplicates and the fixed apps.
    func addApps(_ urls: [URL], to id: UUID) {
        let fixedIDs = Set(fixedItems.map(\.bundleID))
        update(id) { profile in
            for url in urls where url.pathExtension == "app" {
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.path
                guard !fixedIDs.contains(bundleID), !profile.items.contains(where: { $0.bundleID == bundleID }) else { continue }
                profile.items.append(DockItem(bundleID: bundleID, path: url.path))
            }
        }
    }

    func removeApp(_ bundleID: String, from id: UUID) {
        update(id) { $0.items.removeAll { $0.bundleID == bundleID } }
    }

    /// Moves an app to the position of another app in the same profile.
    func moveApp(_ bundleID: String, to targetBundleID: String, in id: UUID) {
        update(id) { profile in
            guard let from = profile.items.firstIndex(where: { $0.bundleID == bundleID }),
                  let to = profile.items.firstIndex(where: { $0.bundleID == targetBundleID }),
                  from != to else { return }
            profile.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    /// Puts an app at `index` of a profile: moves it if it is already there, pins it if not
    /// (an open app dragged into the profile). The index counts the other apps only.
    func placeApp(_ entry: DockEntry, at index: Int, in id: UUID) {
        guard !isFixed(entry) else { return }
        update(id) { profile in
            let item = profile.items.firstIndex { $0.bundleID == entry.id }
                .map { profile.items.remove(at: $0) }
                ?? DockItem(bundleID: entry.id, path: entry.url.path)
            profile.items.insert(item, at: min(max(index, 0), profile.items.count))
        }
    }

    /// The sound the native Dock plays when an icon is dragged off it.
    private static let poofSound = NSSound(
        contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/poof item off dock.aif",
        byReference: true
    )

    /// Removes an app dragged off the dock from the active profile.
    func removeAppWithPoof(_ entry: DockEntry) {
        guard isInActiveProfile(entry) else { return }
        removeApp(entry.id, from: activeProfileID)
        Self.poofSound?.stop()
        Self.poofSound?.play()
    }

    func isInActiveProfile(_ entry: DockEntry) -> Bool {
        activeProfile.items.contains { $0.bundleID == entry.id }
    }

    func isFixed(_ entry: DockEntry) -> Bool {
        isFixed(bundleID: entry.id)
    }

    func isFixed(bundleID: String) -> Bool {
        fixedItems.contains { $0.bundleID == bundleID }
    }

    /// Icon and name for a profile item, for the editor. Nil when the app is gone.
    func entry(for item: DockItem) -> DockEntry? {
        resolve(item).map { entry(id: item.bundleID, url: $0, isRunning: false) }
    }

    private func update(_ id: UUID, _ change: (inout DockProfile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        change(&profiles[index])
        commit()
    }

    /// Profiles still carrying a default name ("Perfil 2", "Profile 2") follow the language;
    /// a name the user typed is theirs and stays.
    func localizeDefaultNames() {
        var changed = false
        for index in profiles.indices {
            guard let number = L10n.defaultProfileNumber(of: profiles[index].name) else { continue }
            let name = L10n.defaultProfileName(number)
            if profiles[index].name != name {
                profiles[index].name = name
                changed = true
            }
        }
        if changed { commit() }
    }

    private func commit() {
        save()
        refresh()
    }

    // MARK: Apps

    func revealInFinder(_ entry: DockEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
    }

    static let trashURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")

    /// Finder shows its Trash window when asked to open the folder.
    func openTrash() {
        NSWorkspace.shared.open(Self.trashURL)
    }

    /// The sound the native Dock plays when something is dropped on its Trash.
    private static let trashSound = NSSound(
        contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif",
        byReference: true
    )

    func moveToTrash(_ urls: [URL]) {
        NSWorkspace.shared.recycle(urls) { trashed, error in
            DispatchQueue.main.async {
                if let error { NSLog("Flyby Dock: could not move to Trash: \(error)") }
                // Only when something really went to the Trash, so the sound means it worked.
                if !trashed.isEmpty {
                    Self.trashSound?.stop()
                    Self.trashSound?.play()
                }
                NotificationCenter.default.post(name: .flybyMovedToTrash, object: nil)
            }
        }
    }

    func quit(_ entry: DockEntry) {
        NSRunningApplication.runningApplications(withBundleIdentifier: entry.id).forEach { $0.terminate() }
    }

    /// Opens the app, or brings it forward if it is running. Like the native Dock, a running
    /// app with no windows gets a reopen event and usually shows a new window.
    func open(_ entry: DockEntry) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: entry.url, configuration: configuration) { _, error in
            if let error { NSLog("Flyby Dock: could not open \(entry.name): \(error)") }
        }
    }

    private func refresh() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let runningIDs = Set(apps.compactMap(\.bundleIdentifier))

        var seen = Set<String>()
        let resolveAll = { (items: [DockItem]) -> [DockEntry] in
            items.compactMap { item in
                guard seen.insert(item.bundleID).inserted, let url = self.resolve(item) else { return nil }
                return self.entry(id: item.bundleID, url: url, isRunning: runningIDs.contains(item.bundleID))
            }
        }
        fixed = resolveAll(fixedItems)
        profileApps = resolveAll(activeProfile.items)

        // An open app pinned to another profile belongs to that profile, unless the user
        // asked to see every open app.
        if !AppSettings.shared.dockShowRunningFromOtherProfiles {
            for profile in profiles {
                seen.formUnion(profile.items.map(\.bundleID))
            }
        }

        running = apps.compactMap { app in
            guard let url = app.bundleURL else { return nil }
            let id = app.bundleIdentifier ?? url.path
            guard seen.insert(id).inserted else { return nil }
            return entry(id: id, url: url, isRunning: true)
        }
    }

    private func resolve(_ item: DockItem) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) { return url }
        return FileManager.default.fileExists(atPath: item.path) ? URL(fileURLWithPath: item.path) : nil
    }

    private func entry(id: String, url: URL, isRunning: Bool) -> DockEntry {
        let icon = iconCache[url.path] ?? {
            let image = NSWorkspace.shared.icon(forFile: url.path)
            iconCache[url.path] = image
            return image
        }()
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return DockEntry(id: id, name: name, url: url, icon: icon, isRunning: isRunning)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Self.profilesKey)
        }
        defaults.set(activeProfileID.uuidString, forKey: Self.activeProfileKey)
    }

    /// First-run profiles, made of common apps that are installed on this Mac:
    /// one for browsing and media, one for work.
    private static func defaultProfiles() -> [DockProfile] {
        func profile(_ name: String, _ candidates: [String]) -> DockProfile {
            let items = candidates.compactMap { id -> DockItem? in
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
                return DockItem(bundleID: id, path: url.path)
            }
            return DockProfile(id: UUID(), name: name, items: items)
        }
        return [
            profile(L10n.defaultProfileName(1), ["com.apple.Safari", "com.google.Chrome", "com.spotify.client", "com.apple.systempreferences"]),
            profile(L10n.defaultProfileName(2), ["com.microsoft.VSCode", "com.anthropic.claudefordesktop", "com.apple.Terminal"]),
        ]
    }
}
