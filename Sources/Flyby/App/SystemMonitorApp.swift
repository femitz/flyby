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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hostingController: NSHostingController<DashboardView>?
    private var cancellables = Set<AnyCancellable>()
    private let service = SystemMonitorService.shared
    private let settings = AppSettings.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupPopover()
        observeThemeChanges()
        service.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        service.stop()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 180)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateButtonTitle()
        }
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateButtonTitle()
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

    private func applyTheme() {
        let appearance = settings.theme.nsAppearance
        hostingController?.view.appearance = appearance
        popover?.appearance = appearance
        popover?.contentViewController?.view.window?.appearance = appearance
    }
    
    private func updateButtonTitle() {
        let cpu = Int(service.cpuUsage * 100)
        let ram = Int(service.ramUsage * 100)
        let thermal = service.thermalState.icon
        
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.title = "CPU: \(cpu)% | RAM: \(ram)% | \(thermal)"
        }
    }
}
