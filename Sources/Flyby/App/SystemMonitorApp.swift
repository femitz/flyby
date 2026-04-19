import SwiftUI
import AppKit
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
    private let service = SystemMonitorService.shared
    private let lightAppearance = NSAppearance(named: .aqua)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupPopover()
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
            .preferredColorScheme(.light)

        let hostingController = NSHostingController(rootView: dashboard)
        hostingController.view.appearance = lightAppearance

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 550)
        popover?.behavior = .transient
        popover?.appearance = lightAppearance
        popover?.contentViewController = hostingController
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
        window.appearance = lightAppearance
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = false
        window.hasShadow = true
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
