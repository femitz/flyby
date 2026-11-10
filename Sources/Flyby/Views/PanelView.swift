import AppKit
import SwiftUI

/// UI state that outlives a single show/hide of the panel window.
final class PanelState: ObservableObject {
    @Published var showingPreferences = false
    /// The dock profile editor, a page below Preferences.
    @Published var showingDockProfiles = false
    /// Room between the status item and the bottom of the screen, set each time the panel opens.
    @Published var availableHeight: CGFloat = 800
    /// Called with the panel content's size whenever it changes; the controller resizes the window.
    var onSizeChange: ((CGSize) -> Void)?
}

/// The menu bar panel: header, telemetry rings, mixer and footer (see the "Painel na
/// barra de menus" design). Preferences replace the content inside the same panel.
struct PanelView: View {
    @ObservedObject var service: SystemMonitorService
    @ObservedObject var state: PanelState
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var appVolume = AppVolumeService.shared
    @ObservedObject private var output = OutputVolumeService.shared
    @ObservedObject private var updater = UpdateService.shared

    private let maxVisibleMixerRows = 6

    var body: some View {
        Group {
            if state.showingDockProfiles {
                DockProfilesView(onBack: { state.showingDockProfiles = false })
            } else if state.showingPreferences {
                PreferencesView(
                    service: service,
                    maxScrollHeight: state.availableHeight - 40 - 64,   // panel padding, fixed header
                    onBack: { state.showingPreferences = false },
                    onOpenDockProfiles: { state.showingDockProfiles = true }
                )
            } else {
                mainContent
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Brand.casco)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Brand.orbita, lineWidth: 1))
        .preferredColorScheme(.dark)
        // Not a preference: on the macOS 27 SDK, onPreferenceChange at the root of this
        // hosting controller stopped firing after the first value, so Preferences never
        // got a taller window.
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { state.onSizeChange?(proxy.size) }
                .onChange(of: proxy.size) { state.onSizeChange?($0) }
        })
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if !metrics.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    BrandLabel(L10n.telemetry)
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(metrics) { metric in
                            TelemetryRing(
                                fraction: metric.fraction,
                                value: metric.value,
                                label: metric.label,
                                detail: metric.detail
                            )
                        }
                    }
                }
                BrandDivider()
            }

            if settings.monitorAppVolume {
                mixer
                BrandDivider()
            }

            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                FlybyGlyph(ink: Brand.lua, dot: Brand.ignicao, weight: .medium)
                    .frame(width: 24, height: 24)
                Text("flyby")
                    .font(Brand.sans(18, .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Brand.lua)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                BrandLabel(L10n.missionTime)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("T+ \(Self.missionTime(at: context.date))")
                        .font(Brand.mono(14))
                        .foregroundStyle(Brand.lua)
                }
            }
        }
    }

    /// Time since the Mac booted, formatted like "3d 04:12:07".
    private static func missionTime(at date: Date) -> String {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0 else { return "0d 00:00:00" }

        let total = max(0, Int(date.timeIntervalSince1970) - Int(boot.tv_sec))
        let days = total / 86_400
        let hours = (total / 3_600) % 24
        let minutes = (total / 60) % 60
        let seconds = total % 60
        return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
    }

    // MARK: - Telemetry

    private struct Metric: Identifiable {
        let id: String
        let label: String
        let value: String
        let detail: String
        let fraction: Double
    }

    private var metrics: [Metric] {
        var result: [Metric] = []

        if settings.monitorCPU {
            result.append(Metric(
                id: "cpu", label: "CPU",
                value: "\(Int(service.cpuUsage * 100))%",
                detail: "\(ProcessInfo.processInfo.activeProcessorCount) \(L10n.cores)",
                fraction: service.cpuUsage
            ))
        }

        if settings.monitorRAM {
            let locale = settings.language.locale
            let used = service.ramUsedGB.formatted(.number.precision(.fractionLength(1)).locale(locale))
            let total = service.ramTotalGB.formatted(.number.precision(.fractionLength(0)).locale(locale))
            result.append(Metric(
                id: "ram", label: L10n.memory,
                value: "\(Int(service.ramUsage * 100))%",
                detail: "\(used) / \(total) GB",
                fraction: service.ramUsage
            ))
        }

        if settings.monitorThermal {
            result.append(Metric(
                id: "thermal", label: L10n.thermal,
                value: service.thermalState.shortName,
                detail: L10n.system,
                fraction: service.thermalState.fraction
            ))
        }

        return result
    }

    // MARK: - Mixer

    private var mixer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                BrandLabel(L10n.mixer)
                Spacer()
                Text(output.deviceName ?? L10n.audioOutput)
                    .font(Brand.sans(12))
                    .foregroundStyle(Brand.poeira)
                    .lineLimit(1)
            }
            .padding(.bottom, 4)

            if output.isAvailable {
                MixerRow(
                    initials: "Σ",
                    name: L10n.mainOutput,
                    volume: Binding(get: { output.volume }, set: { output.setVolume($0) }),
                    range: 0...1,
                    isMuted: output.isMuted,
                    onToggleMute: { output.setMuted(!output.isMuted) }
                )
            }

            if appVolume.isSupported {
                let rows = appVolume.apps
                if rows.isEmpty {
                    Text(L10n.mixerEmpty)
                        .font(Brand.sans(12))
                        .foregroundStyle(Brand.poeira)
                        .padding(.top, 4)
                } else if rows.count > maxVisibleMixerRows {
                    ScrollView { appRows(rows) }
                        .frame(height: CGFloat(maxVisibleMixerRows) * 50)
                } else {
                    appRows(rows)
                }
            } else {
                Text(L10n.mixerUnsupported)
                    .font(Brand.sans(12))
                    .foregroundStyle(Brand.poeira)
                    .padding(.top, 4)
            }

            if let error = appVolume.error {
                Text(L10n.appVolumeError(error))
                    .font(Brand.sans(11))
                    .foregroundStyle(Brand.ignicao)
                    .padding(.top, 4)
            }
        }
    }

    private func appRows(_ apps: [AudioApp]) -> some View {
        VStack(spacing: 6) {
            ForEach(apps) { app in
                MixerRow(
                    initials: Self.initials(for: app.name),
                    name: app.name,
                    volume: Binding(
                        get: { appVolume.volume(for: app.id) },
                        set: { appVolume.setVolume($0, for: app.id) }
                    ),
                    range: 0...AppVolumeService.maxVolume,
                    isMuted: appVolume.isMuted(app.id),
                    onToggleMute: { appVolume.setMuted(!appVolume.isMuted(app.id), for: app.id) }
                )
            }
        }
    }

    private static func initials(for name: String) -> String {
        let word = name.split(separator: " ").last.map(String.init) ?? name
        return String(word.prefix(2)).capitalized
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L10n.steadySignal(interval: Int(service.refreshInterval)))
                .font(Brand.mono(11))
                .foregroundStyle(Brand.poeira)

            Spacer()

            HStack(spacing: 4) {
                Button {
                    state.showingPreferences = true
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.preferences)
                        if updater.updateAvailable {
                            Circle().fill(Brand.ignicao).frame(width: 6, height: 6)
                                .accessibilityLabel(L10n.updateAvailable)
                        }
                    }
                }
                Button(L10n.quit) { NSApp.terminate(nil) }
            }
            .buttonStyle(BrandButtonStyle())
        }
    }
}

/// One mixer line: initials tile, name + value, slider and a mute button.
struct MixerRow: View {
    let initials: String
    let name: String
    @Binding var volume: Double
    let range: ClosedRange<Double>
    let isMuted: Bool
    let onToggleMute: () -> Void

    /// Not read, but observing it redraws the row (its texts) when the language changes.
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(Brand.mono(12, .medium))
                .foregroundStyle(Brand.lua)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.orbita))

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(Brand.sans(13, .medium))
                        .foregroundStyle(Brand.lua)
                        .lineLimit(1)
                    Spacer()
                    Text(isMuted ? L10n.muted : "\(Int(volume * 100))%")
                        .font(Brand.mono(12))
                        .foregroundStyle(Brand.textSoft)
                }
                BrandSlider(
                    value: $volume,
                    range: range,
                    fill: isMuted ? Brand.muted : Brand.ignicao,
                    accessibilityName: L10n.volume(of: name)
                )
            }

            Button(action: onToggleMute) {
                Image(systemName: isMuted ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isMuted ? Brand.poeira : Brand.lua)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal, -14)
            .accessibilityLabel(isMuted ? L10n.unmute(name) : L10n.mute(name))
        }
        .opacity(isMuted ? 0.6 : 1)
    }
}

