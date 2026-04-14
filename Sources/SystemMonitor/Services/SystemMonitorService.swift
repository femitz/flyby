import Foundation
import Darwin
import IOKit

final class SystemMonitorService: ObservableObject {
    static let shared = SystemMonitorService()

    @Published var metrics: SystemMetrics = .empty
    @Published var refreshInterval: Double = 5.0

    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?
    private var isRunning = false

    private init() {
        loadSettings()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()
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
            self?.refresh()
        }
    }

    private func refresh() {
        Task { @MainActor in
            let cpu = getCPUMetrics()
            let ram = getRAMMetrics()
            let gpu = await getGPUMetrics()
            let thermal = getThermalState()

            self.metrics = SystemMetrics(
                cpuUsage: cpu,
                ramUsage: ram.usagePercent,
                ramUsedGB: ram.usedGB,
                ramTotalGB: ram.totalGB,
                gpuUsage: gpu,
                thermalState: thermal
            )
        }
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

        let user = Double(cpuLoadInfo.cpu_ticks.0)
        let system = Double(cpuLoadInfo.cpu_ticks.1)
        let idle = Double(cpuLoadInfo.cpu_ticks.2)
        let nice = Double(cpuLoadInfo.cpu_ticks.3)

        let total = user + system + idle + nice
        guard total > 0 else { return 0 }

        var deltaUser: Double = 0
        var deltaSystem: Double = 0

        if let previous = previousCPUInfo {
            deltaUser = user - Double(previous.cpu_ticks.0)
            deltaSystem = system - Double(previous.cpu_ticks.1)
        }

        let deltaTotal = deltaUser + deltaSystem + idle
        let usage = (deltaUser + deltaSystem) / deltaTotal

        previousCPUInfo = cpuLoadInfo

        return min(max(usage, 0), 1)
    }

    private func getRAMMetrics() -> RAMMetrics {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return RAMMetrics(totalGB: 0, usedGB: 0, freeGB: 0, activeGB: 0, inactiveGB: 0, wiredGB: 0, compressedGB: 0)
        }

        let pageSize = Double(vm_kernel_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)

        let active = Double(vmStats.active_count) * pageSize
        let inactive = Double(vmStats.inactive_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize
        let free = Double(vmStats.free_count) * pageSize

        let used = active + wired + compressed
        let total = totalMemory
        let totalGB = total / 1_073_741_824
        let usedGB = used / 1_073_741_824
        let freeGB = free / 1_073_741_824

        return RAMMetrics(
            totalGB: totalGB,
            usedGB: usedGB,
            freeGB: freeGB,
            activeGB: active / 1_073_741_824,
            inactiveGB: inactive / 1_073_741_824,
            wiredGB: wired / 1_073_741_824,
            compressedGB: compressed / 1_073_741_824
        )
    }

    private func getGPUMetrics() async -> Double {
        return await withCheckedContinuation { continuation in
            var gpuUtil = 0

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            task.arguments = ["-l", "-w", "0", "-d", "1", "-n", "AppleARMIODevice", "/AppleM2"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: "\n")
                    for line in lines {
                        if line.contains("gpu-core-count") {
                            if let match = line.range(of: #"gpu-core-count (\d+)"#, options: .regularExpression) {
                                let value = String(line[match]).components(separatedBy: "\"")[1]
                                gpuUtil = Int(value) ?? 0
                            }
                        }
                    }
                }
            } catch {
                // Fallback: estimate based on system load
            }

            continuation.resume(returning: Double(gpuUtil))
        }
    }

    private func getThermalState() -> ThermalState {
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