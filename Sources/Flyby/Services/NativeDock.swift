import Foundation

/// Hides the macOS Dock while the Flyby Dock is on, and puts the user's settings back after.
///
/// There is no API to replace the Dock, and its process also runs Mission Control, so it
/// cannot be stopped. Instead it gets auto-hide with a very long delay, so it never shows,
/// and restarts to apply that. The original values are saved first, and a flag records
/// that Flyby changed them, so a launch after a crash can still restore them.
enum NativeDock {
    private static let domain = "com.apple.dock" as CFString
    private static let autohideKey = "autohide"
    private static let delayKey = "autohide-delay"
    /// Seconds. Distinctive on purpose: it also tells a Dock that Flyby already hid
    /// (from another Flyby build, say) apart from the user's own settings.
    private static let hiddenDelay = 1000.0

    private static let defaults = UserDefaults.standard
    private static let hiddenFlagKey = "nativeDockHiddenByFlyby"
    private static let originalAutohideKey = "nativeDockOriginalAutohide"
    private static let originalDelayKey = "nativeDockOriginalAutohideDelay"

    static var isHiddenByFlyby: Bool { defaults.bool(forKey: hiddenFlagKey) }

    static func hide() {
        guard !isHiddenByFlyby else { return }
        CFPreferencesAppSynchronize(domain)

        // An absent key stays absent on restore, so the Dock goes back to its own default.
        let alreadyHidden = (read(delayKey) as? Double) == hiddenDelay
        if !alreadyHidden {
            store(read(autohideKey), at: originalAutohideKey)
            store(read(delayKey), at: originalDelayKey)
        }
        defaults.set(true, forKey: hiddenFlagKey)

        write(autohideKey, true as CFBoolean)
        write(delayKey, hiddenDelay as CFNumber)
        restartDock()
    }

    static func restore() {
        guard isHiddenByFlyby else { return }
        write(autohideKey, defaults.object(forKey: originalAutohideKey) as CFPropertyList?)
        write(delayKey, defaults.object(forKey: originalDelayKey) as CFPropertyList?)
        for key in [hiddenFlagKey, originalAutohideKey, originalDelayKey] {
            defaults.removeObject(forKey: key)
        }
        restartDock()
    }

    private static func read(_ key: String) -> CFPropertyList? {
        CFPreferencesCopyAppValue(key as CFString, domain)
    }

    /// `nil` deletes the key.
    private static func write(_ key: String, _ value: CFPropertyList?) {
        CFPreferencesSetAppValue(key as CFString, value, domain)
        CFPreferencesAppSynchronize(domain)
    }

    private static func store(_ value: CFPropertyList?, at key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    /// The Dock only reads its settings at launch; launchd starts it again right away.
    private static func restartDock() {
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]
        try? killall.run()
        killall.waitUntilExit()
    }
}
