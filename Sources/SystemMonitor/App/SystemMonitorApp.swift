import SwiftUI
import AppKit
import ServiceManagement

@main
struct SystemMonitorApp: App {
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
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 550)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: DashboardView(service: service))
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func updateButtonTitle() {
        let cpu = service.metrics.cpuUsagePercent
        let ram = service.metrics.ramUsagePercent
        let thermal = service.metrics.thermalState.icon
        
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.title = "CPU: \(cpu)% | RAM: \(ram)% | \(thermal)"
        }
    }
}