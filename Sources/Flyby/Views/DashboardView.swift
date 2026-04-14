import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var service: SystemMonitorService
    @State private var selectedInterval: Double = 5.0
    @State private var launchAtLogin: Bool = false
    
    let intervals = [1.0, 2.0, 5.0, 10.0, 30.0]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Flyby")
                .font(.title)
                .fontWeight(.bold)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    CPUChartView(
                        cpuUsage: service.cpuUsage,
                        ramUsage: service.ramUsage,
                        ramUsedGB: service.ramUsedGB,
                        ramTotalGB: service.ramTotalGB
                    )
                    ThermalStateView(thermalState: service.thermalState)
                }
                .padding()
            }
            
            Divider()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Refresh:")
                        .foregroundColor(.secondary)
                    Picker("", selection: $selectedInterval) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(Int(interval))s").tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    .onChange(of: selectedInterval) { newValue in
                        service.updateInterval(newValue)
                    }
                }
                .padding(.horizontal)
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .padding(.horizontal)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            selectedInterval = service.refreshInterval
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        AppSettings.shared.launchAtLogin = enabled
    }
}