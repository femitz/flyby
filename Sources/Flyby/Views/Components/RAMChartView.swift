import SwiftUI
import Charts

struct RAMChartView: View {
    let ramUsage: Double
    let ramUsedGB: Double
    let ramTotalGB: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.headline)
                Spacer()
                Text("\(ramPercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(ramColor)
            }
            
            Chart {
                BarMark(
                    x: .value("Usage", ramUsage),
                    y: .value("Type", "RAM")
                )
                .foregroundStyle(ramColor.gradient)
                .cornerRadius(4)
                
                BarMark(
                    x: .value("Free", 1.0 - ramUsage),
                    y: .value("Type", "Free")
                )
                .foregroundStyle(Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
            .frame(height: 24)
            .chartYAxis(.hidden)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Used: \(String(format: "%.1f", ramUsedGB)) GB")
                    Text("Total: \(String(format: "%.1f", ramTotalGB)) GB")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var ramPercent: Int { Int(ramUsage * 100) }
    
    private var ramColor: Color {
        if ramPercent > 90 { return .red }
        else if ramPercent > 75 { return .orange }
        else if ramPercent > 50 { return .yellow }
        else { return .green }
    }
}