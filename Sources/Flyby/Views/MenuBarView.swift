import SwiftUI
import AppKit
import Charts

final class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let service: SystemMonitorService
    
    init(service: SystemMonitorService) {
        self.service = service
        super.init()
        setupStatusBar()
        setupPopover()
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 180)
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: DashboardView(service: service))
    }
    
    @objc func togglePopover() {
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
    
    private func updateTitle() {
        let cpu = Int(service.cpuUsage * 100)
        let ram = Int(service.ramUsage * 100)
        let thermal = service.thermalState.icon
        
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.title = "CPU: \(cpu)% | RAM: \(ram)% | \(thermal)"
        }
    }
}