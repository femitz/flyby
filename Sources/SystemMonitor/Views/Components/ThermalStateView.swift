import SwiftUI

struct ThermalStateView: View {
    let thermalState: ThermalState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Thermal State")
                    .font(.headline)
                Spacer()
                ThermalIndicator(state: thermalState)
            }
            
            HStack(spacing: 12) {
                ForEach(ThermalState.allCases, id: \.self) { state in
                    VStack(spacing: 4) {
                        Text(state.icon)
                            .font(.title)
                        Text(state.rawValue)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(state == thermalState ? state.colorValue.opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(state == thermalState ? state.colorValue : Color.clear, lineWidth: 2)
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
            return "Sistema operando em temperatura normal."
        case .fair:
            return "Sistema operando com temperatura elevada. Considere reduzir carga de trabalho."
        case .serious:
            return "Sistema quente. Alguns recursos podem estar受限icos."
        case .critical:
            return "Sistema em temperaturas críticas. Reduza a carga imediatamente."
        }
    }
}

struct ThermalIndicator: View {
    let state: ThermalState
    
    var body: some View {
        HStack(spacing: 4) {
            Text(state.icon)
            Text(state.rawValue)
                .fontWeight(.semibold)
        }
        .foregroundColor(state.colorValue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(state.colorValue.opacity(0.2))
        .cornerRadius(8)
    }
}

extension ThermalState {
    var colorValue: Color {
        switch self {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        }
    }
}