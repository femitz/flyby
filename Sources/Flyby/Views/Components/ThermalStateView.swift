import SwiftUI

struct ThermalStateView: View {
    let thermalState: SystemThermalState

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Thermal State", systemImage: "thermometer.medium")
                        .font(.headline)
                    Spacer()
                    ThermalIndicator(state: thermalState)
                }

                HStack(spacing: 10) {
                    ForEach(SystemThermalState.allCases, id: \.self) { state in
                        VStack(spacing: 6) {
                            Text(state.icon)
                                .font(.title3)
                            Text(state.rawValue)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            state == thermalState
                                ? state.color.opacity(0.15)
                                : Color(nsColor: .quaternaryLabelColor).opacity(0.12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    state == thermalState
                                        ? state.color.opacity(0.55)
                                        : Color(nsColor: .separatorColor).opacity(0.35),
                                    lineWidth: 1
                                )
                        )
                    }
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(state.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(state.color.opacity(0.14))
        .clipShape(Capsule())
    }
}
