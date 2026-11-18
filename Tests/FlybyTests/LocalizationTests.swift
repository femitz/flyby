import Foundation
import Testing
@testable import Flyby

@Suite struct LocalizationTests {
    @Test func stringsFollowTheLanguage() {
        Language.$override.withValue(.ptBR) {
            #expect(L10n.back == "Voltar")
            #expect(L10n.volume(of: "Música") == "Volume de Música")
        }
        Language.$override.withValue(.en) {
            #expect(L10n.back == "Back")
            #expect(L10n.volume(of: "Music") == "Music volume")
        }
    }

    @Test(arguments: [Language.ptBR, .en])
    func defaultProfileNamesRoundTrip(language: Language) {
        Language.$override.withValue(language) {
            for number in [1, 2, 10, 123] {
                #expect(L10n.defaultProfileNumber(of: L10n.defaultProfileName(number)) == number)
            }
        }
    }

    @Test func defaultProfileNumberIsReadInEitherLanguage() {
        #expect(L10n.defaultProfileNumber(of: "Perfil 3") == 3)
        #expect(L10n.defaultProfileNumber(of: "Profile 3") == 3)
    }

    /// A name the user typed must never be renamed when the language changes.
    @Test(arguments: ["Trabalho", "Perfil", "Perfil ", "Perfil 2a", "Meu Perfil 2", "perfil 2", "Profile -1"])
    func customNamesAreNotDefaultNames(name: String) {
        #expect(L10n.defaultProfileNumber(of: name) == nil)
    }

    @Test func updateFailuresIncludeTheReason() {
        Language.$override.withValue(.en) {
            #expect(L10n.updateStatus(.failed(.install(.checksumMismatch)), lastCheck: nil)
                    == "Update failed: integrity check failed")
            #expect(L10n.updateStatus(.failed(.install(.commandFailed(tool: "codesign"))), lastCheck: nil)
                    == "Update failed: codesign failed")
            #expect(L10n.updateStatus(.available(version: "1.2.0"), lastCheck: nil) == "Version 1.2.0 available.")
        }
        Language.$override.withValue(.ptBR) {
            #expect(L10n.updateStatus(.failed(.install(.other("disco cheio"))), lastCheck: nil)
                    == "Falha ao atualizar: disco cheio")
        }
    }

    @Test func languageLocales() {
        #expect(Language.ptBR.locale.identifier == "pt_BR")
        #expect(Language.en.locale.identifier == "en_US")
        #expect(Language(rawValue: "pt-BR") == .ptBR)
    }
}
