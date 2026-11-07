import SwiftUI

/// Preferences, shown inside the panel in the same visual language as the main view.
struct PreferencesView: View {
    @ObservedObject var service: SystemMonitorService
    /// Tallest the sections may get before they scroll, so the panel never runs off screen.
    let maxScrollHeight: CGFloat
    let onBack: () -> Void
    let onOpenDockProfiles: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updater = UpdateService.shared
    @ObservedObject private var scrollReverser = ScrollReverserService.shared
    @State private var launchAtLogin = AppSettings.shared.launchAtLogin
    @State private var sectionsHeight: CGFloat = 0
    /// Held by @State without being observed: a scroll only redraws the indicator, not the sections.
    @State private var scrollMetrics = ScrollMetrics()

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

            // The system scroller sits on top of the switches when a mouse is connected,
            // so it is hidden and a thin indicator is drawn in the panel's margin instead.
            ScrollView(.vertical, showsIndicators: false) {
                sections
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GeometryReader { proxy in
                        Color.clear
                            .preference(key: SectionsHeightKey.self, value: proxy.size.height)
                            .preference(key: ScrollOffsetKey.self, value: -proxy.frame(in: .named(Self.scrollSpace)).minY)
                    })
            }
            .coordinateSpace(name: Self.scrollSpace)
            .frame(height: visibleHeight)
            .onPreferenceChange(SectionsHeightKey.self) { sectionsHeight = $0 }
            .onPreferenceChange(ScrollOffsetKey.self) { scrollMetrics.offset = $0 }
            .overlay(alignment: .topTrailing) {
                ScrollIndicator(metrics: scrollMetrics, contentHeight: sectionsHeight, visibleHeight: visibleHeight)
                    .offset(x: 12)
            }
        }
    }

    private static let scrollSpace = "preferencesScroll"

    private var visibleHeight: CGFloat {
        max(0, min(sectionsHeight, maxScrollHeight))
    }


    private var sections: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Monitores") {
                toggle("CPU", isOn: $settings.monitorCPU)
                toggle("Memória", isOn: $settings.monitorRAM)
                toggle("Térmico", isOn: $settings.monitorThermal)
                toggle("Volume por app", isOn: $settings.monitorAppVolume)
            }

            BrandDivider()

            section("Dock") {
                toggle("Dock do Flyby", isOn: $settings.customDockEnabled)
                Text("Substitui o Dock do macOS enquanto estiver ligado. Ao desligar ou sair do Flyby, ele volta como estava.")
                    .font(Brand.sans(12))
                    .foregroundStyle(Brand.poeira)
                    .fixedSize(horizontal: false, vertical: true)
                toggle("Ocultar automaticamente", isOn: $settings.dockAutoHide)
                toggle("Apps abertos de outros perfis", isOn: $settings.dockShowRunningFromOtherProfiles)
                Button(action: onOpenDockProfiles) {
                    HStack {
                        Text("Perfis")
                            .font(Brand.sans(13, .medium))
                            .foregroundStyle(Brand.lua)
                        Spacer()
                        Text("\(DockService.shared.profiles.count)")
                            .font(Brand.mono(12))
                            .foregroundStyle(Brand.poeira)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Brand.poeira)
                    }
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar perfis do Dock")
            }

            BrandDivider()

            section("Rolagem") {
                toggle("Inverter no mouse", isOn: $settings.reverseMouseScroll)
                toggle("Inverter no trackpad", isOn: $settings.reverseTrackpadScroll)
                Text("Inverte em relação à rolagem natural do macOS. Com ela ligada, inverter só o mouse deixa a roda como no Windows e o trackpad como está.")
                    .font(Brand.sans(12))
                    .foregroundStyle(Brand.poeira)
                    .fixedSize(horizontal: false, vertical: true)
                if (settings.reverseMouseScroll || settings.reverseTrackpadScroll) && !scrollReverser.hasPermission {
                    permissionRow
                }
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

            BrandDivider()

            section("Atualizações do app") {
                updateRow
            }
        }
    }

    private var updateRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Versão \(updater.currentVersion)")
                    .font(Brand.sans(13, .medium))
                    .foregroundStyle(Brand.lua)
                Text(updateStatus)
                    .font(Brand.mono(11))
                    .foregroundStyle(updateStatusIsError ? Brand.ignicao : Brand.poeira)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if case .available = updater.state {
                Button("Instalar") { Task { await updater.install() } }
                    .buttonStyle(.plain)
                    .font(Brand.sans(13, .semibold))
                    .foregroundStyle(Brand.vacuo)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.ignicao))
            } else {
                Button("Buscar") { Task { await updater.check() } }
                    .buttonStyle(.plain)
                    .font(Brand.sans(13, .medium))
                    .foregroundStyle(Brand.lua)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Brand.orbita, lineWidth: 1))
                    .disabled(updater.isBusy)
                    .opacity(updater.isBusy ? 0.5 : 1)
            }
        }
    }

    private var permissionRow: some View {
        HStack(spacing: 12) {
            Text("Permita o Flyby em Acessibilidade para inverter a rolagem.")
                .font(Brand.mono(11))
                .foregroundStyle(Brand.ignicao)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Abrir Ajustes") { scrollReverser.openAccessibilitySettings() }
                .buttonStyle(.plain)
                .font(Brand.sans(13, .medium))
                .foregroundStyle(Brand.lua)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Brand.orbita, lineWidth: 1))
        }
    }

    private var updateStatusIsError: Bool {
        if case .failed = updater.state { return true }
        return false
    }

    private var updateStatus: String {
        switch updater.state {
        case .idle:
            return updater.lastCheck.map { "Última busca \(Self.relative($0)). Automática a cada 5 h." } ?? "Busca automática a cada 5 h."
        case .checking: return "Buscando…"
        case .upToDate: return "Você está na versão mais recente."
        case .available(let version): return "Versão \(version) disponível."
        case .downloading: return "Baixando…"
        case .installing: return "Instalando… o Flyby vai reiniciar."
        case .failed(let message): return message
        }
    }

    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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

private struct SectionsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private final class ScrollMetrics: ObservableObject {
    @Published var offset: CGFloat = 0
}

/// A thin thumb drawn in the panel's margin in place of the system scroller.
private struct ScrollIndicator: View {
    @ObservedObject var metrics: ScrollMetrics
    let contentHeight: CGFloat
    let visibleHeight: CGFloat

    var body: some View {
        if contentHeight > visibleHeight + 1, visibleHeight > 0 {
            let thumb = max(24, visibleHeight * visibleHeight / contentHeight)
            let progress = min(max(metrics.offset / (contentHeight - visibleHeight), 0), 1)
            Capsule()
                .fill(Brand.orbita)
                .frame(width: 3, height: thumb)
                .offset(y: progress * (visibleHeight - thumb))
                .accessibilityHidden(true)
        }
    }
}
