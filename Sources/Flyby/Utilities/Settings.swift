import AppKit
import Foundation
import ServiceManagement
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    static func systemDefault() -> AppTheme {
        let appearance = NSApplication.shared.effectiveAppearance
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua ? .dark : .light
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    private let themeKey = "appTheme"

    @Published var theme: AppTheme

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

        if let storedTheme = defaults.string(forKey: themeKey),
           let resolvedTheme = AppTheme(rawValue: storedTheme) {
            theme = resolvedTheme
        } else {
            let resolvedTheme = AppTheme.systemDefault()
            theme = resolvedTheme
            defaults.set(resolvedTheme.rawValue, forKey: themeKey)
        }
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

    func setTheme(_ newTheme: AppTheme) {
        guard theme != newTheme else { return }
        theme = newTheme
        defaults.set(newTheme.rawValue, forKey: themeKey)
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
