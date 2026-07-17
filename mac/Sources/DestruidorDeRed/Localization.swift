import Foundation

/// Idioma da interface. O conteúdo das lutas (JSON) é tratado à parte.
enum Lang: String, CaseIterable {
    case pt, en
}

/// Idioma atual da UI (global). Mantido em sincronia com `AppModel.language` para que
/// telas SEM acesso ao `AppModel` (subviews, NSViews, helpers estáticos, mensagens de erro)
/// também traduzam. Trocar de idioma sempre acontece no Menu e recria as telas de jogo, então
/// ler o global é suficiente — não precisa observar. Escrito só na main thread.
enum AppLang {
    nonisolated(unsafe) static var current: Lang = Lang(rawValue: TeamPrefs.language) ?? .pt
}

/// Tradução de uma chave para o idioma atual.
func tr(_ key: L) -> String { Strings.text(key, AppLang.current) }

/// Chaves de texto da interface (apenas strings cujo EN difere do PT são roteadas;
/// tokens idênticos nos dois idiomas — "Menu", "Overlay", "ON/OFF", "Elite 4", "v%@" — ficam literais).
enum L: String {
    // Compartilhadas
    case back, cancel, none

    // ContentView / shell
    case updateRequiredTitle, updateRequiredBody, downloadUpdate, close
    case switchModeHelp, helpAndLegendHelp, lessOpacityHelp, moreOpacityHelp
    case clickThroughHelp, minimizeHelp, restart, stepProgress
    case capturePressKey, captureHint
    case loadErrorTitle
    case miniBallTooltip, unlockPillLabel

    // SettingsView (Menu)
    case shortcut, language, teams, defaultTeam, gymFarm, emojiMode
    case options, general, navNextShortcut, portuguese, about, version, developedBy, thanksTo
    case opacity, comingSoon, pasteHelp, docHelp
    case pokekingBody, copyCode, openPokeking, docNotFoundTitle, docNotFoundBody

    // ModePicker
    case modePickerPrompt, categorySubtitle, settingsCardSubtitle

    // LegendView
    case legendGlossary, legendWindowShortcuts, legendDragKey, legendDragDesc
    case legendOpacityDesc, legendClickThroughDesc
    case legendHowToTitle, legendHowToArrow, legendHowToIcons, legendHowToChoose
    case legendNewbieTitle, legendNewbieBody, legendGotIt
    case shortcutTitle, shortcutDescription, shortcutCurrent
    case shortcutSet, shortcutChange, shortcutClear
    case shortcutAccessWarning, shortcutGrant
    case navSkipShortcut, shortcutSkipDescription

    // HomeView
    case homeGroupPromptDefault, searchCity, searchPokemon, searchNoResults
    case citySkipUncheckHelp, citySkipMarkHelp, citySkipBadge, showSkipped, hideSkipped, flatHomePromptDefault

    // NodeView
    case opponentOnField, gymLeadWith, nextGym, nextLeadLabel, skipThisStop
    case seeTeamsConfirmed, seeTeamsPossible, stepSetupBadge, stepNoteBadge
    case next, nextStop, continueLabel, opponentHeaderFacing
    case feedbackThanksOk, feedbackThanksFail, feedbackFailPrompt, send
    case feedbackWorked, feedbackDidntWork, nextTrainerBadge
    case leagueCompleted, terminalBadge

    // ChoiceView / ConditionalTableView
    case choicePromptDefault, conditionalTableTitleDefault

    // TeamsOverlayView
    case teamsDistinguishHint, teamsConfirmedTitle, teamsPossibleTitle, teamsTeamCardTitle

    // AppModel (modos)
    case modeRedTitle, modeRedSubtitle, modeGymFarmSubtitle
    case modeElite4KantoSubtitle, modeElite4HoennSubtitle, modeElite4UnovaSubtitle
    case modeElite4SinnohSubtitle, modeElite4JohtoSubtitle
    case modeCynthiaMorimotoTitle, modeCynthiaMorimotoSubtitle, modeHoohTitle, modeHoohSubtitle

    // ShortcutManager / SolveLoader
    case keyNameSpace, keyNameUnknownFallback, errorSolveFileNotFound

    // CooldownView (sistema de CD/alarme #33)
    case cdTitle, cdReloginhoHelp, cdCharacters, cdNoCharacters, cdCharacterName, cdAdd, cdActiveCount
    case cdBattles, cdBerries, cdOptional, cdDoNow, cdClear
    case cdEmpty, cdPlant, cdWaterNow, cdWatered, cdHarvest, cdHarvestNow, cdHarvestIn, cdWilted
    case cdAddBerry, cdTierLabel, cdRenameTitle, cdRemove, cdRemoveConfirm
    case cdNotifReady, cdNotifCharacter, cdNotifWater, cdNotifBerryReady, cdNotifWilt
    case cdElite4, cdReset, cdTapToStart, cdRunning, cdWaterIn, cdWaterDone, cdRemoveBerry
    case cdNextWater, cdHarvestShort, cdAllWatered, cdReadyLabel
    case cdPhoto, cdChoosePhoto, cdChangePhoto, cdRemovePhoto, cdPhotoHint
}

enum Strings {
    static func text(_ key: L, _ lang: Lang) -> String {
        switch lang {
        case .en: return en[key] ?? pt[key] ?? key.rawValue
        case .pt: return pt[key] ?? key.rawValue
        }
    }

    static let pt: [L: String] = [
        .back: "Voltar", .cancel: "Cancelar", .none: "nenhum",

        // Cooldowns (#33)
        .cdTitle: "Cooldowns", .cdReloginhoHelp: "Cooldowns e alarmes",
        .cdCharacters: "Personagens", .cdNoCharacters: "Nenhum boneco ainda.\nAdicione o primeiro 👇",
        .cdCharacterName: "Nome do boneco (ex: Vinicios1)", .cdAdd: "Adicionar", .cdActiveCount: "%d ativo(s)",
        .cdBattles: "Batalhas", .cdBerries: "Berries", .cdOptional: "Opcionais",
        .cdDoNow: "✓ Fazer agora", .cdClear: "Limpar",
        .cdEmpty: "Vazio — plantar", .cdPlant: "Plantar", .cdWaterNow: "Regar agora",
        .cdWatered: "Reguei", .cdHarvest: "Colher", .cdHarvestNow: "✓ Colher agora",
        .cdHarvestIn: "Colher em %@", .cdWilted: "Murchou — colha!",
        .cdAddBerry: "Adicionar berry", .cdTierLabel: "Cresce em %dh",
        .cdRenameTitle: "Novo nome do boneco:", .cdRemove: "Remover",
        .cdRemoveConfirm: "Remover o boneco \"%@\"? Isso apaga os cooldowns dele.",
        .cdNotifReady: "%@ liberou! ⚔️", .cdNotifCharacter: "Boneco: %@",
        .cdNotifWater: "💧 Hora de regar %@", .cdNotifBerryReady: "🌱 %@ pronta pra colher",
        .cdNotifWilt: "⚠️ %@ vai murchar — colha!",
        .cdElite4: "Elite 4", .cdReset: "Resetar", .cdTapToStart: "Tocar para iniciar o CD",
        .cdRunning: "Em cooldown", .cdWaterIn: "Regar em %@", .cdWaterDone: "Regas %d/%d",
        .cdRemoveBerry: "Remover berry",
        .cdNextWater: "Próxima rega", .cdHarvestShort: "Colheita",
        .cdAllWatered: "Regas concluídas", .cdReadyLabel: "Liberado",
        .cdPhoto: "Foto…", .cdChoosePhoto: "Escolher foto…", .cdChangePhoto: "Trocar foto…",
        .cdRemovePhoto: "Remover foto", .cdPhotoHint: "A imagem é reduzida pra um ícone de 128×128.",

        .updateRequiredTitle: "Atualização obrigatória",
        .updateRequiredBody: "Você está na v%@. A versão mínima agora é v%@.\nBaixe a nova para continuar.",
        .downloadUpdate: "Baixar atualização", .close: "Fechar",
        .switchModeHelp: "Trocar de modo (Red / Rota de Farm)",
        .helpAndLegendHelp: "Ajuda e legenda",
        .lessOpacityHelp: "Menos opacidade", .moreOpacityHelp: "Mais opacidade",
        .clickThroughHelp: "Deixar cliques passarem para o jogo (⌥⌘L)",
        .minimizeHelp: "Minimizar (vira uma Master Ball)",
        .restart: "Reiniciar", .stepProgress: "passo %d/%d",
        .capturePressKey: "Aperte a tecla do atalho",
        .captureHint: "Pode combinar com ⌘ ⌥ ⌃ ⇧.\nEsc para cancelar.",
        .loadErrorTitle: "Não consegui carregar os roteiros",
        .miniBallTooltip: "Duplo-clique para abrir · arraste para mover",
        .unlockPillLabel: "Cliques indo pro jogo — toque para travar",

        .shortcut: "Atalho", .language: "Idioma", .teams: "Times",
        .defaultTeam: "Time padrão", .gymFarm: "Farm de Ginásios", .emojiMode: "Modo Emoji",
        .options: "Opções", .general: "Geral", .navNextShortcut: "Atalho do \"Próximo\"",
        .portuguese: "Português", .about: "Sobre", .version: "Versão", .developedBy: "Desenvolvido por: Prestrelo", .thanksTo: "Agradecimentos: xfallen, allen e tilapia",
        .opacity: "Opacidade", .comingSoon: "em breve", .pasteHelp: "Ver Poképaste",
        .docHelp: "Ver fonte da estratégia",
        .pokekingBody: "CODE: %@\n\nCole no Pokeking (account info → CODE → save) para usar este time e extrair as soluções.",
        .copyCode: "Copiar CODE", .openPokeking: "Abrir Pokeking",
        .docNotFoundTitle: "Documento oficial",
        .docNotFoundBody: "Ainda não encontramos o documento oficial desta estratégia.",

        .modePickerPrompt: "Escolha o que você vai fazer",
        .categorySubtitle: "Derrote os melhores treinadores de cada região.",
        .settingsCardSubtitle: "Times, Poképastes e ajustes",

        .legendHowToTitle: "Como ler o overlay",
        .legendHowToArrow: "A seta verde mostra a próxima ação que você deve fazer no jogo.",
        .legendHowToIcons: "Ícones como ↩️ 🗡️ 👏 são explicados no glossário deste modo, logo abaixo.",
        .legendHowToChoose: "Clique na opção que corresponde ao que apareceu no jogo.",
        .legendNewbieTitle: "Novo na Elite 4?",
        .legendNewbieBody: "Antes da sua 5ª vitória (enquanto a liga ainda não está no nível 100), o jogo troca os níveis e times, e as instruções podem não bater. A partir da 5ª vez elas ficam certeiras.",
        .legendGotIt: "Entendi",
        .legendGlossary: "Glossário deste modo", .legendWindowShortcuts: "Atalhos da janela",
        .legendDragKey: "Arraste", .legendDragDesc: "clique em qualquer ponto e mova a janela",
        .legendOpacityDesc: "ajusta a opacidade do overlay",
        .legendClickThroughDesc: "deixa os cliques passarem para o jogo (e volta)",
        .shortcutTitle: "Atalho do botão \"Próximo\"",
        .shortcutDescription: "Funciona com o PokeMMO em foco — avança o passo sem clicar na janela.",
        .shortcutCurrent: "Atual:", .shortcutSet: "Definir atalho", .shortcutChange: "Trocar atalho",
        .shortcutClear: "Limpar",
        .shortcutAccessWarning: "Para funcionar com o jogo em foco, permita o app em Ajustes → Privacidade e Segurança → Acessibilidade.",
        .shortcutGrant: "Conceder permissão",
        .navSkipShortcut: "Atalho de \"Pular parada\"",
        .shortcutSkipDescription: "Funciona com o PokeMMO em foco — pula a parada atual da rota de farm sem clicar na janela.",

        .homeGroupPromptDefault: "Escolha:", .searchCity: "Buscar cidade…",
        .searchPokemon: "Buscar Pokémon…", .searchNoResults: "Nada encontrado para “%@”.",
        .citySkipUncheckHelp: "Desmarcar (fazer esta cidade)", .citySkipMarkHelp: "Marcar para pular",
        .citySkipBadge: "pular", .showSkipped: "Mostrar pulados (%d)", .hideSkipped: "Ocultar pulados",
        .flatHomePromptDefault: "Toque para escolher",

        .opponentOnField: "no campo", .gymLeadWith: "Lidere com", .nextGym: "Próximo ginásio",
        .nextLeadLabel: "Próximo lead: ", .skipThisStop: "Pular esta parada",
        .seeTeamsConfirmed: "Time confirmado — ver", .seeTeamsPossible: "Ver times possíveis (%d)",
        .stepSetupBadge: "PÓS-LUTA", .stepNoteBadge: "ATENÇÃO",
        .next: "Próximo", .nextStop: "Próxima parada", .continueLabel: "Continuar",
        .opponentHeaderFacing: "ENFRENTANDO",
        .feedbackThanksOk: "Valeu pelo retorno! 💪", .feedbackThanksFail: "Obrigado! Vamos corrigir. 🙏",
        .feedbackFailPrompt: "O que aconteceu? (opcional)", .send: "Enviar",
        .feedbackWorked: "Funcionou", .feedbackDidntWork: "Não funcionou",
        .nextTrainerBadge: "PRÓXIMO", .leagueCompleted: "Liga concluída — escolher outra",
        .terminalBadge: "Fim do roteiro — finalize e leve a vitória!",

        .choicePromptDefault: "O que o Red fez?",
        .conditionalTableTitleDefault: "Escolha o golpe conforme o alvo",

        .teamsDistinguishHint: "Diferencie pelo **item** e pela **habilidade** — alguns são exclusivos de um time e confirmam qual é.",
        .teamsConfirmedTitle: "TIME CONFIRMADO", .teamsPossibleTitle: "TIMES POSSÍVEIS · %d",
        .teamsTeamCardTitle: "Time %@",

        .modeRedTitle: "Luta Red", .modeRedSubtitle: "Derrote o Red no Monte Silver.",
        .modeGymFarmSubtitle: "Derrote os líderes dos ginásios novamente em batalhas em dupla.",
        .modeElite4KantoSubtitle: "Lorelei, Bruno, Agatha, Lance e Gary.",
        .modeElite4HoennSubtitle: "Sidney, Phoebe, Glacia, Drake e Wallace.",
        .modeElite4UnovaSubtitle: "Shauntal, Grimsley, Caitlin, Marshal e Alder.",
        .modeElite4SinnohSubtitle: "Aaron, Bertha, Flint, Lucian e Cynthia.",
        .modeElite4JohtoSubtitle: "Will, Koga, Bruno, Karen e Lance.",
        .modeCynthiaMorimotoTitle: "Cynthia & Morimoto",
        .modeCynthiaMorimotoSubtitle: "Derrote a Cynthia e o Morimoto em Unova.",
        .modeHoohTitle: "Ho-Oh", .modeHoohSubtitle: "Derrote o Ho-Oh no rematch.",

        .keyNameSpace: "Espaço", .keyNameUnknownFallback: "Tecla %d",
        .errorSolveFileNotFound: "Arquivo %@.json não encontrado no pacote do app.",
    ]

    static let en: [L: String] = [
        .back: "Back", .cancel: "Cancel", .none: "none",

        // Cooldowns (#33)
        .cdTitle: "Cooldowns", .cdReloginhoHelp: "Cooldowns & alarms",
        .cdCharacters: "Characters", .cdNoCharacters: "No characters yet.\nAdd your first one 👇",
        .cdCharacterName: "Character name (e.g. Vinicios1)", .cdAdd: "Add", .cdActiveCount: "%d active",
        .cdBattles: "Battles", .cdBerries: "Berries", .cdOptional: "Optional",
        .cdDoNow: "✓ Do now", .cdClear: "Clear",
        .cdEmpty: "Empty — plant", .cdPlant: "Plant", .cdWaterNow: "Water now",
        .cdWatered: "Watered", .cdHarvest: "Harvest", .cdHarvestNow: "✓ Harvest now",
        .cdHarvestIn: "Harvest in %@", .cdWilted: "Wilted — harvest!",
        .cdAddBerry: "Add berry", .cdTierLabel: "Grows in %dh",
        .cdRenameTitle: "New character name:", .cdRemove: "Remove",
        .cdRemoveConfirm: "Remove character \"%@\"? This deletes its cooldowns.",
        .cdNotifReady: "%@ is ready! ⚔️", .cdNotifCharacter: "Character: %@",
        .cdNotifWater: "💧 Time to water %@", .cdNotifBerryReady: "🌱 %@ ready to harvest",
        .cdNotifWilt: "⚠️ %@ is wilting — harvest!",
        .cdElite4: "Elite 4", .cdReset: "Reset", .cdTapToStart: "Tap to start the CD",
        .cdRunning: "On cooldown", .cdWaterIn: "Water in %@", .cdWaterDone: "Waterings %d/%d",
        .cdRemoveBerry: "Remove berry",
        .cdNextWater: "Next watering", .cdHarvestShort: "Harvest",
        .cdAllWatered: "All waterings done", .cdReadyLabel: "Ready",
        .cdPhoto: "Photo…", .cdChoosePhoto: "Choose photo…", .cdChangePhoto: "Change photo…",
        .cdRemovePhoto: "Remove photo", .cdPhotoHint: "The image is scaled down to a 128×128 icon.",

        .updateRequiredTitle: "Update required",
        .updateRequiredBody: "You're on v%@. The minimum version is now v%@.\nDownload the new one to continue.",
        .downloadUpdate: "Download update", .close: "Close",
        .switchModeHelp: "Switch mode (Red / Farm Route)",
        .helpAndLegendHelp: "Help & legend",
        .lessOpacityHelp: "Less opacity", .moreOpacityHelp: "More opacity",
        .clickThroughHelp: "Let clicks pass through to the game (⌥⌘L)",
        .minimizeHelp: "Minimize (turns into a Master Ball)",
        .restart: "Restart", .stepProgress: "step %d/%d",
        .capturePressKey: "Press the shortcut key",
        .captureHint: "You can combine with ⌘ ⌥ ⌃ ⇧.\nEsc to cancel.",
        .loadErrorTitle: "Couldn't load the scripts",
        .miniBallTooltip: "Double-click to open · drag to move",
        .unlockPillLabel: "Clicks going to the game — tap to lock",

        .shortcut: "Shortcut", .language: "Language", .teams: "Teams",
        .defaultTeam: "Default team", .gymFarm: "Gym Farm", .emojiMode: "Emoji Mode",
        .options: "Options", .general: "General", .navNextShortcut: "\"Next\" shortcut",
        .portuguese: "Portuguese", .about: "About", .version: "Version", .developedBy: "Developed by: Prestrelo", .thanksTo: "Thanks: xfallen, allen and tilapia",
        .opacity: "Opacity", .comingSoon: "coming soon", .pasteHelp: "View Poképaste",
        .docHelp: "View strategy source",
        .pokekingBody: "CODE: %@\n\nPaste it in Pokeking (account info → CODE → save) to use this team and extract the solutions.",
        .copyCode: "Copy CODE", .openPokeking: "Open Pokeking",
        .docNotFoundTitle: "Official document",
        .docNotFoundBody: "We haven't found the official document for this strategy yet.",

        .modePickerPrompt: "Choose what to do",
        .categorySubtitle: "Beat the best trainers of each region.",
        .settingsCardSubtitle: "Teams, Poképastes and settings",

        .legendHowToTitle: "How to read the overlay",
        .legendHowToArrow: "The green arrow shows the next action to take in the game.",
        .legendHowToIcons: "Icons like ↩️ 🗡️ 👏 are explained in this mode's glossary, just below.",
        .legendHowToChoose: "Click the option that matches what showed up in the game.",
        .legendNewbieTitle: "New to the Elite 4?",
        .legendNewbieBody: "Before your 5th win (while the league isn't level 100 yet), the game changes the levels and teams, so the instructions may not match. From the 5th time on they're accurate.",
        .legendGotIt: "Got it",
        .legendGlossary: "Glossary for this mode", .legendWindowShortcuts: "Window shortcuts",
        .legendDragKey: "Drag", .legendDragDesc: "click anywhere and move the window",
        .legendOpacityDesc: "adjusts the overlay opacity",
        .legendClickThroughDesc: "lets clicks pass through to the game (and back)",
        .shortcutTitle: "\"Next\" button shortcut",
        .shortcutDescription: "Works while PokeMMO is focused — advances the step without clicking the window.",
        .shortcutCurrent: "Current:", .shortcutSet: "Set shortcut", .shortcutChange: "Change shortcut",
        .shortcutClear: "Clear",
        .shortcutAccessWarning: "To work while the game is focused, allow the app in Settings → Privacy & Security → Accessibility.",
        .shortcutGrant: "Grant permission",
        .navSkipShortcut: "\"Skip stop\" shortcut",
        .shortcutSkipDescription: "Works while PokeMMO is focused — skips the current farm-route stop without clicking the window.",

        .homeGroupPromptDefault: "Choose:", .searchCity: "Search city…",
        .searchPokemon: "Search Pokémon…", .searchNoResults: "Nothing found for “%@”.",
        .citySkipUncheckHelp: "Uncheck (do this city)", .citySkipMarkHelp: "Mark to skip",
        .citySkipBadge: "skip", .showSkipped: "Show skipped (%d)", .hideSkipped: "Hide skipped",
        .flatHomePromptDefault: "Tap to choose",

        .opponentOnField: "on the field", .gymLeadWith: "Lead with", .nextGym: "Next gym",
        .nextLeadLabel: "Next lead: ", .skipThisStop: "Skip this stop",
        .seeTeamsConfirmed: "Team confirmed — view", .seeTeamsPossible: "View possible teams (%d)",
        .stepSetupBadge: "POST-BATTLE", .stepNoteBadge: "ATTENTION",
        .next: "Next", .nextStop: "Next stop", .continueLabel: "Continue",
        .opponentHeaderFacing: "FACING",
        .feedbackThanksOk: "Thanks for the feedback! 💪", .feedbackThanksFail: "Thank you! We'll fix it. 🙏",
        .feedbackFailPrompt: "What happened? (optional)", .send: "Send",
        .feedbackWorked: "It worked", .feedbackDidntWork: "Didn't work",
        .nextTrainerBadge: "NEXT", .leagueCompleted: "League completed — choose another",
        .terminalBadge: "End of the guide — finish it off and take the win!",

        .choicePromptDefault: "What did Red do?",
        .conditionalTableTitleDefault: "Choose the move based on the target",

        .teamsDistinguishHint: "Tell them apart by **item** and **ability** — some are exclusive to one team and confirm which it is.",
        .teamsConfirmedTitle: "TEAM CONFIRMED", .teamsPossibleTitle: "POSSIBLE TEAMS · %d",
        .teamsTeamCardTitle: "Team %@",

        .modeRedTitle: "Red Battle", .modeRedSubtitle: "Defeat Red at Mt. Silver.",
        .modeGymFarmSubtitle: "Defeat the gym leaders again in double battles.",
        .modeElite4KantoSubtitle: "Lorelei, Bruno, Agatha, Lance and Gary.",
        .modeElite4HoennSubtitle: "Sidney, Phoebe, Glacia, Drake and Wallace.",
        .modeElite4UnovaSubtitle: "Shauntal, Grimsley, Caitlin, Marshal and Alder.",
        .modeElite4SinnohSubtitle: "Aaron, Bertha, Flint, Lucian and Cynthia.",
        .modeElite4JohtoSubtitle: "Will, Koga, Bruno, Karen and Lance.",
        .modeCynthiaMorimotoTitle: "Cynthia & Morimoto",
        .modeCynthiaMorimotoSubtitle: "Beat Cynthia and Morimoto in Unova.",
        .modeHoohTitle: "Ho-Oh", .modeHoohSubtitle: "Beat Ho-Oh in the rematch.",

        .keyNameSpace: "Space", .keyNameUnknownFallback: "Key %d",
        .errorSolveFileNotFound: "File %@.json was not found in the app bundle.",
    ]
}
