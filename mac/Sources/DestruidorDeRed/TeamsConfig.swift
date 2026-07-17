import Foundation

/// Um time jogável (define qual conjunto de soluções a Elite 4 usa).
struct TeamInfo: Codable, Identifiable {
    let id: String
    let name: String
    /// Sprite usado como ícone do time (Resources/sprites/<icon>.png).
    let icon: String?
    let pokemon: [String]
    let pokepaste: String?
    /// Se o time tem versão "Modo Emoji" (combate na notação original do autor).
    let hasEmoji: Bool
    /// CODE do Pokeking (pokeking.icu) que seleciona este time — mostrado no aviso de "fonte"
    /// dos modos Elite 4 (a fonte deles é o Pokeking + o código, não um Google Docs).
    let code: String?

    init(id: String, name: String, icon: String? = nil,
         pokemon: [String] = [], pokepaste: String? = nil, hasEmoji: Bool = false,
         code: String? = nil) {
        self.id = id; self.name = name; self.icon = icon
        self.pokemon = pokemon; self.pokepaste = pokepaste; self.hasEmoji = hasEmoji
        self.code = code
    }
}

/// Manifesto data/teams.json: lista de times + quais modos variam por time.
struct TeamsConfig: Codable {
    let defaultTeam: String
    let teamScopedModes: [String]
    let teams: [TeamInfo]

    enum CodingKeys: String, CodingKey {
        case defaultTeam = "default"
        case teamScopedModes
        case teams
    }

    func get(_ id: String?) -> TeamInfo? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    func isTeamScoped(_ modeId: String) -> Bool { teamScopedModes.contains(modeId) }

    func resolve(_ id: String?) -> TeamInfo {
        get(id) ?? get(defaultTeam) ?? teams.first ?? TeamInfo(id: "", name: "Padrão")
    }

    static func load() -> TeamsConfig {
        let url = Bundle.module.url(forResource: "teams", withExtension: "json")
        if let url,
           let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(TeamsConfig.self, from: data) {
            return cfg
        }
        return fallback()
    }

    /// Sem manifesto: um único "time" que lê os elite4 da raiz (compat retro).
    private static func fallback() -> TeamsConfig {
        TeamsConfig(defaultTeam: "", teamScopedModes: [],
                    teams: [TeamInfo(id: "", name: "Padrão")])
    }

    init(defaultTeam: String, teamScopedModes: [String], teams: [TeamInfo]) {
        self.defaultTeam = defaultTeam
        self.teamScopedModes = teamScopedModes
        self.teams = teams
    }
}
