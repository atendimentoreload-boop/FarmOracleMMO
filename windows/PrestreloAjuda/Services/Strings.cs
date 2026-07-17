namespace PrestreloAjuda.Services;

/// Idioma da interface. O conteúdo das lutas (JSON) é tratado à parte (SolveLoader roteia por idioma).
public enum Lang { Pt, En }

/// Chaves de texto da interface. Espelha o enum L do Localization.swift do Mac:
/// só strings cujo EN difere do PT entram aqui; tokens idênticos ("Menu", "ON/OFF",
/// "Elite 4", "v%@") ficam literais no código.
public enum L
{
    // Compartilhadas
    Back, Cancel, None, Clear,

    // Shell / janela
    UpdateRequiredTitle, UpdateRequiredBody, DownloadUpdate, Close,
    LessOpacityHelp, MoreOpacityHelp, ClickThroughOnHelp, ClickThroughOffHelp,
    MinimizeHelp, CloseHelp, Restart, BackButton, StepProgress,
    CapturePressKey, CaptureHint, NextShortcutSet, NextShortcutDefine,
    MiniBallTooltip, UnlockPillLabel,

    // SettingsView (Menu)
    Shortcut, Language, Teams, DefaultTeam, GymFarm, EmojiMode,
    Options, General, NavNextShortcut, NavSkipShortcut, ShortcutDescription, ShortcutSkipDescription, Portuguese, About, Version, DevelopedBy, ThanksTo,
    Opacity, PasteHelp, Overlay, SwitchTeam, SettingsCardTitle, SettingsCardSubtitle,
    SourceHelp, PokekingBody, CopyCode, OpenPokeking, DocNotFoundTitle, DocNotFoundBody,

    // ModePicker
    ModePickerPrompt,

    // LegendView
    LegendGlossary,
    // #73 — guia "Como ler o overlay"
    LegendHowToTitle, LegendHowToArrow, LegendHowToIcons, LegendHowToChoose,
    LegendNewbieTitle, LegendNewbieBody, LegendGotIt,

    // HomeView
    HomeGroupPromptDefault, SearchCity, SearchPokemon, SearchNoResults,
    CitySkipUncheckHelp, CitySkipMarkHelp, FlatHomePromptDefault, ChoosePrompt,

    // NodeView
    OpponentOnField, GymLeadWith, NextGym, NextLeadLabel, SkipThisStop,
    SeeTeamsConfirmed, SeeTeamsPossible, StepSetupBadge,
    Next, NextStop, ContinueLabel, OpponentHeaderFacing,
    FeedbackThanksOk, FeedbackThanksFail, FeedbackFailPrompt, Send,
    FeedbackWorked, FeedbackDidntWork, NextTrainerBadge,
    LeagueCompleted, TerminalBadge,

    // ChoiceView
    ChoicePromptDefault,

    // TeamsOverlayView
    TeamsDistinguishHint, TeamsConfirmedTitle, TeamsPossibleTitle, TeamsTeamCardTitle,
    TeamLabel, TeamPokemonSep,

    // AppModel (modos)
    ModeRedTitle, ModeRedSubtitle, ModeGymFarmTitle, ModeGymFarmSubtitle,
    ModeElite4KantoSubtitle, ModeElite4HoennSubtitle, ModeElite4UnovaSubtitle,
    ModeElite4SinnohSubtitle, ModeElite4JohtoSubtitle,
    ModeCynthiaMorimotoTitle, ModeCynthiaMorimotoSubtitle, ModeHoohTitle, ModeHoohSubtitle,
    ComingSoon,
    CategorySubtitle,

    // SolveLoader / erros
    KeyNameSpace, LoadError,

    // Cooldowns (#33) — espelha as chaves cd* do Localization.swift do Mac (valores EXATOS).
    CdTitle, CdReloginhoHelp, CdCharacters, CdNoCharacters, CdCharacterName, CdAdd, CdActiveCount,
    CdBattles, CdBerries, CdOptional, CdDoNow, CdClear, CdEmpty, CdPlant, CdWaterNow, CdWatered,
    CdHarvest, CdHarvestNow, CdHarvestIn, CdWilted, CdAddBerry, CdTierLabel, CdRenameTitle, CdRemove,
    CdRemoveConfirm, CdNotifReady, CdNotifCharacter, CdNotifWater, CdNotifBerryReady, CdNotifWilt,
    CdElite4, CdReset, CdTapToStart, CdRunning, CdWaterIn, CdWaterDone, CdRemoveBerry, CdNextWater,
    CdHarvestShort, CdAllWatered, CdReadyLabel, CdPhoto, CdChoosePhoto, CdChangePhoto, CdRemovePhoto,
    CdPhotoHint,
}

/// Camada de strings PT/EN. Espelha o Strings.swift do Mac.
/// Use <see cref="T"/> para traduzir uma chave para o idioma atual.
public static class Strings
{
    /// Idioma atual da UI (global). Lido pelos helpers estáticos e telas sem acesso ao AppModel.
    /// Trocar de idioma sempre acontece no Menu e re-renderiza tudo, então ler o global basta.
    public static Lang Current { get; set; } = ParseLang(TeamPrefs.Language);

    public static Lang ParseLang(string? raw) =>
        string.Equals(raw, "en", StringComparison.OrdinalIgnoreCase) ? Lang.En : Lang.Pt;

    public static string Code(Lang l) => l == Lang.En ? "en" : "pt";

    /// Tradução de uma chave para o idioma atual.
    public static string T(L key) => Text(key, Current);

    public static string Text(L key, Lang lang)
    {
        if (lang == Lang.En && En.TryGetValue(key, out var e)) return e;
        return Pt.TryGetValue(key, out var p) ? p : key.ToString();
    }

    private static readonly Dictionary<L, string> Pt = new()
    {
        [L.Back] = "Voltar", [L.Cancel] = "Cancelar", [L.None] = "nenhum", [L.Clear] = "Limpar",

        [L.UpdateRequiredTitle] = "Atualização obrigatória",
        [L.UpdateRequiredBody] = "Você está na v{0}. A versão mínima agora é v{1}.\nBaixe a nova para continuar.",
        [L.DownloadUpdate] = "Baixar atualização", [L.Close] = "Fechar",
        [L.LessOpacityHelp] = "Menos opacidade", [L.MoreOpacityHelp] = "Mais opacidade",
        [L.ClickThroughOnHelp] = "Cliques indo pro jogo (Ctrl+Alt+L para travar)",
        [L.ClickThroughOffHelp] = "Deixar cliques passarem pro jogo (Ctrl+Alt+L)",
        [L.MinimizeHelp] = "Minimizar (vira Master Ball)", [L.CloseHelp] = "Fechar",
        [L.Restart] = "Reiniciar", [L.BackButton] = "Voltar", [L.StepProgress] = "passo {0}/{1}",
        [L.CapturePressKey] = "Aperte a tecla do atalho",
        [L.CaptureHint] = "Pode combinar com Ctrl, Alt, Shift ou Win.\nEsc para cancelar.",
        [L.NextShortcutSet] = "Atalho do Próximo: {0} (clique para mudar)",
        [L.NextShortcutDefine] = "Definir atalho do botão Próximo",
        [L.MiniBallTooltip] = "Duplo-clique para abrir · arraste para mover",
        [L.UnlockPillLabel] = "Cliques indo pro jogo — toque para travar",

        [L.Shortcut] = "Atalho", [L.Language] = "Idioma", [L.Teams] = "Times",
        [L.DefaultTeam] = "Time padrão", [L.GymFarm] = "Farm de Ginásios", [L.EmojiMode] = "Modo Emoji",
        [L.Options] = "Opções", [L.General] = "Geral", [L.NavNextShortcut] = "Atalho do \"Próximo\"",
        [L.NavSkipShortcut] = "Atalho de \"Pular parada\"",
        [L.ShortcutDescription] = "Funciona com o PokeMMO em foco — avança o passo sem clicar na janela.",
        [L.ShortcutSkipDescription] = "Funciona com o PokeMMO em foco — pula a parada atual da rota de farm sem clicar na janela.",
        [L.Portuguese] = "Português", [L.About] = "Sobre", [L.Version] = "Versão",
        [L.DevelopedBy] = "Desenvolvido por: Prestrelo", [L.ThanksTo] = "Agradecimentos: xfallen, allen e tilapia",
        [L.Opacity] = "Opacidade", [L.PasteHelp] = "Ver Poképaste", [L.Overlay] = "Overlay",
        [L.SwitchTeam] = "Trocar de time",
        [L.SettingsCardTitle] = "Menu", [L.SettingsCardSubtitle] = "Times, Poképastes e ajustes",
        [L.SourceHelp] = "Ver fonte da estratégia",
        [L.PokekingBody] = "CODE: {0}\n\nCole no Pokeking (account info → CODE → save) para usar este time e extrair as soluções.",
        [L.CopyCode] = "Copiar CODE", [L.OpenPokeking] = "Abrir Pokeking",
        [L.DocNotFoundTitle] = "Documento oficial",
        [L.DocNotFoundBody] = "Ainda não encontramos o documento oficial desta estratégia.",

        [L.ModePickerPrompt] = "Escolha o que você vai fazer",
        [L.CategorySubtitle] = "Derrote os melhores treinadores de cada região.",

        [L.LegendGlossary] = "Legenda deste modo",

        // #73 — guia "Como ler o overlay"
        [L.LegendHowToTitle] = "Como ler o overlay",
        [L.LegendHowToArrow] = "A seta verde mostra a próxima ação que você deve fazer no jogo.",
        [L.LegendHowToIcons] = "Ícones como ↩️ 🗡️ 👏 são explicados no glossário deste modo, logo abaixo.",
        [L.LegendHowToChoose] = "Clique na opção que corresponde ao que apareceu no jogo.",
        [L.LegendNewbieTitle] = "Novo na Elite 4?",
        [L.LegendNewbieBody] = "Antes da sua 5ª vitória (enquanto a liga ainda não está no nível 100), o jogo troca os níveis e times, e as instruções podem não bater. A partir da 5ª vez elas ficam certeiras.",
        [L.LegendGotIt] = "Entendi",

        [L.HomeGroupPromptDefault] = "Escolha:", [L.SearchCity] = "Buscar cidade…",
        [L.SearchPokemon] = "Buscar Pokémon…", [L.SearchNoResults] = "Nada encontrado para “{0}”.",
        [L.CitySkipUncheckHelp] = "Desmarcar (fazer esta parada)", [L.CitySkipMarkHelp] = "Marcar para pular",
        [L.FlatHomePromptDefault] = "Toque para escolher", [L.ChoosePrompt] = "Escolha:",

        [L.OpponentOnField] = " no campo", [L.GymLeadWith] = "Lidere com", [L.NextGym] = "Próximo ginásio",
        [L.NextLeadLabel] = "Próximo lead: ", [L.SkipThisStop] = "Pular esta parada",
        [L.SeeTeamsConfirmed] = "Time confirmado — ver", [L.SeeTeamsPossible] = "Ver times do oponente · {0}",
        [L.StepSetupBadge] = "PÓS-LUTA",
        [L.Next] = "Próximo", [L.NextStop] = "Próxima parada", [L.ContinueLabel] = "Continuar",
        [L.OpponentHeaderFacing] = "ENFRENTANDO",
        [L.FeedbackThanksOk] = "Valeu pelo retorno! 💪", [L.FeedbackThanksFail] = "Obrigado! Vamos corrigir. 🙏",
        [L.FeedbackFailPrompt] = "O que aconteceu? (opcional)", [L.Send] = "Enviar",
        [L.FeedbackWorked] = "👍 Funcionou", [L.FeedbackDidntWork] = "👎 Não funcionou",
        [L.NextTrainerBadge] = "PRÓXIMO", [L.LeagueCompleted] = "🏁 Liga concluída — escolher outra",
        [L.TerminalBadge] = "🏆 Fim do roteiro — finalize e leve a vitória!",

        [L.ChoicePromptDefault] = "O que o oponente fez?",

        [L.TeamsDistinguishHint] = "Diferencie pelo item e pela habilidade — alguns são exclusivos de um time e confirmam qual é.",
        [L.TeamsConfirmedTitle] = "TIME CONFIRMADO", [L.TeamsPossibleTitle] = "TIMES POSSÍVEIS · {0}",
        [L.TeamsTeamCardTitle] = "Time {0}", [L.TeamLabel] = "TIME", [L.TeamPokemonSep] = " · ",

        [L.ModeRedTitle] = "Luta do Red", [L.ModeRedSubtitle] = "Roteiro turno a turno para vencer o Red.",
        [L.ModeGymFarmTitle] = "Farm de Ginásios (Veteran)",
        [L.ModeGymFarmSubtitle] = "Hoenn → Kanto → Sinnoh → Johto → Unova, ginásio a ginásio.",
        [L.ModeElite4KantoSubtitle] = "Lorelei, Bruno, Agatha, Lance e Gary.",
        [L.ModeElite4HoennSubtitle] = "Sidney, Phoebe, Glacia, Drake e Wallace.",
        [L.ModeElite4UnovaSubtitle] = "Shauntal, Grimsley, Caitlin, Marshal e Alder.",
        [L.ModeElite4SinnohSubtitle] = "Aaron, Bertha, Flint, Lucian e Cynthia.",
        [L.ModeElite4JohtoSubtitle] = "Will, Koga, Bruno, Karen e Lance.",
        [L.ModeCynthiaMorimotoTitle] = "Cynthia & Morimoto",
        [L.ModeCynthiaMorimotoSubtitle] = "Derrote a Cynthia e o Morimoto em Unova.",
        [L.ModeHoohTitle] = "Ho-Oh", [L.ModeHoohSubtitle] = "Derrote o Ho-Oh no rematch.",
        [L.ComingSoon] = "em breve",

        [L.KeyNameSpace] = "Espaço",
        [L.LoadError] = "Não consegui carregar os roteiros (pasta data/).\n\n{0}",

        // Cooldowns (#33)
        [L.CdTitle] = "Cooldowns", [L.CdReloginhoHelp] = "Cooldowns e alarmes",
        [L.CdCharacters] = "Personagens", [L.CdNoCharacters] = "Nenhum boneco ainda.\nAdicione o primeiro 👇",
        [L.CdCharacterName] = "Nome do boneco (ex: Vinicios1)", [L.CdAdd] = "Adicionar", [L.CdActiveCount] = "{0} ativo(s)",
        [L.CdBattles] = "Batalhas", [L.CdBerries] = "Berries", [L.CdOptional] = "Opcionais",
        [L.CdDoNow] = "✓ Fazer agora", [L.CdClear] = "Limpar",
        [L.CdEmpty] = "Vazio — plantar", [L.CdPlant] = "Plantar", [L.CdWaterNow] = "Regar agora",
        [L.CdWatered] = "Reguei", [L.CdHarvest] = "Colher", [L.CdHarvestNow] = "✓ Colher agora",
        [L.CdHarvestIn] = "Colher em {0}", [L.CdWilted] = "Murchou — colha!",
        [L.CdAddBerry] = "Adicionar berry", [L.CdTierLabel] = "Cresce em {0}h",
        [L.CdRenameTitle] = "Novo nome do boneco:", [L.CdRemove] = "Remover",
        [L.CdRemoveConfirm] = "Remover o boneco \"{0}\"? Isso apaga os cooldowns dele.",
        [L.CdNotifReady] = "{0} liberou! ⚔️", [L.CdNotifCharacter] = "Boneco: {0}",
        [L.CdNotifWater] = "💧 Hora de regar {0}", [L.CdNotifBerryReady] = "🌱 {0} pronta pra colher",
        [L.CdNotifWilt] = "⚠️ {0} vai murchar — colha!",
        [L.CdElite4] = "Elite 4", [L.CdReset] = "Resetar", [L.CdTapToStart] = "Tocar para iniciar o CD",
        [L.CdRunning] = "Em cooldown", [L.CdWaterIn] = "Regar em {0}", [L.CdWaterDone] = "Regas {0}/{1}",
        [L.CdRemoveBerry] = "Remover berry",
        [L.CdNextWater] = "Próxima rega", [L.CdHarvestShort] = "Colheita",
        [L.CdAllWatered] = "Regas concluídas", [L.CdReadyLabel] = "Liberado",
        [L.CdPhoto] = "Foto…", [L.CdChoosePhoto] = "Escolher foto…", [L.CdChangePhoto] = "Trocar foto…",
        [L.CdRemovePhoto] = "Remover foto", [L.CdPhotoHint] = "A imagem é reduzida pra um ícone de 128×128.",
    };

    private static readonly Dictionary<L, string> En = new()
    {
        [L.Back] = "Back", [L.Cancel] = "Cancel", [L.None] = "none", [L.Clear] = "Clear",

        [L.UpdateRequiredTitle] = "Update required",
        [L.UpdateRequiredBody] = "You're on v{0}. The minimum version is now v{1}.\nDownload the new one to continue.",
        [L.DownloadUpdate] = "Download update", [L.Close] = "Close",
        [L.LessOpacityHelp] = "Less opacity", [L.MoreOpacityHelp] = "More opacity",
        [L.ClickThroughOnHelp] = "Clicks going to the game (Ctrl+Alt+L to lock)",
        [L.ClickThroughOffHelp] = "Let clicks pass through to the game (Ctrl+Alt+L)",
        [L.MinimizeHelp] = "Minimize (turns into a Master Ball)", [L.CloseHelp] = "Close",
        [L.Restart] = "Restart", [L.BackButton] = "Back", [L.StepProgress] = "step {0}/{1}",
        [L.CapturePressKey] = "Press the shortcut key",
        [L.CaptureHint] = "You can combine with Ctrl, Alt, Shift or Win.\nEsc to cancel.",
        [L.NextShortcutSet] = "Next shortcut: {0} (click to change)",
        [L.NextShortcutDefine] = "Set the Next button shortcut",
        [L.MiniBallTooltip] = "Double-click to open · drag to move",
        [L.UnlockPillLabel] = "Clicks going to the game — tap to lock",

        [L.Shortcut] = "Shortcut", [L.Language] = "Language", [L.Teams] = "Teams",
        [L.DefaultTeam] = "Default team", [L.GymFarm] = "Gym Farm", [L.EmojiMode] = "Emoji Mode",
        [L.Options] = "Options", [L.General] = "General", [L.NavNextShortcut] = "\"Next\" shortcut",
        [L.NavSkipShortcut] = "\"Skip stop\" shortcut",
        [L.ShortcutDescription] = "Works while PokeMMO is focused — advances the step without clicking the window.",
        [L.ShortcutSkipDescription] = "Works while PokeMMO is focused — skips the current farm-route stop without clicking the window.",
        [L.Portuguese] = "Portuguese", [L.About] = "About", [L.Version] = "Version",
        [L.DevelopedBy] = "Developed by: Prestrelo", [L.ThanksTo] = "Thanks: xfallen, allen and tilapia",
        [L.Opacity] = "Opacity", [L.PasteHelp] = "View Poképaste", [L.Overlay] = "Overlay",
        [L.SwitchTeam] = "Switch team",
        [L.SettingsCardTitle] = "Menu", [L.SettingsCardSubtitle] = "Teams, Poképastes and settings",
        [L.SourceHelp] = "View strategy source",
        [L.PokekingBody] = "CODE: {0}\n\nPaste it in Pokeking (account info → CODE → save) to use this team and extract the solutions.",
        [L.CopyCode] = "Copy CODE", [L.OpenPokeking] = "Open Pokeking",
        [L.DocNotFoundTitle] = "Official document",
        [L.DocNotFoundBody] = "We haven't found the official document for this strategy yet.",

        [L.ModePickerPrompt] = "Choose what to do",
        [L.CategorySubtitle] = "Beat the best trainers of each region.",

        [L.LegendGlossary] = "Glossary for this mode",

        // #73 — "How to read the overlay" guide
        [L.LegendHowToTitle] = "How to read the overlay",
        [L.LegendHowToArrow] = "The green arrow shows the next action to take in the game.",
        [L.LegendHowToIcons] = "Icons like ↩️ 🗡️ 👏 are explained in this mode's glossary, just below.",
        [L.LegendHowToChoose] = "Click the option that matches what showed up in the game.",
        [L.LegendNewbieTitle] = "New to the Elite 4?",
        [L.LegendNewbieBody] = "Before your 5th win (while the league isn't level 100 yet), the game changes the levels and teams, so the instructions may not match. From the 5th time on they're accurate.",
        [L.LegendGotIt] = "Got it",

        [L.HomeGroupPromptDefault] = "Choose:", [L.SearchCity] = "Search city…",
        [L.SearchPokemon] = "Search Pokémon…", [L.SearchNoResults] = "Nothing found for “{0}”.",
        [L.CitySkipUncheckHelp] = "Uncheck (do this stop)", [L.CitySkipMarkHelp] = "Mark to skip",
        [L.FlatHomePromptDefault] = "Tap to choose", [L.ChoosePrompt] = "Choose:",

        [L.OpponentOnField] = " on the field", [L.GymLeadWith] = "Lead with", [L.NextGym] = "Next gym",
        [L.NextLeadLabel] = "Next lead: ", [L.SkipThisStop] = "Skip this stop",
        [L.SeeTeamsConfirmed] = "Team confirmed — view", [L.SeeTeamsPossible] = "View opponent teams · {0}",
        [L.StepSetupBadge] = "POST-BATTLE",
        [L.Next] = "Next", [L.NextStop] = "Next stop", [L.ContinueLabel] = "Continue",
        [L.OpponentHeaderFacing] = "FACING",
        [L.FeedbackThanksOk] = "Thanks for the feedback! 💪", [L.FeedbackThanksFail] = "Thank you! We'll fix it. 🙏",
        [L.FeedbackFailPrompt] = "What happened? (optional)", [L.Send] = "Send",
        [L.FeedbackWorked] = "👍 It worked", [L.FeedbackDidntWork] = "👎 Didn't work",
        [L.NextTrainerBadge] = "NEXT", [L.LeagueCompleted] = "🏁 League completed — choose another",
        [L.TerminalBadge] = "🏆 End of the guide — finish it off and take the win!",

        [L.ChoicePromptDefault] = "What did the opponent do?",

        [L.TeamsDistinguishHint] = "Tell them apart by item and ability — some are exclusive to one team and confirm which it is.",
        [L.TeamsConfirmedTitle] = "TEAM CONFIRMED", [L.TeamsPossibleTitle] = "POSSIBLE TEAMS · {0}",
        [L.TeamsTeamCardTitle] = "Team {0}", [L.TeamLabel] = "TEAM", [L.TeamPokemonSep] = " · ",

        [L.ModeRedTitle] = "Red Battle", [L.ModeRedSubtitle] = "Turn-by-turn guide to beat Red.",
        [L.ModeGymFarmTitle] = "Gym Farm (Veteran)",
        [L.ModeGymFarmSubtitle] = "Hoenn → Kanto → Sinnoh → Johto → Unova, gym by gym.",
        [L.ModeElite4KantoSubtitle] = "Lorelei, Bruno, Agatha, Lance and Gary.",
        [L.ModeElite4HoennSubtitle] = "Sidney, Phoebe, Glacia, Drake and Wallace.",
        [L.ModeElite4UnovaSubtitle] = "Shauntal, Grimsley, Caitlin, Marshal and Alder.",
        [L.ModeElite4SinnohSubtitle] = "Aaron, Bertha, Flint, Lucian and Cynthia.",
        [L.ModeElite4JohtoSubtitle] = "Will, Koga, Bruno, Karen and Lance.",
        [L.ModeCynthiaMorimotoTitle] = "Cynthia & Morimoto",
        [L.ModeCynthiaMorimotoSubtitle] = "Beat Cynthia and Morimoto in Unova.",
        [L.ModeHoohTitle] = "Ho-Oh", [L.ModeHoohSubtitle] = "Beat Ho-Oh in the rematch.",
        [L.ComingSoon] = "coming soon",

        [L.KeyNameSpace] = "Space",
        [L.LoadError] = "Couldn't load the scripts (data/ folder).\n\n{0}",

        // Cooldowns (#33)
        [L.CdTitle] = "Cooldowns", [L.CdReloginhoHelp] = "Cooldowns & alarms",
        [L.CdCharacters] = "Characters", [L.CdNoCharacters] = "No characters yet.\nAdd your first one 👇",
        [L.CdCharacterName] = "Character name (e.g. Vinicios1)", [L.CdAdd] = "Add", [L.CdActiveCount] = "{0} active",
        [L.CdBattles] = "Battles", [L.CdBerries] = "Berries", [L.CdOptional] = "Optional",
        [L.CdDoNow] = "✓ Do now", [L.CdClear] = "Clear",
        [L.CdEmpty] = "Empty — plant", [L.CdPlant] = "Plant", [L.CdWaterNow] = "Water now",
        [L.CdWatered] = "Watered", [L.CdHarvest] = "Harvest", [L.CdHarvestNow] = "✓ Harvest now",
        [L.CdHarvestIn] = "Harvest in {0}", [L.CdWilted] = "Wilted — harvest!",
        [L.CdAddBerry] = "Add berry", [L.CdTierLabel] = "Grows in {0}h",
        [L.CdRenameTitle] = "New character name:", [L.CdRemove] = "Remove",
        [L.CdRemoveConfirm] = "Remove character \"{0}\"? This deletes its cooldowns.",
        [L.CdNotifReady] = "{0} is ready! ⚔️", [L.CdNotifCharacter] = "Character: {0}",
        [L.CdNotifWater] = "💧 Time to water {0}", [L.CdNotifBerryReady] = "🌱 {0} ready to harvest",
        [L.CdNotifWilt] = "⚠️ {0} is wilting — harvest!",
        [L.CdElite4] = "Elite 4", [L.CdReset] = "Reset", [L.CdTapToStart] = "Tap to start the CD",
        [L.CdRunning] = "On cooldown", [L.CdWaterIn] = "Water in {0}", [L.CdWaterDone] = "Waterings {0}/{1}",
        [L.CdRemoveBerry] = "Remove berry",
        [L.CdNextWater] = "Next watering", [L.CdHarvestShort] = "Harvest",
        [L.CdAllWatered] = "All waterings done", [L.CdReadyLabel] = "Ready",
        [L.CdPhoto] = "Photo…", [L.CdChoosePhoto] = "Choose photo…", [L.CdChangePhoto] = "Change photo…",
        [L.CdRemovePhoto] = "Remove photo", [L.CdPhotoHint] = "The image is scaled down to a 128×128 icon.",
    };
}
