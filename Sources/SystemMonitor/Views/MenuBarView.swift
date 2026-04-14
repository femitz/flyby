import SwiftUI
import AppKit

final class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let service: SystemMonitorService
    
    @Published var metrics: SystemMetrics = .empty
    
    init(service: SystemMonitorService) {
        self.service = service
        super.init()
        setupStatusBar()
        setupPopover()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 180)
        if let button = statusItem?.button {
            button.title = "CPU: 0% | RAM: 0% | 🟢"
        }
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
            }
        }
    }
    
    private func updateTitle() {
        let cpu = service.metrics.cpuUsagePercent
        let ram = service.metrics.ramUsagePercent
        let thermal = service.metrics.thermalState.icon
        statusItem?.button?.title = "CPU: \(cpu)% | RAM: \(ram)% | \(thermal)"
    }
}