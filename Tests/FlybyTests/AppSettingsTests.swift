import Foundation
import Testing
@testable import Flyby

/// Each test gets its own UserDefaults suite, so nothing touches the real preferences.
@Suite struct AppSettingsTests {
    let suiteName = "flyby-tests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    // Swift Testing has no tearDown; a fresh random suite per test keeps runs independent,
    // and this drops it from disk.
    private func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }

    @Test func freshInstallDefaults() {
        defer { cleanUp() }
        let settings = AppSettings(defaults: defaults)

        // Monitors are on until the user turns them off.
        #expect(settings.monitorCPU)
        #expect(settings.monitorRAM)
        #expect(settings.monitorThermal)
        #expect(settings.monitorAppVolume)
        #expect(settings.showMenuBarIcon)
        #expect(settings.dockAutoHide)
        #expect(settings.dockHoverEffectsEnabled)

        // Anything that changes the desktop or needs Accessibility is opt-in.
        #expect(!settings.customDockEnabled)
        #expect(!settings.dockShowRunningFromOtherProfiles)
        #expect(!settings.reverseMouseScroll)
        #expect(!settings.reverseTrackpadScroll)

        #expect(settings.dockHoverEffect == .magnify)
        #expect(settings.appIcon == .vacuo)
        #expect(settings.language == Language.system)
        #expect(settings.refreshInterval == 5.0)
    }

    @Test func changesSurviveARelaunch() {
        defer { cleanUp() }
        let settings = AppSettings(defaults: defaults)
        settings.monitorCPU = false
        settings.customDockEnabled = true
        settings.dockHoverEffect = .spin
        settings.language = .en
        settings.refreshInterval = 2

        let relaunched = AppSettings(defaults: defaults)
        #expect(!relaunched.monitorCPU)
        #expect(relaunched.customDockEnabled)
        #expect(relaunched.dockHoverEffect == .spin)
        #expect(relaunched.language == .en)
        #expect(relaunched.refreshInterval == 2)
    }

    @Test func unknownStoredValuesFallBack() {
        defer { cleanUp() }
        // A value written by a newer or older build that this one does not know.
        defaults.set("zoom", forKey: "dockHoverEffect")
        defaults.set("fr", forKey: "language")
        defaults.set("neon", forKey: "appIcon")
        defaults.set(0, forKey: "refreshInterval")

        let settings = AppSettings(defaults: defaults)
        #expect(settings.dockHoverEffect == .magnify)
        #expect(settings.language == Language.system)
        #expect(settings.appIcon == .vacuo)
        #expect(settings.refreshInterval == 5.0)
    }

    @Test func hoverEffectSwitchTurnsTheEffectOff() {
        defer { cleanUp() }
        let settings = AppSettings(defaults: defaults)
        settings.dockHoverEffect = .bounce
        #expect(settings.activeDockHoverEffect == .bounce)
        settings.dockHoverEffectsEnabled = false
        #expect(settings.activeDockHoverEffect == nil)
    }
}
