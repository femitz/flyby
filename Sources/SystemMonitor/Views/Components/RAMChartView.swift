import SwiftUI
import Charts

struct RAMChartView: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RAM")
                    .font(.headline)
                Spacer()
                Text("\(metrics.ramUsagePercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ramColor)
            }
            
            Chart {
                BarMark(
                    x: .value("Usage", metrics.ramUsagePercent),
                    y: .value("Type", "RAM")
                )
                .foregroundStyle(ramColor.gradient)
                .cornerRadius(4)
                
                BarMark(
                    x: .value("Free", 100 - metrics.ramUsagePercent),
                    y: .value("Type", "Free")
                )
                .foregroundStyle(Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
            .frame(height: 30)
            .chartYAxis(.hidden)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Usado: \(String(format: "%.1f", metrics.ramUsedGB)) GB")
                    Text("Total: \(String(format: "%.1f", metrics.ramTotalGB)) GB")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var ramColor: Color {
        if metrics.ramUsagePercent > 90 {
            return .red
        } else if metrics.ramUsagePercent > 75 {
            return .orange
        } else if metrics.ramUsagePercent > 50 {
            return .yellow
        } else {
            return .green
        }
    }
}