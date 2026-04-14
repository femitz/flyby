import Foundation

struct SystemMetrics {
    var cpuUsage: Double
    var ramUsage: Double
    var ramUsedGB: Double
    var ramTotalGB: Double
    var gpuUsage: Double
    var thermalState: ThermalState

    var cpuUsagePercent: Int { Int(cpuUsage * 100) }
    var ramUsagePercent: Int { Int(ramUsage * 100) }
    var gpuUsagePercent: Int { Int(gpuUsage * 100) }

    static var empty: SystemMetrics {
        SystemMetrics(
            cpuUsage: 0,
            ramUsage: 0,
            ramUsedGB: 0,
            ramTotalGB: 0,
            gpuUsage: 0,
            thermalState: .nominal
        )
    }
}

enum ThermalState: String, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    var icon: String {
        switch self {
        case .nominal: return "🟢"
        case .fair: return "🟡"
        case .serious: return "🟠"
        case .critical: return "🔴"
        }
    }

    var color: String {
        switch self {
        case .nominal: return "green"
        case .fair: return "yellow"
        case .serious: return "orange"
        case .critical: return "red"
        }
    }
}

struct CPUMetrics {
    var user: Double
    var system: Double
    var idle: Double
    var nice: Double

    var total: Double { user + system + idle + nice }
}

struct RAMMetrics {
    var totalGB: Double
    var usedGB: Double
    var freeGB: Double
    var activeGB: Double
    var inactiveGB: Double
    var wiredGB: Double
    var compressedGB: Double

    var usagePercent: Double {
        guard totalGB > 0 else { return 0 }
        return usedGB / totalGB
    }
}

struct GPUMetrics {
    var usage: Double
    var deviceUtilization: Int
    var rendererUtilization: Int
    var tilerUtilization: Int

    var usagePercent: Double {
        Double(deviceUtilization) / 100.0
    }
}