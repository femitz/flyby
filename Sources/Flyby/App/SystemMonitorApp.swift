import SwiftUI
import AppKit
import Combine
import ServiceManagement
import Charts

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
    private var popover: NSPopover?
    private var hostingController: NSHostingController<DashboardView>?
    private var cancellables = Set<AnyCancellable>()
    private let service = SystemMonitorService.shared
    private let settings = AppSettings.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if exportIconsIfRequested() { return }

        setupStatusBar()
        setupPopover()
        observeThemeChanges()
        observeMonitorToggles()
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
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateButtonTitle()
        }
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateButtonTitle() }
        }
    }
    
    private func setupPopover() {
        let dashboard = DashboardView(service: service)

        let hostingController = NSHostingController(rootView: dashboard)
        self.hostingController = hostingController

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 550)
        popover?.behavior = .transient
        popover?.contentViewController = hostingController
        applyTheme()
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            configurePopoverWindowAppearance()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func configurePopoverWindowAppearance() {
        guard let window = popover?.contentViewController?.view.window else { return }
        window.appearance = settings.theme.nsAppearance
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = false
        window.hasShadow = true
    }

    private func observeThemeChanges() {
        settings.$theme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

    private func observeMonitorToggles() {
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

    private func applyTheme() {
        let appearance = settings.theme.nsAppearance
        hostingController?.view.appearance = appearance
        popover?.appearance = appearance
        popover?.contentViewController?.view.window?.appearance = appearance
    }
    
    private func updateButtonTitle() {
        var parts: [String] = []
        if settings.monitorCPU { parts.append("CPU: \(Int(service.cpuUsage * 100))%") }
        if settings.monitorRAM { parts.append("RAM: \(Int(service.ramUsage * 100))%") }
        if settings.monitorThermal { parts.append(service.thermalState.icon) }
        let title = parts.isEmpty ? (settings.showMenuBarIcon ? "" : "Flyby") : parts.joined(separator: " | ")
        
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.title = title
        }
    }
}
