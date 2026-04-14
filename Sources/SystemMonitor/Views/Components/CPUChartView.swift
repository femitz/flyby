import SwiftUI
import Charts

struct CPUChartView: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CPU")
                    .font(.headline)
                Spacer()
                Text("\(metrics.cpuUsagePercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(cpuColor)
            }
            
            Chart {
                BarMark(
                    x: .value("Usage", metrics.cpuUsage),
                    y: .value("Type", "CPU")
                )
                .foregroundStyle(cpuColor.gradient)
                .cornerRadius(4)
            }
            .frame(height: 30)
            .chartYAxis(.hidden)
            
            HStack {
                Label("\(Int(metrics.cpuUsage * 100))% usage", systemImage: "cpu")
                Spacer()
                Text("Normal")
                    .foregroundColor(.green)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var cpuColor: Color {
        if metrics.cpuUsagePercent > 80 {
            return .red
        } else if metrics.cpuUsagePercent > 60 {
            return .orange
        } else if metrics.cpuUsagePercent > 40 {
            return .yellow
        } else {
            return .green
        }
    }
}