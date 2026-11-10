import Foundation

/// The languages the interface is available in.
enum Language: String, CaseIterable, Identifiable {
    case ptBR = "pt-BR"
    case en

    var id: String { rawValue }

    /// Always written in the language itself, so it can be found whichever one is active.
    var nativeName: String {
        switch self {
        case .ptBR: return "Português (Brasil)"
        case .en: return "English"
        }
    }

    var locale: Locale { Locale(identifier: rawValue == "en" ? "en_US" : "pt_BR") }

    /// What a Mac with no stored choice gets: Portuguese when macOS prefers it, else English.
    static var system: Language {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") == true ? .ptBR : .en
    }

    /// The language the interface is drawn in right now.
    static var current: Language { AppSettings.shared.language }
}

/// Every string the user can read. Each one is written in both languages side by side, so a
/// missing translation cannot slip through. Views redraw on a language change because they
/// observe `AppSettings`; text that outlives a view (an error, a state) is stored as data and
/// turned into a string here, when it is drawn.
///
/// Brand names (Flyby, Vácuo, Lua, Ignição) and units (CPU, RAM, GB, s) are the same in both.
enum L10n {
    private static func tr(_ pt: String, _ en: String) -> String {
        Language.current == .ptBR ? pt : en
    }

    // MARK: Common

    static var back: String { tr("Voltar", "Back") }
    static var quit: String { tr("Sair", "Quit") }
    static var done: String { tr("Concluir", "Done") }
    static var remove: String { tr("Remover", "Remove") }
    static var showInFinder: String { tr("Mostrar no Finder", "Show in Finder") }
    static var openInFinder: String { tr("Abrir no Finder", "Open in Finder") }

    // MARK: Panel

    static var telemetry: String { tr("Telemetria", "Telemetry") }
    static var missionTime: String { tr("Tempo de missão", "Mission time") }
    static var cores: String { tr("núcleos", "cores") }
    static var memory: String { tr("Memória", "Memory") }
    static var thermal: String { tr("Térmico", "Thermal") }
    static var system: String { tr("Sistema", "System") }
    static var mixer: String { "Mixer" }
    static var mainOutput: String { tr("Saída geral", "Main output") }
    static var audioOutput: String { tr("Saída de áudio", "Audio output") }
    static var mixerEmpty: String { tr("Toque áudio em um app e ele aparece aqui.", "Play audio in an app and it shows up here.") }
    static var mixerUnsupported: String { tr("O volume por app exige macOS 14.2 ou mais recente.", "Per-app volume needs macOS 14.2 or later.") }
    static var muted: String { tr("mudo", "muted") }
    static func volume(of name: String) -> String { tr("Volume de \(name)", "\(name) volume") }
    static func unmute(_ name: String) -> String { tr("Ativar som de \(name)", "Unmute \(name)") }
    static func mute(_ name: String) -> String { tr("Silenciar \(name)", "Mute \(name)") }
    static func steadySignal(interval: Int) -> String { tr("Sinal estável · \(interval) s", "Signal steady · \(interval) s") }
    static var preferences: String { tr("Preferências", "Preferences") }
    static var updateAvailable: String { tr("Atualização disponível", "Update available") }

    static func thermalName(_ state: SystemThermalState) -> String {
        switch state {
        case .nominal: return "OK"
        case .fair: return tr("Morno", "Warm")
        case .serious: return tr("Quente", "Hot")
        case .critical: return tr("Crítico", "Critical")
        }
    }

    static func appVolumeError(_ error: AppVolumeError) -> String {
        switch error {
        case .controlFailed(let app, let detail):
            return tr(
                "Não foi possível controlar \(app): \(detail) Permita o Flyby em Ajustes → Privacidade e Segurança → Gravação de Tela e Áudio do Sistema.",
                "Couldn't control \(app): \(detail) Allow Flyby in Settings → Privacy & Security → Screen & System Audio Recording."
            )
        }
    }

    // MARK: Preferences

    static var monitors: String { tr("Monitores", "Monitors") }
    static var perAppVolume: String { tr("Volume por app", "Per-app volume") }
    static var dock: String { "Dock" }
    static var flybyDock: String { tr("Dock do Flyby", "Flyby Dock") }
    static var flybyDockNote: String {
        tr("Substitui o Dock do macOS enquanto estiver ligado. Ao desligar ou sair do Flyby, ele volta como estava.",
           "Replaces the macOS Dock while on. Turn it off or quit Flyby and it comes back as it was.")
    }
    static var dockAutoHide: String { tr("Ocultar automaticamente", "Auto-hide") }
    static var dockOtherProfiles: String { tr("Apps abertos de outros perfis", "Open apps from other profiles") }
    static var profiles: String { tr("Perfis", "Profiles") }
    static var editDockProfiles: String { tr("Editar perfis do Dock", "Edit Dock profiles") }
    static var scrolling: String { tr("Rolagem", "Scrolling") }
    static var reverseMouse: String { tr("Inverter no mouse", "Reverse on mouse") }
    static var reverseTrackpad: String { tr("Inverter no trackpad", "Reverse on trackpad") }
    static var scrollNote: String {
        tr("Inverte em relação à rolagem natural do macOS. Com ela ligada, inverter só o mouse deixa a roda como no Windows e o trackpad como está.",
           "Reverses relative to macOS natural scrolling. With it on, reversing only the mouse gives the wheel Windows-style direction and leaves the trackpad as is.")
    }
    static var accessibilityPrompt: String { tr("Permita o Flyby em Acessibilidade para inverter a rolagem.", "Allow Flyby in Accessibility to reverse scrolling.") }
    static var openSettings: String { tr("Abrir Ajustes", "Open Settings") }
    static var refresh: String { tr("Atualização", "Refresh rate") }
    static var appIcon: String { tr("Ícone do app", "App icon") }
    static func iconAccessibility(_ style: String) -> String { tr("Ícone \(style)", "\(style) icon") }
    static var menuBarIcon: String { tr("Ícone na barra de menus", "Menu bar icon") }
    static var launchAtLogin: String { tr("Abrir ao iniciar sessão", "Open at login") }
    static var language: String { tr("Idioma", "Language") }
    static var appUpdates: String { tr("Atualizações do app", "App updates") }
    static func version(_ value: String) -> String { tr("Versão \(value)", "Version \(value)") }
    static var install: String { tr("Instalar", "Install") }
    static var check: String { tr("Buscar", "Check") }

    static func updateStatus(_ state: UpdateService.State, lastCheck: Date?) -> String {
        switch state {
        case .idle:
            guard let lastCheck else { return tr("Busca automática a cada 5 h.", "Checks automatically every 5 h.") }
            let when = relative(lastCheck)
            return tr("Última busca \(when). Automática a cada 5 h.", "Last checked \(when). Automatic every 5 h.")
        case .checking: return tr("Buscando…", "Checking…")
        case .upToDate: return tr("Você está na versão mais recente.", "You're up to date.")
        case .available(let version): return tr("Versão \(version) disponível.", "Version \(version) available.")
        case .downloading: return tr("Baixando…", "Downloading…")
        case .installing: return tr("Instalando… o Flyby vai reiniciar.", "Installing… Flyby will restart.")
        case .failed(let failure): return updateFailure(failure)
        }
    }

    private static func updateFailure(_ failure: UpdateService.Failure) -> String {
        switch failure {
        case .check:
            return tr("Não foi possível buscar atualizações.", "Couldn't check for updates.")
        case .notInstalled:
            return tr("A atualização automática só funciona no app instalado.", "Automatic update only works in the installed app.")
        case .noPermission(let folder):
            return tr("Sem permissão para atualizar em \(folder).", "No permission to update in \(folder).")
        case .install(let error):
            let reason = updateError(error)
            return tr("Falha ao atualizar: \(reason)", "Update failed: \(reason)")
        }
    }

    private static func updateError(_ error: UpdateService.UpdateError) -> String {
        switch error {
        case .badResponse: return tr("resposta inválida do GitHub", "invalid response from GitHub")
        case .missingAsset: return tr("arquivo da versão não encontrado", "release file not found")
        case .badArchive: return tr("pacote inválido", "invalid package")
        case .checksumMismatch: return tr("verificação de integridade falhou", "integrity check failed")
        case .commandFailed(let tool): return tr("\(tool) falhou", "\(tool) failed")
        case .other(let message): return message
        }
    }

    // MARK: Dock profiles

    static var dockProfiles: String { tr("Perfis do Dock", "Dock profiles") }
    static var dockProfilesNote: String {
        tr("Rolar em cima do Dock troca de perfil. Arraste um app do Finder para o Dock para incluí-lo no perfil ativo.",
           "Scrolling over the Dock switches profile. Drag an app from Finder onto the Dock to add it to the active profile.")
    }
    static var newProfile: String { tr("Novo perfil", "New profile") }
    static func defaultProfileName(_ number: Int) -> String { tr("Perfil \(number)", "Profile \(number)") }
    /// The number in a default profile name ("Perfil 2" or "Profile 2" gives 2), in either language.
    static func defaultProfileNumber(of name: String) -> Int? {
        for prefix in ["Perfil ", "Profile "] where name.hasPrefix(prefix) {
            let rest = name.dropFirst(prefix.count)
            if !rest.isEmpty, rest.allSatisfy(\.isNumber) { return Int(rest) }
        }
        return nil
    }
    static var profileName: String { tr("Nome do perfil", "Profile name") }
    static var useProfile: String { tr("Usar", "Use") }
    static var deleteProfile: String { tr("Apagar perfil", "Delete profile") }
    static func delete(_ name: String) -> String { tr("Apagar \(name)", "Delete \(name)") }
    static var addApps: String { tr("Adicionar apps", "Add apps") }
    static func addApps(to profile: String) -> String { tr("Adicionar apps a \(profile)", "Add apps to \(profile)") }
    static func removeApp(_ name: String) -> String { tr("Remover \(name)", "Remove \(name)") }
    static var removeFromProfile: String { tr("Remover do perfil", "Remove from profile") }
    static var appsFor: String { tr("Apps de", "Apps for") }
    static var searchApps: String { tr("Buscar app", "Search apps") }
    static var findingApps: String { tr("Procurando apps…", "Looking for apps…") }
    static var noAppsFound: String { tr("Nenhum app encontrado", "No apps found") }

    // MARK: Dock

    static func profilePosition(_ index: Int, of count: Int) -> String { tr("Perfil \(index) de \(count)", "Profile \(index) of \(count)") }
    static var running: String { tr("Aberto", "Running") }
    static func removeFrom(_ profile: String) -> String { tr("Remover de \(profile)", "Remove from \(profile)") }
    static func keepIn(_ profile: String) -> String { tr("Manter em \(profile)", "Keep in \(profile)") }
    static var trash: String { tr("Lixeira", "Trash") }
    static var emptyTrash: String { tr("Esvaziar Lixeira", "Empty Trash") }
    static var emptyTrashConfirm: String {
        tr("Apagar permanentemente os itens da Lixeira?", "Permanently erase the items in the Trash?")
    }
    static var emptyTrashConfirmNote: String { tr("Não é possível desfazer esta ação.", "You can't undo this action.") }
    static var cancel: String { tr("Cancelar", "Cancel") }
    static var emptyTrashFailed: String { tr("Não foi possível esvaziar a Lixeira", "Couldn't empty the Trash") }
    static var emptyTrashNeedsPermission: String {
        tr("Permita que o Flyby controle o Finder em Ajustes → Privacidade e Segurança → Automação.",
           "Allow Flyby to control Finder in Settings → Privacy & Security → Automation.")
    }

    // MARK: Downloads

    static var noDownloads: String { tr("Nenhum download", "No downloads") }
    static var noDownloadsAccess: String { tr("Sem acesso à pasta Downloads", "No access to the Downloads folder") }

    // MARK: Formatting

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Language.current.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
