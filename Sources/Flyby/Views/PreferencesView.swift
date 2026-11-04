import SwiftUI

/// Preferences, shown inside the panel in the same visual language as the main view.
struct PreferencesView: View {
    @ObservedObject var service: SystemMonitorService
    let onBack: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin = AppSettings.shared.launchAtLogin

    private let intervals: [Double] = [1, 2, 5, 10, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button(action: onBack) {
                    Label("Voltar", systemImage: "chevron.left")
                }
                .buttonStyle(BrandButtonStyle())
                .padding(.leading, -14)

                Spacer()

                Text("Preferências")
                    .font(Brand.sans(18, .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Brand.lua)
            }

            section("Monitores") {
                toggle("CPU", isOn: $settings.monitorCPU)
                toggle("Memória", isOn: $settings.monitorRAM)
                toggle("Térmico", isOn: $settings.monitorThermal)
                toggle("Volume por app", isOn: $settings.monitorAppVolume)
            }

            BrandDivider()

            section("Atualização") {
                HStack(spacing: 6) {
                    ForEach(intervals, id: \.self) { interval in
                        let selected = Int(service.refreshInterval) == Int(interval)
                        Button("\(Int(interval)) s") { service.updateInterval(interval) }
                            .buttonStyle(.plain)
                            .font(Brand.mono(12, selected ? .medium : .regular))
                            .foregroundStyle(selected ? Brand.lua : Brand.poeira)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Brand.orbita : Color.clear)
                            )
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            BrandDivider()

            section("Ícone do app") {
                HStack(spacing: 12) {
                    ForEach(AppIconStyle.allCases) { style in
                        iconTile(style)
                    }
                }
                toggle("Ícone na barra de menus", isOn: $settings.showMenuBarIcon)
                    .padding(.top, 4)
            }

            BrandDivider()

            section("Sistema") {
                toggle("Abrir ao iniciar sessão", isOn: Binding(
                    get: { launchAtLogin },
                    set: {
                        launchAtLogin = $0
                        settings.launchAtLogin = $0
                    }
                ))
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandLabel(title)
            content()
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(Brand.sans(13, .medium))
                .foregroundStyle(Brand.lua)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Brand.ignicao)
        }
        .frame(minHeight: 28)
    }

    private func iconTile(_ style: AppIconStyle) -> some View {
        let selected = settings.appIcon == style
        return Button { settings.appIcon = style } label: {
            VStack(spacing: 6) {
                AppIconArtwork(style: style, weight: .medium)
                    .frame(width: 56, height: 56)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? Brand.ignicao : Color.clear, lineWidth: 2)
                    )
                Text(style.displayName)
                    .font(Brand.sans(12, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Brand.lua : Brand.poeira)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ícone \(style.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
