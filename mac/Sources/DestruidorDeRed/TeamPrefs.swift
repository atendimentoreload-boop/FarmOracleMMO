import Foundation

/// Preferências de time/visualização, persistidas em UserDefaults.
enum TeamPrefs {
    private static let teamKey = "team.active"
    private static let emojiKey = "team.emoji"
    private static let farmRouteKey = "farm.route"
    private static let cmStrategyKey = "cynthiaMorimoto.strategy"
    private static let redStrategyKey = "red.strategy"
    private static let hoohStrategyKey = "hooh.strategy"

    static var team: String? {
        get { UserDefaults.standard.string(forKey: teamKey) }
        set { UserDefaults.standard.set(newValue, forKey: teamKey) }
    }

    /// Rota ativa do modo Farm de Ginásios ("veteran" / "lucky_girl"). Padrão: veteran.
    static var farmRoute: String {
        get { UserDefaults.standard.string(forKey: farmRouteKey) ?? "veteran" }
        set { UserDefaults.standard.set(newValue, forKey: farmRouteKey) }
    }

    /// Estratégia/time ativo do modo Cynthia & Morimoto. Padrão: cynthia_morimoto (a 1ª).
    static var cynthiaMorimotoStrategy: String {
        get { UserDefaults.standard.string(forKey: cmStrategyKey) ?? "cynthia_morimoto" }
        set { UserDefaults.standard.set(newValue, forKey: cmStrategyKey) }
    }

    /// Estratégia/time ativo do modo Red ("red" / "red_colored"). Padrão: red (a 1ª).
    static var redStrategy: String {
        get { UserDefaults.standard.string(forKey: redStrategyKey) ?? "red" }
        set { UserDefaults.standard.set(newValue, forKey: redStrategyKey) }
    }

    /// Estratégia/time ativo do modo Ho-Oh ("hooh" / "hooh_trickroom"). Padrão: hooh (a 1ª).
    static var hoohStrategy: String {
        get { UserDefaults.standard.string(forKey: hoohStrategyKey) ?? "hooh" }
        set { UserDefaults.standard.set(newValue, forKey: hoohStrategyKey) }
    }

    static var emoji: Bool {
        get { UserDefaults.standard.bool(forKey: emojiKey) }
        set { UserDefaults.standard.set(newValue, forKey: emojiKey) }
    }

    private static let languageKey = "app.language"

    /// Idioma da interface ("pt" / "en"). Na 1ª abertura segue o idioma do sistema
    /// (PT se o Mac estiver em português; caso contrário, EN). Depois respeita a escolha.
    static var language: String {
        get { UserDefaults.standard.string(forKey: languageKey) ?? deviceDefaultLanguage() }
        set { UserDefaults.standard.set(newValue, forKey: languageKey) }
    }

    /// Idioma do sistema reduzido a "pt"/"en" (default usado só na 1ª abertura).
    static func deviceDefaultLanguage() -> String {
        let pref = Locale.preferredLanguages.first ?? "en"
        return pref.lowercased().hasPrefix("pt") ? "pt" : "en"
    }

    private static let languageChosenKey = "app.languageChosen"

    /// 1ª abertura: `false` até o usuário escolher o idioma na tela inicial (porte do
    /// `langChosen` do Android / `LanguageChosen` do Windows). Depois fica `true` e o
    /// seletor não reaparece. `bool(forKey:)` já devolve `false` por padrão.
    static var languageChosen: Bool {
        get { UserDefaults.standard.bool(forKey: languageChosenKey) }
        set { UserDefaults.standard.set(newValue, forKey: languageChosenKey) }
    }

    private static let seenOverlayGuideKey = "app.seenOverlayGuide"

    /// 1ª abertura (após escolher o idioma): `false` até o guia "Como ler o overlay" (#73)
    /// aparecer uma vez sozinho. Depois fica `true` e a ajuda só reaparece se o usuário tocar
    /// no "?". `bool(forKey:)` já devolve `false` por padrão.
    static var seenOverlayGuide: Bool {
        get { UserDefaults.standard.bool(forKey: seenOverlayGuideKey) }
        set { UserDefaults.standard.set(newValue, forKey: seenOverlayGuideKey) }
    }
}
