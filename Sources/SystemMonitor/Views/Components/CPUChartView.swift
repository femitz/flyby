import SwiftUI
import Charts

struct CPUChartView: View {
    let cpuUsage: Double
    let ramUsage: Double
    let ramUsedGB: Double
    let ramTotalGB: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.headline)
                Spacer()
                Text("\(cpuPercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(cpuColor)
            }
            
            Chart {
                BarMark(
                    x: .value("Usage", cpuUsage),
                    y: .value("Type", "CPU")
                )
                .foregroundStyle(cpuColor.gradient)
                .cornerRadius(4)
            }
            .frame(height: 24)
            .chartYAxis(.hidden)
            
            Divider()
            
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.headline)
                Spacer()
                Text("\(ramPercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ramColor)
            }
            
            HStack {
                Text("\(String(format: "%.1f", ramUsedGB)) GB used of \(String(format: "%.1f", ramTotalGB)) GB")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var cpuPercent: Int { Int(cpuUsage * 100) }
    private var ramPercent: Int { Int(ramUsage * 100) }
    
    private var cpuColor: Color {
        if cpuPercent > 80 { return .red }
        else if cpuPercent > 60 { return .orange }
        else if cpuPercent > 40 { return .yellow }
        else { return .green }
    }
    
    private var ramColor: Color {
        if ramPercent > 90 { return .red }
        else if ramPercent > 75 { return .orange }
        else if ramPercent > 50 { return .yellow }
        else { return .green }
    }
}