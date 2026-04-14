import SwiftUI

struct ThermalStateView: View {
    let thermalState: SystemThermalState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Thermal State", systemImage: "thermometer")
                    .font(.headline)
                Spacer()
                ThermalIndicator(state: thermalState)
            }
            
            HStack(spacing: 12) {
                ForEach(SystemThermalState.allCases, id: \.self) { state in
                    VStack(spacing: 4) {
                        Text(state.icon)
                            .font(.title2)
                        Text(state.rawValue)
                            .font(.caption2)
                    }
                    .padding(8)
                    .background(state == thermalState ? state.color.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(state == thermalState ? state.color : Color.clear, lineWidth: 2)
                    )
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var description: String {
        switch thermalState {
        case .nominal:
            return "System operating at normal temperature."
        case .fair:
            return "System running warm. Consider reducing workload."
        case .serious:
            return "System is hot. Some resources may be throttled."
        case .critical:
            return "System at critical temperature. Reduce load immediately."
        }
    }
}

struct ThermalIndicator: View {
    let state: SystemThermalState
    
    var body: some View {
        HStack(spacing: 4) {
            Text(state.icon)
            Text(state.rawValue)
                .fontWeight(.semibold)
        }
        .foregroundColor(state.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(state.color.opacity(0.2))
        .cornerRadius(8)
    }
}