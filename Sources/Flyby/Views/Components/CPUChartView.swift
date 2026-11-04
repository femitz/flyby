import SwiftUI

struct CPUChartView: View {
    let cpuUsage: Double
    let ramUsage: Double
    let ramUsedGB: Double
    let ramTotalGB: Double
    var showCPU: Bool = true
    var showRAM: Bool = true
    
    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 18) {
                if showCPU {
                metricSection(
                    title: "CPU",
                    systemImage: "cpu",
                    value: "\(cpuPercent)%",
                    subtitle: "Current processor usage",
                    color: cpuColor,
                    fraction: cpuUsage
                )
                }

                if showCPU && showRAM {
                    Divider()
                }

                if showRAM {
                metricSection(
                    title: "Memory",
                    systemImage: "memorychip",
                    value: "\(ramPercent)%",
                    subtitle: "\(String(format: "%.1f", ramUsedGB)) GB of \(String(format: "%.1f", ramTotalGB)) GB in use",
                    color: ramColor,
                    fraction: ramUsage
                )
                }
            }
        }
    }
    
    private var cpuPercent: Int { Int(cpuUsage * 100) }
    private var ramPercent: Int { Int(ramUsage * 100) }

    @ViewBuilder
    private func metricSection(
        title: String,
        systemImage: String,
        value: String,
        subtitle: String,
        color: Color,
        fraction: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                Spacer()

                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }

            Capsule()
                .fill(Color(nsColor: .separatorColor).opacity(0.35))
                .frame(height: 9)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(12, 340 * fraction), height: 9)
                }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var cpuColor: Color {
        if cpuPercent > 80 {
            return .red
        } else if cpuPercent > 60 {
            return .orange
        } else if cpuPercent > 40 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var ramColor: Color {
        if ramPercent > 90 {
            return .red
        } else if ramPercent > 75 {
            return .orange
        } else if ramPercent > 50 {
            return .yellow
        } else {
            return .green
        }
    }
}
