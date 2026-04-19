import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var service: SystemMonitorService
    @State private var selectedInterval: Double = 5.0
    @State private var launchAtLogin: Bool = false
    
    let intervals = [1.0, 2.0, 5.0, 10.0, 30.0]
    
    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    CPUChartView(
                        cpuUsage: service.cpuUsage,
                        ramUsage: service.ramUsage,
                        ramUsedGB: service.ramUsedGB,
                        ramTotalGB: service.ramTotalGB
                    )
                    ThermalStateView(thermalState: service.thermalState)
                    settingsCard
                }
                .padding(18)
            }
            .scrollIndicators(.visible)
        }
        .frame(width: 420, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedInterval = service.refreshInterval
            launchAtLogin = AppSettings.shared.launchAtLogin
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Flyby")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("System overview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(service.thermalState.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(service.thermalState.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(service.thermalState.color.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                statBadge(title: "CPU", value: "\(Int(service.cpuUsage * 100))%")
                statBadge(title: "Memory", value: "\(Int(service.ramUsage * 100))%")
                statBadge(title: "RAM Used", value: String(format: "%.1f GB", service.ramUsedGB))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(alignment: .bottom) {
                    Divider()
                }
        )
    }

    private var settingsCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Preferences")
                    .font(.headline)

                HStack {
                    Text("Refresh interval")
                        .foregroundStyle(.primary)

                    Spacer()

                    Picker("Refresh interval", selection: $selectedInterval) {
                        ForEach(intervals, id: \.self) { interval in
                            Text("\(Int(interval)) seconds").tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: selectedInterval) { newValue in
                        service.updateInterval(newValue)
                    }
                }

                Divider()

                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                        Text("Start Flyby automatically when your Mac signs in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(enabled: newValue)
                }

                Divider()

                HStack {
                    Spacer()

                    Button("Quit Flyby") {
                        quitApp()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private func statBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        AppSettings.shared.launchAtLogin = enabled
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}
