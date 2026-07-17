import Foundation

// Modelo do sistema de Cooldown/Alarme (#33).
// - CATÁLOGO: templates lidos de `data/cooldowns.json` (batalhas, tiers de berry, 64 berries).
// - ESTADO: o que o usuário criou/marcou (personagens + marcações), salvo em UserDefaults.
//
// Regra de robustez: a VERDADE é sempre um timestamp absoluto (epoch em MILISSEGUNDOS, igual ao
// protótipo/sync). Contador e alarme são derivados; reconciliar no startup a partir dos timestamps.

/// Milissegundos desde 1970 (mesma base do protótipo web e do futuro sync).
func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

/// Nome bilíngue (PT/EN) vindo do catálogo.
struct LocalizedName: Codable, Equatable {
    var pt: String
    var en: String
    var localized: String { AppLang.current == .en ? en : pt }
}

// MARK: - Catálogo (data/cooldowns.json)

/// Tarefa de batalha com cooldown simples (um timer).
struct BattleTask: Codable, Identifiable, Equatable {
    var id: String
    var category: String
    var name: LocalizedName
    var hours: Double
    var color: String
    var confidence: String
    var defaultOn: Bool
    /// Especificação do ícone: "region:x" | "trainer:x" | "item:x" | "sprite:x" | "sf:símbolo".
    /// Opcional (nil = cai no ponto colorido). (campos extras type/note/source são ignorados.)
    var icon: String?
    /// Agrupador na UI (ex.: "elite4" junta as 5 ligas num submenu). nil = tarefa avulsa.
    var group: String?
}

/// Tier de berry: guarda a matemática do ciclo (uma vez), compartilhada por várias berries.
struct BerryTier: Codable, Identifiable, Equatable {
    var tier: String
    var growthHours: Double        // plantar -> pronta pra colher (fixo)
    var wiltHours: Double          // janela de colheita depois de pronta
    var waterWindowsHours: [Double] // limite (h após plantar) de cada rega
    var waterLeadHours: Double      // disparar o lembrete tantas h ANTES do limite (adiantar é seguro)
    var yield: String
    var id: String { tier }
}

/// Uma berry específica (nome/ícone) que aponta pro seu tier.
struct BerryDef: Codable, Identifiable, Equatable {
    var id: String
    var tier: String
    var name: LocalizedName
    var popular: Bool
    var defaultOn: Bool
}

/// O catálogo-semente inteiro.
struct CooldownCatalog: Codable {
    var battleTasks: [BattleTask]
    var optionalTasks: [BattleTask]
    var berryTiers: [BerryTier]
    var berries: [BerryDef]

    static let empty = CooldownCatalog(battleTasks: [], optionalTasks: [], berryTiers: [], berries: [])

    /// Todas as tarefas de batalha (obrigatórias + opcionais).
    var allBattle: [BattleTask] { battleTasks + optionalTasks }

    func battleTask(_ id: String) -> BattleTask? { allBattle.first { $0.id == id } }
    func berry(_ id: String) -> BerryDef? { berries.first { $0.id == id } }
    func tier(_ id: String) -> BerryTier? { berryTiers.first { $0.tier == id } }

    static func loadFromBundle() -> CooldownCatalog {
        guard let url = Bundle.module.url(forResource: "cooldowns", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cat = try? JSONDecoder().decode(CooldownCatalog.self, from: data)
        else { return .empty }
        return cat
    }
}

// MARK: - Estado do usuário (persistido)

/// Um "boneco" (conta/ALT) cadastrado pelo usuário.
struct GameCharacter: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// Foto do ícone (PNG 128×128 em base64). nil = usa o monograma (1ª letra). Opcional pra
    /// não quebrar estados antigos e já viajar no blob de sync.
    var avatar: String? = nil
}

/// Progresso de uma berry plantada num canteiro. `plantedAt` é a verdade — tudo (colheita, wilt,
/// janelas de rega) deriva dele + do tier. `waterings` = quantas regas o usuário já confirmou.
struct BerryProgress: Codable, Equatable {
    var plantedAt: Double   // ms
    var waterings: Int
}

/// Estado completo do usuário. Salvo como um único blob JSON (preparado pra sync futuro).
struct CooldownState: Codable {
    var version: Int
    var characters: [GameCharacter]
    /// "charId:battleTaskId" -> ms da marcação.
    var battle: [String: Double]
    /// "charId:berryId:plot" -> progresso.
    var berry: [String: BerryProgress]
    /// Ids de tarefas de batalha que o usuário DESATIVOU (as defaultOn começam ligadas).
    var hiddenBattle: [String]
    /// Ids de berries que o usuário ATIVOU além das defaultOn.
    var enabledBerry: [String]
    var updatedAt: Double

    static let current = CooldownState(version: 2, characters: [], battle: [:], berry: [:],
                                       hiddenBattle: [], enabledBerry: [], updatedAt: 0)

    // Decoder tolerante: campos ausentes (versões antigas / campos novos) não quebram.
    enum CodingKeys: String, CodingKey {
        case version, characters, battle, berry, hiddenBattle, enabledBerry, updatedAt
    }
    init(version: Int, characters: [GameCharacter], battle: [String: Double],
         berry: [String: BerryProgress], hiddenBattle: [String], enabledBerry: [String], updatedAt: Double) {
        self.version = version; self.characters = characters; self.battle = battle
        self.berry = berry; self.hiddenBattle = hiddenBattle; self.enabledBerry = enabledBerry
        self.updatedAt = updatedAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 2
        characters = (try? c.decode([GameCharacter].self, forKey: .characters)) ?? []
        battle = (try? c.decode([String: Double].self, forKey: .battle)) ?? [:]
        berry = (try? c.decode([String: BerryProgress].self, forKey: .berry)) ?? [:]
        hiddenBattle = (try? c.decode([String].self, forKey: .hiddenBattle)) ?? []
        enabledBerry = (try? c.decode([String].self, forKey: .enabledBerry)) ?? []
        updatedAt = (try? c.decode(Double.self, forKey: .updatedAt)) ?? 0
    }
}
