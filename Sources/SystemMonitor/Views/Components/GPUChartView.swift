import SwiftUI
import Charts

struct GPUChartView: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GPU")
                    .font(.headline)
                Spacer()
                Text("\(metrics.gpuUsagePercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(gpuColor)
            }
            
            Chart {
                BarMark(
                    x: .value("Usage", metrics.gpuUsage),
                    y: .value("Type", "GPU")
                )
                .foregroundStyle(gpuColor.gradient)
                .cornerRadius(4)
            }
            .frame(height: 30)
            .chartYAxis(.hidden)
            
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.secondary)
                Text("Apple Silicon (M2)")
                    .foregroundColor(.secondary)
                Spacer()
                Text("Best effort")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var gpuColor: Color {
        if metrics.gpuUsagePercent > 80 {
            return .red
        } else if metrics.gpuUsagePercent > 60 {
            return .orange
        } else if metrics.gpuUsagePercent > 40 {
            return .yellow
        } else {
            return .green
        }
    }
}