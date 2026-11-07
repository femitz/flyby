import Foundation
import ServiceManagement
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    @Published var monitorCPU: Bool {
        didSet { defaults.set(monitorCPU, forKey: Self.monitorCPUKey) }
    }
    @Published var monitorRAM: Bool {
        didSet { defaults.set(monitorRAM, forKey: Self.monitorRAMKey) }
    }
    @Published var monitorThermal: Bool {
        didSet { defaults.set(monitorThermal, forKey: Self.monitorThermalKey) }
    }

    @Published var monitorAppVolume: Bool {
        didSet { defaults.set(monitorAppVolume, forKey: Self.monitorAppVolumeKey) }
    }

    @Published var appIcon: AppIconStyle {
        didSet { defaults.set(appIcon.rawValue, forKey: Self.appIconKey) }
    }
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Self.showMenuBarIconKey) }
    }

    /// Off by default, unlike the monitors: the dock changes the desktop, so it is opt-in.
    @Published var customDockEnabled: Bool {
        didSet { defaults.set(customDockEnabled, forKey: Self.customDockEnabledKey) }
    }

    @Published var dockAutoHide: Bool {
        didSet { defaults.set(dockAutoHide, forKey: Self.dockAutoHideKey) }
    }

    /// The interface language. Follows the system until the user picks one in Preferences.
    @Published var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Self.languageKey) }
    }

    private static let languageKey = "language"
    private static let appIconKey = "appIcon"
    /// Off by default: an open app pinned to another profile shows only in that profile.
    @Published var dockShowRunningFromOtherProfiles: Bool {
        didSet { defaults.set(dockShowRunningFromOtherProfiles, forKey: Self.dockShowRunningFromOtherProfilesKey) }
    }

    /// Both off by default: the reverser needs Accessibility access, so it is opt-in.
    @Published var reverseMouseScroll: Bool {
        didSet { defaults.set(reverseMouseScroll, forKey: Self.reverseMouseScrollKey) }
    }
    @Published var reverseTrackpadScroll: Bool {
        didSet { defaults.set(reverseTrackpadScroll, forKey: Self.reverseTrackpadScrollKey) }
    }

    private static let reverseMouseScrollKey = "reverseMouseScroll"
    private static let reverseTrackpadScrollKey = "reverseTrackpadScroll"
    private static let customDockEnabledKey = "customDockEnabled"
    private static let dockShowRunningFromOtherProfilesKey = "dockShowRunningFromOtherProfiles"
    private static let dockAutoHideKey = "dockAutoHide"
    private static let showMenuBarIconKey = "showMenuBarIcon"
    private static let monitorAppVolumeKey = "monitorAppVolume"
    private static let monitorCPUKey = "monitorCPU"
    private static let monitorRAMKey = "monitorRAM"
    private static let monitorThermalKey = "monitorThermal"

    private static func storedBool(_ key: String, in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
    
    private init() {
        monitorCPU = Self.storedBool(Self.monitorCPUKey, in: defaults)
        monitorRAM = Self.storedBool(Self.monitorRAMKey, in: defaults)
        monitorThermal = Self.storedBool(Self.monitorThermalKey, in: defaults)
        monitorAppVolume = Self.storedBool(Self.monitorAppVolumeKey, in: defaults)
        showMenuBarIcon = Self.storedBool(Self.showMenuBarIconKey, in: defaults)
        customDockEnabled = defaults.bool(forKey: Self.customDockEnabledKey)
        dockAutoHide = Self.storedBool(Self.dockAutoHideKey, in: defaults)
        dockShowRunningFromOtherProfiles = defaults.bool(forKey: Self.dockShowRunningFromOtherProfilesKey)
        reverseMouseScroll = defaults.bool(forKey: Self.reverseMouseScrollKey)
        reverseTrackpadScroll = defaults.bool(forKey: Self.reverseTrackpadScrollKey)
        language = defaults.string(forKey: Self.languageKey).flatMap(Language.init(rawValue:)) ?? .system
        appIcon = defaults.string(forKey: Self.appIconKey).flatMap(AppIconStyle.init(rawValue:)) ?? .vacuo
    }
    
    var refreshInterval: Double {
        get {
            let value = defaults.double(forKey: "refreshInterval")
            return value > 0 ? value : 5.0
        }
        set {
            defaults.set(newValue, forKey: "refreshInterval")
        }
    }
    
    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: "launchAtLogin")
        }
        set {
            defaults.set(newValue, forKey: "launchAtLogin")
            setLaunchAtLogin(enabled: newValue)
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Error setting launch at login: \(error)")
            }
        }
    }
}
