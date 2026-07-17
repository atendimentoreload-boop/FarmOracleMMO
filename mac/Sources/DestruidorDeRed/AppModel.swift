import Foundation
import Combine

/// Estado global do app: biblioteca de modos (lutas/rotas) + o modo atualmente selecionado.
/// Cada modo é um `Solve` carregado de um JSON; selecionar um cria um `SolveEngine` novo.
@MainActor
final class AppModel: ObservableObject {
    struct Mode: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let solve: Solve
        /// Retrato de treinador (Resources/trainers) usado como ícone do card. Ex.: "red", "lorelei".
        var portrait: String? = nil
        /// Ícone de item (Resources/items) usado como ícone do card. Ex.: "amulet-coin".
        var item: String? = nil
        /// Sprite de Pokémon (Resources/sprites) que REPRESENTA o time no card. Tem prioridade
        /// sobre portrait/item no card da home. Ex.: Red → "infernape". Não afeta o retrato
        /// usado no topo da luta (esse continua vindo de `portrait`).
        var pokemon: String? = nil
        /// Agrupa modos sob um submenu na tela inicial (ex.: "Elite 4"). Nulo = aparece direto.
        var category: String? = nil
        /// Modo ainda sem conteúdo pronto: mostra o selo "em breve" no card (ex.: Ho-Oh).
        var comingSoon: Bool = false

        /// Link do Poképaste do time deste modo (vem do JSON).
        var pokepaste: String? { solve.pokepaste }
        /// Link do documento oficial (Google Docs) que originou a estratégia (vem do JSON).
        var doc: String? { solve.doc }
    }

    @Published private(set) var modes: [Mode]
    let shortcuts: ShortcutManager
    let skips: SkipStore

    // MARK: - Time ativo / visual

    let teams: TeamsConfig
    @Published private(set) var activeTeamId: String
    @Published private(set) var emojiMode: Bool
    /// Idioma da interface (pt/en). Trocar reconstrói os modos (títulos) e atualiza o global.
    @Published private(set) var language: Lang

    /// Tradução de uma chave no idioma atual (atalho para as views).
    func t(_ key: L) -> String { Strings.text(key, language) }

    var activeTeam: TeamInfo { teams.resolve(activeTeamId) }
    var availableTeams: [TeamInfo] { teams.teams }
    /// O modo Emoji só faz sentido (e só fica ligado) se o time ativo tiver versão emoji.
    var emojiAvailable: Bool { activeTeam.hasEmoji }

    // MARK: - Rotas de Farm de Ginásios (selecionáveis no menu, como os times da Elite 4)

    /// Uma rota de farm: time + solve próprios. Trocável nas Configurações.
    /// Rotas do MESMO `teamGroup` (mesmo time) são agrupadas num submenu; muda só a rota.
    struct FarmRoute: Identifiable {
        let id: String        // nome do arquivo de solve ("veteran" / "6pillars_basic" / "lucky_girl")
        let name: String
        let roster: String
        let pokepaste: String
        /// Sprite de Pokémon que representa a rota no menu (1 Pokémon por time).
        let pokemon: String
        /// Documento oficial (Google Docs) que originou a estratégia.
        let doc: String?
        /// Time a que a rota pertence (agrupa no seletor). Ex.: "six_pillars", "seven_hells".
        let teamGroup: String
        /// Nome curto da variante (mostrado dentro do submenu). Ex.: "Veteran", "BASIC".
        let variant: String
    }

    /// Nome de exibição de um teamGroup (cabeçalho do submenu).
    static func farmTeamName(_ group: String) -> String {
        switch group {
        case "six_pillars": return "Six Pillars"
        case "seven_hells": return "Seven Hells (Lucky Girl)"
        default: return group
        }
    }

    let farmRoutes: [FarmRoute] = [
        FarmRoute(id: "veteran", name: "Six Pillars (Veteran Route)",
                  roster: "Typhlosion, Togekiss, Blastoise, Vanilluxe, Weezing, Garchomp",
                  pokepaste: "https://pokepast.es/f00df8948e58939c", pokemon: "garchomp",
                  doc: "https://docs.google.com/document/d/1XnFfsSVh1x5sEBLzvkletNfBuKY5ymSL_UHKNjoDaeE/edit",
                  teamGroup: "six_pillars", variant: "Veteran"),
        FarmRoute(id: "6pillars_basic", name: "Six Pillars (BASIC Route)",
                  roster: "Typhlosion, Togekiss, Blastoise, Vanilluxe, Weezing, Garchomp",
                  pokepaste: "https://pokepast.es/f00df8948e58939c", pokemon: "garchomp",
                  doc: "https://docs.google.com/document/d/1cWYvyJ7JxlkQqnrIeLZj0l_Yra0JKMuT2dIPwGwNjGA/edit",
                  teamGroup: "six_pillars", variant: "BASIC"),
        FarmRoute(id: "lucky_girl", name: "Seven Hells (Lucky Girl)",
                  roster: "Typhlosion, Blastoise, Vanilluxe, Aerodactyl, Excadrill, Meloetta",
                  pokepaste: "https://pokepast.es/852ceef5515a4f85", pokemon: "meloetta",
                  doc: "https://docs.google.com/document/d/1PINJU34XcRW0hsQ5U9TPkbihCMZFkclspFo4HFHu9XE/edit",
                  teamGroup: "seven_hells", variant: "Lucky Girl"),
    ]

    /// teamGroups na ordem de 1ª aparição (pro seletor agrupar preservando a ordem).
    var farmTeamGroupsOrdered: [String] {
        var seen = Set<String>(); var out: [String] = []
        for r in farmRoutes where !seen.contains(r.teamGroup) { seen.insert(r.teamGroup); out.append(r.teamGroup) }
        return out
    }
    func farmRoutes(in group: String) -> [FarmRoute] { farmRoutes.filter { $0.teamGroup == group } }
    @Published private(set) var activeFarmRouteId: String
    var activeFarmRoute: FarmRoute { farmRoutes.first { $0.id == activeFarmRouteId } ?? farmRoutes[0] }

    // MARK: - Estratégias de Cynthia & Morimoto (selecionáveis no menu, como as rotas de farm)

    /// Uma estratégia/time do modo Cynthia & Morimoto: solve + time próprios. Trocável nas Configurações.
    struct CynthiaMorimotoStrategy: Identifiable {
        let id: String        // nome do arquivo de solve ("cynthia_morimoto", ...)
        let name: String
        let roster: String
        let pokepaste: String
        /// Documento oficial da estratégia (ainda pendente para Cynthia/Morimoto).
        let doc: String?
    }

    /// Estratégias cadastradas. Novas entram aqui + um JSON `<id>.json` (PT + en/).
    let cynthiaMorimotoStrategies: [CynthiaMorimotoStrategy] = [
        CynthiaMorimotoStrategy(id: "cynthia_morimoto", name: "Swellow e Garchomp",
                                roster: "Metagross, Swellow, Umbreon, Garchomp ×2, Slowking",
                                pokepaste: "https://pokepast.es/73afd6d7af99592f", doc: nil),
        CynthiaMorimotoStrategy(id: "cynthia_morimoto_cadozz", name: "cadozz — Torterra/Scyther",
                                roster: "Chansey, Smeargle, Infernape, Torterra, Scyther",
                                pokepaste: "https://pokepast.es/acbe0d2c63e3c68c",
                                doc: "https://forums.pokemmo.com/index.php?/topic/198035-beating-cynthia-fast-a-strategy-guide/"),
    ]
    @Published private(set) var activeCmStrategyId: String
    var activeCmStrategy: CynthiaMorimotoStrategy {
        cynthiaMorimotoStrategies.first { $0.id == activeCmStrategyId } ?? cynthiaMorimotoStrategies[0]
    }

    // MARK: - Estratégias/times do Red (selecionáveis no menu, como Cynthia & Morimoto)

    /// Uma estratégia/time do modo Red: solve + time próprios. Trocável nas Configurações.
    struct RedStrategy: Identifiable {
        let id: String        // nome do arquivo de solve ("red", "red_colored", ...)
        let name: String
        let roster: String
        let pokepaste: String
        /// Documento oficial (Google Docs) que originou a estratégia.
        let doc: String?
        /// Sprite de Pokémon que representa a estratégia no menu (1 por time).
        let pokemon: String
    }

    /// Estratégias cadastradas do Red. Novas entram aqui + um JSON `<id>.json` (PT + en/).
    let redStrategies: [RedStrategy] = [
        RedStrategy(id: "red", name: "Pós Choice Nerf (JinxedBoon)",
                    roster: "Infernape, Weavile, Jolteon, Bisharp, Breloom, Gliscor",
                    pokepaste: "https://pokepast.es/8a207ad044e70c5a",
                    doc: "https://docs.google.com/document/d/1dXaJNGqA2xjUACgcCshcIktBlCjcZgTT839O-Q1pGoA/edit",
                    pokemon: "infernape"),
        RedStrategy(id: "red_colored", name: "Colored (ZzPSYCHOzZ)",
                    roster: "Blissey, Honchkrow, Gliscor, Lapras, Golduck, Breloom",
                    pokepaste: "https://pokepast.es/433ccc371e07d52c",
                    doc: "https://docs.google.com/document/d/1hcpaFvBere2nWb0C61PVqteTeouoNiMMsmln3YLmFk8/edit",
                    pokemon: "blissey"),
    ]
    @Published private(set) var activeRedStrategyId: String
    var activeRedStrategy: RedStrategy {
        redStrategies.first { $0.id == activeRedStrategyId } ?? redStrategies[0]
    }

    /// Uma estratégia/time do modo Ho-Oh (rematch): solve + time próprios. Trocável nas Configurações.
    struct HoohStrategy: Identifiable {
        let id: String        // nome do arquivo de solve ("hooh", "hooh_trickroom", ...)
        let name: String
        let roster: String
        let pokepaste: String
        /// Fonte oficial (vídeo do YouTube) que originou a estratégia.
        let video: String?
        /// Sprite de Pokémon que representa a estratégia no menu (1 por time).
        let pokemon: String
    }

    /// Estratégias cadastradas do Ho-Oh. Novas entram aqui + um JSON `<id>.json` (PT + en/).
    let hoohStrategies: [HoohStrategy] = [
        HoohStrategy(id: "hooh", name: "Allen - Yatsura",
                     roster: "Shuckle, Rotom, Ducklett",
                     pokepaste: "https://pokepast.es/95c7ab2b67af6a1a",
                     video: "https://youtu.be/TR-8IkhyRJE",
                     pokemon: "rotom"),
        HoohStrategy(id: "hooh_trickroom", name: "Trick Room (Lewis Nield)",
                     roster: "Chandelure, Rotom-Heat, Lunatone",
                     pokepaste: "https://pokepast.es/bf35cfea0d1b7356",
                     video: "https://youtu.be/_fcYxnPJKA0",
                     pokemon: "chandelure"),
    ]
    @Published private(set) var activeHoohStrategyId: String
    var activeHoohStrategy: HoohStrategy {
        hoohStrategies.first { $0.id == activeHoohStrategyId } ?? hoohStrategies[0]
    }

    @Published private(set) var engine: SolveEngine?
    @Published private(set) var currentMode: Mode?

    /// Quando preenchido, o app está travado por atualização obrigatória.
    @Published private(set) var forcedUpdate: UpdateInfo?

    var currentTitle: String? { currentMode?.title }

    /// Carrega o manifesto de times + preferências e monta a biblioteca de modos.
    init() throws {
        let cfg = TeamsConfig.load()
        let active = cfg.resolve(TeamPrefs.team).id
        let emoji = TeamPrefs.emoji && cfg.resolve(active).hasEmoji
        let lang = Lang(rawValue: TeamPrefs.language) ?? .pt
        let farmRoute = TeamPrefs.farmRoute
        let cmStrategy = TeamPrefs.cynthiaMorimotoStrategy
        let redStrategy = TeamPrefs.redStrategy
        let hoohStrategy = TeamPrefs.hoohStrategy
        self.teams = cfg
        self.activeTeamId = active
        self.activeFarmRouteId = farmRoute
        self.activeCmStrategyId = cmStrategy
        self.activeRedStrategyId = redStrategy
        self.activeHoohStrategyId = hoohStrategy
        self.emojiMode = emoji
        self.language = lang
        self.shortcuts = ShortcutManager()
        self.skips = SkipStore()
        AppLang.current = lang
        self.modes = try AppModel.buildModes(teams: cfg, teamId: active, emoji: emoji, lang: lang, farmRouteId: farmRoute, cmStrategyId: cmStrategy, redStrategyId: redStrategy, hoohStrategyId: hoohStrategy)
        // O atalho global avança o passo; no fim da luta da Elite 4, vai pro próximo treinador.
        shortcuts.onTrigger = { [weak self] in self?.advanceViaShortcut() }
        // Atalho "Pular parada" (#71): pula a parada atual na rota de farm (se houver pra onde).
        shortcuts.onSkipTrigger = { [weak self] in self?.skipViaShortcut() }
        // F1..F12 selecionam as opções da pergunta "Qual a situação?" (quando houver uma na tela).
        shortcuts.onChoiceKey = { [weak self] idx in self?.chooseChoiceOption(at: idx) ?? false }
    }

    /// Atalho "Próximo": avança o passo/parada; no FIM da luta da Elite 4, pula pro próximo treinador.
    func advanceViaShortcut() {
        guard let engine, !inMenu else { return }
        if engine.showNextButton {
            engine.next()                 // próximo passo / "Próxima parada" (goto)
        } else if engine.isTerminal, engine.nextGroup != nil {
            engine.advanceToNextGroup()   // fim da luta da E4 → próximo treinador
        }
    }

    /// Atalho "Pular parada" (#71): pula a parada atual na rota de farm, quando há pra onde pular.
    func skipViaShortcut() {
        guard let engine, !inMenu, engine.canSkip else { return }
        engine.skip()
    }

    /// (Re)registra os atalhos F1..Fn conforme a escolha atual na tela (ou libera as F-keys).
    func syncChoiceHotkeys() {
        let count: Int
        if let engine, !inMenu, let b = engine.pendingBranch, b.kind == .choice {
            count = b.options?.count ?? 0
        } else {
            count = 0
        }
        shortcuts.syncChoiceHotkeys(count: count)
    }

    /// Times possíveis do adversário no ponto atual do roteiro (pro overlay "Ver times").
    struct PossibleOpponentTeams {
        let teams: [OpponentTeam]
        let confirmed: Bool      // true = sobrou 1 só (time confirmado)
        let trainer: String
        let lead: String
    }

    /// Calcula os times possíveis: base = todos os times do treinador que CONTÊM o lead;
    /// estreitada pelo `lineList` do roteiro (com segurança: filtro que zeraria é ignorado).
    func possibleOpponentTeams() -> PossibleOpponentTeams? {
        guard let engine, !inMenu,
              let region = OpponentCatalog.regionName(modeId: engine.solve.id),
              let group = engine.currentGroupName,
              let lead = engine.pathTrail.first, !lead.isEmpty else { return nil }
        let key = OpponentCatalog.trainerKey(region: region, group: group)
        let all = OpponentCatalog.teams(region: region, trainer: key)
        guard !all.isEmpty else { return nil }
        // Base: times que contêm o lead. Se nenhum casar (nome divergente), cai pra todos.
        let base = all.filter { $0.contains(pokemonNamed: lead) }
        var nums = Set((base.isEmpty ? all : base).map { $0.team })
        // Estreita pelo lineList; só aplica a interseção se ela NÃO zerar (evita filtro incorreto
        // do roteiro apagar todas as possibilidades).
        for set in engine.lineNumberSetsAlongPath() {
            let inter = nums.intersection(set)
            if !inter.isEmpty { nums = inter }
        }
        let teams = all.filter { nums.contains($0.team) }.sorted { $0.team < $1.team }
        guard !teams.isEmpty else { return nil }
        return PossibleOpponentTeams(teams: teams, confirmed: teams.count == 1, trainer: group, lead: lead)
    }

    /// Seleciona a opção da escolha atual pelo índice (atalhos fixos F1..F12).
    /// Retorna `false` se não há escolha na tela ou o índice não existe (a tecla segue para o jogo).
    @discardableResult
    func chooseChoiceOption(at index: Int) -> Bool {
        guard let engine, !inMenu,
              let branch = engine.pendingBranch, branch.kind == .choice,
              let options = branch.options, index < options.count else { return false }
        engine.choose(options[index])
        return true
    }

    // MARK: - Construção dos modos conforme time/visual

    static func buildModes(teams: TeamsConfig, teamId: String, emoji: Bool, lang: Lang, farmRouteId: String, cmStrategyId: String, redStrategyId: String, hoohStrategyId: String) throws -> [Mode] {
        let team = teams.resolve(teamId)
        let useEmoji = emoji && team.hasEmoji

        // Resolve o caminho de um modo: compartilhado (raiz) ou por time (teams/<id>[/emoji]/<nome>).
        func path(_ name: String) -> String {
            if !teams.isTeamScoped(name) || team.id.isEmpty { return name }
            let base = "teams/" + team.id + (useEmoji ? "/emoji" : "")
            return base + "/" + name
        }

        func elite(_ name: String, _ title: String, _ subtitleKey: L) throws -> Mode {
            var solve = try SolveLoader.load(named: path(name), lang: lang)
            solve.pokepaste = team.pokepaste   // botão "?" mostra o Poképaste do time
            return Mode(id: name, title: title, subtitle: Strings.text(subtitleKey, lang),
                        symbol: "crown.fill", solve: solve, category: "Elite 4")
        }

        // A rota Veteran embute a luta de Cynthia & Morimoto no fim. Se o jogador escolheu a
        // estratégia cadozz de C&M, carregamos a variante veteran_cadozz (que injeta o TIME
        // cadozz nessa seção), pra bater com o time selecionado no menu de C&M. #veteran-cadozz
        let farmSolveName = (farmRouteId == "veteran" && cmStrategyId == "cynthia_morimoto_cadozz")
            ? "veteran_cadozz" : farmRouteId

        // A ORDEM aqui é a ordem dos cards na home: Elite 4 (categoria) → Farm → Cynthia &
        // Morimoto → Red → Ho-Oh. O Menu (Configurações) é renderizado à parte pelo picker.
        return [
            try elite("elite4_kanto", "Kanto", .modeElite4KantoSubtitle),
            try elite("elite4_hoenn", "Hoenn", .modeElite4HoennSubtitle),
            try elite("elite4_unova", "Unova", .modeElite4UnovaSubtitle),
            try elite("elite4_sinnoh", "Sinnoh", .modeElite4SinnohSubtitle),
            try elite("elite4_johto", "Johto", .modeElite4JohtoSubtitle),
            // Farm de Ginásios: 1 modo só. A rota ativa (Six Pillars / Seven Hells) é
            // escolhida nas Configurações (TeamPrefs.farmRoute), como os times da Elite 4.
            Mode(id: "veteran", title: Strings.text(.gymFarm, lang),
                 subtitle: Strings.text(.modeGymFarmSubtitle, lang), symbol: "map.fill",
                 solve: try SolveLoader.load(named: farmSolveName, lang: lang), item: "gym"),
            // Cynthia & Morimoto: 1 modo só; a estratégia ativa (o time) é escolhida nas
            // Configurações (TeamPrefs.cynthiaMorimotoStrategy), como as rotas de farm.
            Mode(id: "cynthia_morimoto", title: Strings.text(.modeCynthiaMorimotoTitle, lang),
                 subtitle: Strings.text(.modeCynthiaMorimotoSubtitle, lang), symbol: "person.2.fill",
                 solve: try SolveLoader.load(named: cmStrategyId, lang: lang), portrait: "cynthia"),
            // Red: 1 modo só; a estratégia ativa (o time) vem do redStrategyId (escolhida nas
            // Configurações, como as rotas de farm e o Cynthia & Morimoto).
            Mode(id: "red", title: Strings.text(.modeRedTitle, lang),
                 subtitle: Strings.text(.modeRedSubtitle, lang), symbol: "bolt.fill",
                 solve: try SolveLoader.load(named: redStrategyId, lang: lang), portrait: "red"),
            // Ho-Oh (rematch): 1 modo só; a estratégia ativa (o time) vem do hoohStrategyId
            // (escolhida nas Configurações, como o Red e o Cynthia & Morimoto). O card usa o
            // sprite do próprio Ho-Oh (não tem treinador).
            Mode(id: "hooh", title: Strings.text(.modeHoohTitle, lang),
                 subtitle: Strings.text(.modeHoohSubtitle, lang), symbol: "flame.fill",
                 solve: try SolveLoader.load(named: hoohStrategyId, lang: lang),
                 pokemon: "hooh"),
        ]
    }

    // MARK: - Troca de time / visual

    func setTeam(_ id: String) {
        guard id != activeTeamId else { return }
        activeTeamId = id
        TeamPrefs.team = id
        if !activeTeam.hasEmoji && emojiMode { emojiMode = false; TeamPrefs.emoji = false }
        rebuild()
    }

    /// Troca a rota ativa do Farm de Ginásios (Six Pillars / Seven Hells).
    func setFarmRoute(_ id: String) {
        guard id != activeFarmRouteId, farmRoutes.contains(where: { $0.id == id }) else { return }
        activeFarmRouteId = id
        TeamPrefs.farmRoute = id
        rebuild()
    }

    /// Troca a estratégia ativa do modo Cynthia & Morimoto.
    func setCmStrategy(_ id: String) {
        guard id != activeCmStrategyId, cynthiaMorimotoStrategies.contains(where: { $0.id == id }) else { return }
        activeCmStrategyId = id
        TeamPrefs.cynthiaMorimotoStrategy = id
        rebuild()
    }

    /// Troca a estratégia/time ativo do modo Red (recarrega o solve dela e volta ao menu).
    func setRedStrategy(_ id: String) {
        guard id != activeRedStrategyId, redStrategies.contains(where: { $0.id == id }) else { return }
        activeRedStrategyId = id
        TeamPrefs.redStrategy = id
        rebuild()
    }

    /// Troca a estratégia/time ativo do modo Ho-Oh (recarrega o solve dela e volta ao menu).
    func setHoohStrategy(_ id: String) {
        guard id != activeHoohStrategyId, hoohStrategies.contains(where: { $0.id == id }) else { return }
        activeHoohStrategyId = id
        TeamPrefs.hoohStrategy = id
        rebuild()
    }

    func cycleTeam() {
        guard availableTeams.count > 1 else { return }
        let idx = availableTeams.firstIndex { $0.id == activeTeamId } ?? 0
        setTeam(availableTeams[(idx + 1) % availableTeams.count].id)
    }

    func toggleEmoji() {
        guard activeTeam.hasEmoji else { return }
        emojiMode.toggle()
        TeamPrefs.emoji = emojiMode
        rebuild()
    }

    /// Troca o idioma da interface (recria os modos para traduzir os títulos).
    func setLanguage(_ l: Lang) {
        guard l != language else { return }
        language = l
        AppLang.current = l
        TeamPrefs.language = l.rawValue
        rebuild()
    }

    /// Remonta os modos para o time/visual/idioma atual e volta ao menu.
    private func rebuild() {
        if let m = try? AppModel.buildModes(teams: teams, teamId: activeTeamId, emoji: emojiMode, lang: language, farmRouteId: activeFarmRouteId, cmStrategyId: activeCmStrategyId, redStrategyId: activeRedStrategyId, hoohStrategyId: activeHoohStrategyId) {
            modes = m
        }
        engine = nil
        currentMode = nil
    }

    /// Checa a versão mínima online ao abrir. Fail-open: erro/offline não bloqueia.
    /// Builds de desenvolvimento (debug) NUNCA bloqueiam — só as versões distribuídas (release).
    func checkForcedUpdate() {
        #if DEBUG
        return
        #else
        Task { @MainActor in
            guard let info = await UpdateChecker.fetch(), !info.minimum.isEmpty else { return }
            if UpdateChecker.compare(AppVersion.current, info.minimum) < 0 {
                self.forcedUpdate = info
            }
        }
        #endif
    }

    var inMenu: Bool { engine == nil }

    func select(_ mode: Mode) {
        let newEngine = SolveEngine(solve: mode.solve)
        // IMPORTANTE: usar o id do SOLVE (não o mode.id). O modo Farm tem mode.id fixo "veteran"
        // pra qualquer rota, mas o toggle de pular (HomeView) grava sob engine.solve.id. Com mode.id,
        // o Lucky Girl marca sob "lucky_girl" e o auto-skip procurava sob "veteran" → nunca pulava.
        newEngine.shouldAutoSkip = { [weak self] nodeId in
            self?.skips.isSkipped(mode.solve.id, nodeId) ?? false
        }
        // Foto/nome padrão do modo (usado no topo quando a entrada não tem treinador — ex.: Red).
        newEngine.defaultPortrait = mode.portrait
        newEngine.defaultTrainerName = (mode.id == "red") ? "Red" : mode.title
        engine = newEngine
        currentMode = mode
        syncChoiceHotkeys()   // novo modo: sem escolha ainda → libera F-keys
    }

    func exitToMenu() {
        engine = nil
        currentMode = nil
        syncChoiceHotkeys()   // saiu pro menu → libera F-keys
    }
}
