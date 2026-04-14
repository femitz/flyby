import Foundation
import Darwin
import IOKit
import SwiftUI

final class SystemMonitorService: ObservableObject {
    static let shared = SystemMonitorService()

    @Published var cpuUsage: Double = 0
    @Published var ramUsage: Double = 0
    @Published var ramUsedGB: Double = 0
    @Published var ramTotalGB: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var thermalState: SystemThermalState = .nominal
    
    @Published var refreshInterval: Double = 5.0

    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?
    private var isRunning = false
    private var isRefreshing = false

    private init() {
        loadSettings()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // Primeiro refresh síncrono para ter dados iniciais
        let (cpu, ram, thermal) = gatherMetricsSync()
        cpuUsage = cpu
        ramUsage = ram.usagePercent
        ramUsedGB = ram.usedGB
        ramTotalGB = ram.totalGB
        thermalState = thermal
        
        // Iniciar timer para atualizaões periódicas
        startTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(_ interval: Double) {
        refreshInterval = interval
        saveSettings()
        if isRunning {
            timer?.invalidate()
            startTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshAsync()
        }
    }

    private func refreshAsync() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        Task { @MainActor in
            let (cpu, ram, thermal) = await self.gatherMetricsAsync()
            self.cpuUsage = cpu
            self.ramUsage = ram.usagePercent
            self.ramUsedGB = ram.usedGB
            self.ramTotalGB = ram.totalGB
            self.thermalState = thermal
            self.isRefreshing = false
        }
    }

    private func gatherMetricsSync() -> (Double, RAMInfo, SystemThermalState) {
        let cpu = getCPUMetrics()
        let ram = getRAMMetrics()
        let thermal = getThermalState()
        return (cpu, ram, thermal)
    }

    private func gatherMetricsAsync() async -> (Double, RAMInfo, SystemThermalState) {
        let cpu = getCPUMetrics()
        let ram = getRAMMetrics()
        let thermal = getThermalState()
        return (cpu, ram, thermal)
    }

    private func getCPUMetrics() -> Double {
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let currentUser = Double(cpuLoadInfo.cpu_ticks.0)
        let currentSystem = Double(cpuLoadInfo.cpu_ticks.1)
        let currentIdle = Double(cpuLoadInfo.cpu_ticks.2)
        let currentNice = Double(cpuLoadInfo.cpu_ticks.3)

        // Primeira leitura - inicializar previous
        guard let previous = previousCPUInfo else {
            previousCPUInfo = cpuLoadInfo
            return 0
        }

        let prevUser = Double(previous.cpu_ticks.0)
        let prevSystem = Double(previous.cpu_ticks.1)
        let prevIdle = Double(previous.cpu_ticks.2)
        let prevNice = Double(previous.cpu_ticks.3)

        // Calcular deltas
        let deltaUser = max(0, currentUser - prevUser)
        let deltaSystem = max(0, currentSystem - prevSystem)
        let deltaIdle = max(0, currentIdle - prevIdle)
        let deltaNice = max(0, currentNice - prevNice)

        let deltaTotal = deltaUser + deltaSystem + deltaIdle + deltaNice
        
        previousCPUInfo = cpuLoadInfo

        guard deltaTotal > 0 else { return 0 }
        
        return min((deltaUser + deltaSystem + deltaNice) / deltaTotal, 1.0)
    }

    private func getRAMMetrics() -> RAMInfo {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return RAMInfo(totalGB: 0, usedGB: 0, freeGB: 0)
        }

        let pageSize: Double = 4096
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalMemory / 1_073_741_824

        // wired + active + compressor - purgeable
        let wiredPages = Double(vmStats.wire_count)
        let activePages = Double(vmStats.active_count)
        let compressorPages = Double(vmStats.compressor_page_count)
        let purgeablePages = Double(vmStats.purgeable_count)

        let usedPages = wiredPages + activePages + compressorPages - purgeablePages
        let usedMemory = usedPages * pageSize
        let usedGB = usedMemory / 1_073_741_824
        let freeGB = (totalMemory - usedMemory) / 1_073_741_824

        return RAMInfo(totalGB: totalGB, usedGB: usedGB, freeGB: freeGB)
    }

    private func getThermalState() -> SystemThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .nominal
        }
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        refreshInterval = defaults.double(forKey: "refreshInterval")
        if refreshInterval == 0 {
            refreshInterval = 5.0
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(refreshInterval, forKey: "refreshInterval")
    }
}

struct RAMInfo {
    var totalGB: Double
    var usedGB: Double
    var freeGB: Double

    var usagePercent: Double {
        guard totalGB > 0 else { return 0 }
        return usedGB / totalGB
    }
}

enum SystemThermalState: String, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    var icon: String {
        switch self {
        case .nominal: return "●"
        case .fair: return "◐"
        case .serious: return "◑"
        case .critical: return "◉"
        }
    }

    var color: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}