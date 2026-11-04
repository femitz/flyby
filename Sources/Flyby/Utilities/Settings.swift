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

    private static let appIconKey = "appIcon"
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
