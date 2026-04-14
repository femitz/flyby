import Foundation
import ServiceManagement

final class AppSettings {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    private init() {}
    
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