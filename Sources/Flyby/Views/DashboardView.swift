import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var service: SystemMonitorService
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedInterval: Double = 5.0
    @State private var launchAtLogin: Bool = false
    
    let intervals = [1.0, 2.0, 5.0, 10.0, 30.0]
    
    var body: some View {
        ZStack {
            dashboardBackground
            VStack(spacing: 0) {
                header
                    .zIndex(1)
                scrollContent
            }
        }
        .frame(width: 420, height: 540)
        .preferredColorScheme(settings.theme.colorScheme)
        .onAppear {
            selectedInterval = service.refreshInterval
            launchAtLogin = AppSettings.shared.launchAtLogin
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 18) {
                cardStack
            }
        } else {
            cardStack
        }
    }

    private var cardStack: some View {
        ScrollView {
            VStack(spacing: 16) {
                if settings.monitorCPU || settings.monitorRAM {
                    CPUChartView(
                        cpuUsage: service.cpuUsage,
                        ramUsage: service.ramUsage,
                        ramUsedGB: service.ramUsedGB,
                        ramTotalGB: service.ramTotalGB,
                        showCPU: settings.monitorCPU,
                        showRAM: settings.monitorRAM
                    )
                }
                if settings.monitorThermal {
                    ThermalStateView(thermalState: service.thermalState)
                }
                if settings.monitorAppVolume {
                    AppVolumeView(service: AppVolumeService.shared)
                }
                settingsCard
            }
            .padding(18)
        }
        .scrollIndicators(.visible)
        .clipped()
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

                if settings.monitorThermal {
                    thermalBadge
                }
            }

            HStack(spacing: 16) {
                if settings.monitorCPU {
                    statBadge(title: "CPU", value: "\(Int(service.cpuUsage * 100))%")
                }
                if settings.monitorRAM {
                    statBadge(title: "Memory", value: "\(Int(service.ramUsage * 100))%")
                    statBadge(title: "RAM Used", value: String(format: "%.1f GB", service.ramUsedGB))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(
            headerBackground
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Monitors")
                    monitorToggle("CPU", systemImage: "cpu", isOn: $settings.monitorCPU)
                    monitorToggle("Memory", systemImage: "memorychip", isOn: $settings.monitorRAM)
                    monitorToggle("Thermal state", systemImage: "thermometer.medium", isOn: $settings.monitorThermal)
                    monitorToggle("App volume", systemImage: "speaker.wave.2", isOn: $settings.monitorAppVolume)
                }

                Divider()

                HStack {
                    Text("Appearance")
                        .foregroundStyle(.primary)

                    Spacer()

                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
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

                    quitButton
                }
            }
        }
    }

    private func monitorToggle(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
        }
        .toggleStyle(.switch)
        .onChange(of: isOn.wrappedValue) { _ in
            service.refreshNow()
        }
    }

    private var thermalBadge: some View {
        let label = Text(service.thermalState.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(service.thermalState.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

        return Group {
            if #available(macOS 26, *) {
                label
                    .glassEffect(
                        .regular.tint(service.thermalState.color.opacity(0.2)),
                        in: .capsule
                    )
            } else {
                label
                    .background(service.thermalState.color.opacity(0.14))
                    .clipShape(Capsule())
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

    private var appearanceBinding: Binding<AppTheme> {
        Binding(
            get: { settings.theme },
            set: { settings.setTheme($0) }
        )
    }

    private var quitButton: some View {
        Group {
            if #available(macOS 26, *) {
                Button("Quit Flyby") {
                    quitApp()
                }
                .buttonStyle(.glassProminent)
            } else {
                Button("Quit Flyby") {
                    quitApp()
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
    }

    private var dashboardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 220, height: 220)
                .offset(x: 110, y: -150)

            Circle()
                .fill(service.thermalState.color.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: -130, y: 170)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var headerBackground: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .windowBackgroundColor).opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        AppSettings.shared.launchAtLogin = enabled
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}
