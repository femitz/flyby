import SwiftUI
import AppKit
import Combine

@main
struct FlybyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var cancellables = Set<AnyCancellable>()
    private let service = SystemMonitorService.shared
    private let settings = AppSettings.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if exportIconsIfRequested() || exportInstallerBackgroundIfRequested() { return }

        NSApp.appearance = NSAppearance(named: .darkAqua)
        setupStatusBar()
        panelController = PanelController(service: service)
        observeSettings()
        applyAppIcon()
        service.start()
        _ = AppVolumeService.shared   // starts itself when "App volume" is enabled
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        service.stop()
        AppVolumeService.shared.stop()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateButtonTitle()
        }
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateButtonTitle() }
        }
    }
    
    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        panelController?.toggle(relativeTo: button)
    }

    private func observeSettings() {
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateButtonTitle()
                self?.applyAppIcon()
            }
            .store(in: &cancellables)
    }

    /// Applies the chosen icon variation: the app's runtime icon and the menu bar glyph.
    private func applyAppIcon() {
        if let icon = AppIconRenderer.applicationIcon(settings.appIcon) {
            NSApp.applicationIconImage = icon
        }

        guard let button = statusItem?.button else { return }
        if settings.showMenuBarIcon, let glyph = AppIconRenderer.menuBarImage() {
            button.image = glyph
            button.imagePosition = .imageLeft
        } else {
            button.image = nil
        }
    }

    /// `Flyby --export-icons <dir>` writes the Vácuo `.iconset` and quits; see scripts/generate-icns.sh.
    private func exportIconsIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--export-icons"), args.indices.contains(flag + 1) else { return false }
        do {
            try AppIconRenderer.exportIconset(style: .vacuo, to: URL(fileURLWithPath: args[flag + 1]))
        } catch {
            FileHandle.standardError.write(Data("Icon export failed: \(error)\n".utf8))
        }
        NSApp.terminate(nil)
        return true
    }
    
    /// `Flyby --export-dmg-background <dir> <version> <min macOS>` writes the installer
    /// background images and quits; used by scripts/make-dmg.sh.
    private func exportInstallerBackgroundIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--export-dmg-background"), args.indices.contains(flag + 3) else { return false }
        do {
            try InstallerBackground.export(
                to: URL(fileURLWithPath: args[flag + 1]),
                version: args[flag + 2],
                minimumOS: args[flag + 3]
            )
        } catch {
            FileHandle.standardError.write(Data("Installer background export failed: \(error)\n".utf8))
            exit(1)
        }
        NSApp.terminate(nil)
        return true
    }

    private func updateButtonTitle() {
        var parts: [String] = []
        let labeled = [settings.monitorCPU, settings.monitorRAM].filter { $0 }.count > 1
        if settings.monitorCPU {
            parts.append("\(labeled ? "CPU " : "")\(Int(service.cpuUsage * 100))%")
        }
        if settings.monitorRAM {
            parts.append("\(labeled ? "RAM " : "")\(Int(service.ramUsage * 100))%")
        }
        if settings.monitorThermal && service.thermalState != .nominal {
            parts.append(service.thermalState.icon)   // only shown when the Mac is running warm
        }

        let title = parts.isEmpty ? (settings.showMenuBarIcon ? "" : "Flyby") : " " + parts.joined(separator: " · ")
        statusItem?.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)]
        )
    }
}
