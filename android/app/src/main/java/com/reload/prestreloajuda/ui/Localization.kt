package com.reload.prestreloajuda.ui

import android.content.Context
import androidx.compose.runtime.compositionLocalOf
import com.reload.prestreloajuda.data.TeamPrefs

/** Idioma da interface. O conteúdo das lutas (JSON) é tratado à parte (ver SolveLoader). */
enum class Lang(val code: String) {
    PT("pt"), EN("en");

    companion object {
        fun from(code: String?): Lang = entries.firstOrNull { it.code == code } ?: PT
    }
}

/**
 * Idioma atual da UI, lido das preferências. Mantido num CompositionLocal para que
 * qualquer Composable o leia e RECOMPONHA ao trocar — espelha o AppLang.current do Mac.
 * Trocar o idioma escreve em TeamPrefs e atualiza este estado.
 */
val LocalLang = compositionLocalOf { Lang.PT }

/** Chaves de texto da interface — porte fiel do enum L do Mac (Localization.swift). */
enum class L {
    // Compartilhadas
    Back, Cancel, NoneValue,

    // Cooldowns (#33)
    CdTitle, CdReloginhoHelp, CdCharacters, CdNoCharacters, CdCharacterName, CdAdd, CdActiveCount,
    CdBattles, CdBerries, CdOptional, CdDoNow, CdClear, CdEmpty, CdPlant, CdWaterNow, CdWatered,
    CdHarvest, CdHarvestNow, CdHarvestIn, CdWilted, CdAddBerry, CdTierLabel, CdRenameTitle, CdRemove,
    CdRemoveConfirm, CdNotifReady, CdNotifCharacter, CdNotifWater, CdNotifBerryReady, CdNotifWilt,
    CdElite4, CdReset, CdTapToStart, CdRunning, CdWaterIn, CdWaterDone, CdRemoveBerry, CdNextWater,
    CdHarvestShort, CdAllWatered, CdReadyLabel, CdPhoto, CdChoosePhoto, CdChangePhoto, CdRemovePhoto,
    CdPhotoHint,

    // Settings (Menu)
    Shortcut, Language, Teams, DefaultTeam, GymFarm, EmojiMode,
    Options, General, Portuguese, About, Version, DevelopedBy, ThanksTo,
    Opacity, PasteHelp, SettingsTitle, OpenSettings, ComingSoon,
    SourceHelp, PokekingBody, CopyCode, OpenPokeking, DocNotFoundTitle, DocNotFoundBody, CodeCopied,

    // ModePicker
    ModePickerPrompt,

    // HomeView
    HomeGroupPromptDefault, FlatHomePromptDefault, SearchHint,

    // NodeView
    OpponentOnField, GymLeadWith, NextGym, NextLeadLabel, SkipThisStop,
    SeeTeamsConfirmed, SeeTeamsPossible, StepSetupBadge,
    Next, ContinueLabel, OpponentHeaderFacing, ChoosePrompt, ConditionalTableTitleDefault,
    FeedbackThanksOk, FeedbackThanksFail, FeedbackFailPrompt, Send, FeedbackDescribe,
    FeedbackWorked, FeedbackDidntWork, NextTrainerBadge, LeagueCompleted, TerminalBadge,

    // TeamsOverlay
    TeamsDistinguishHint, TeamsConfirmedTitle, TeamsPossibleTitle, TeamsTeamCardTitle,

    // Diversos
    LegendOfMode, EmojiSubtitle, ChooseAction, Restart, MenuLabel, StepProgress,

    // Guia "Como ler o overlay" (#73) — card de onboarding aberto pelo "?" (sem auto-abrir no Android).
    LegendHowToTitle, LegendHowToArrow, LegendHowToIcons, LegendHowToChoose,
    LegendNewbieTitle, LegendNewbieBody, LegendGotIt,
}

object Strings {
    fun text(key: L, lang: Lang): String = when (lang) {
        Lang.EN -> en[key] ?: pt[key] ?: key.name
        Lang.PT -> pt[key] ?: key.name
    }

    private val pt: Map<L, String> = mapOf(
        L.Back to "Voltar", L.Cancel to "Cancelar", L.NoneValue to "nenhum",

        // Cooldowns (#33)
        L.CdTitle to "Cooldowns", L.CdReloginhoHelp to "Cooldowns e alarmes",
        L.CdCharacters to "Personagens", L.CdNoCharacters to "Nenhum boneco ainda.\nAdicione o primeiro 👇",
        L.CdCharacterName to "Nome do boneco (ex: Vinicios1)", L.CdAdd to "Adicionar", L.CdActiveCount to "%d ativo(s)",
        L.CdBattles to "Batalhas", L.CdBerries to "Berries", L.CdOptional to "Opcionais",
        L.CdDoNow to "✓ Fazer agora", L.CdClear to "Limpar",
        L.CdEmpty to "Vazio — plantar", L.CdPlant to "Plantar", L.CdWaterNow to "Regar agora",
        L.CdWatered to "Reguei", L.CdHarvest to "Colher", L.CdHarvestNow to "✓ Colher agora",
        L.CdHarvestIn to "Colher em %s", L.CdWilted to "Murchou — colha!",
        L.CdAddBerry to "Adicionar berry", L.CdTierLabel to "Cresce em %dh",
        L.CdRenameTitle to "Novo nome do boneco:", L.CdRemove to "Remover",
        L.CdRemoveConfirm to "Remover o boneco \"%s\"? Isso apaga os cooldowns dele.",
        L.CdNotifReady to "%s liberou! ⚔️", L.CdNotifCharacter to "Boneco: %s",
        L.CdNotifWater to "💧 Hora de regar %s", L.CdNotifBerryReady to "🌱 %s pronta pra colher",
        L.CdNotifWilt to "⚠️ %s vai murchar — colha!",
        L.CdElite4 to "Elite 4", L.CdReset to "Resetar", L.CdTapToStart to "Tocar para iniciar o CD",
        L.CdRunning to "Em cooldown", L.CdWaterIn to "Regar em %s", L.CdWaterDone to "Regas %d/%d",
        L.CdRemoveBerry to "Remover berry",
        L.CdNextWater to "Próxima rega", L.CdHarvestShort to "Colheita",
        L.CdAllWatered to "Regas concluídas", L.CdReadyLabel to "Liberado",
        L.CdPhoto to "Foto…", L.CdChoosePhoto to "Escolher foto…", L.CdChangePhoto to "Trocar foto…",
        L.CdRemovePhoto to "Remover foto", L.CdPhotoHint to "A imagem é reduzida pra um ícone de 128×128.",

        L.Shortcut to "Atalho", L.Language to "Idioma", L.Teams to "Times",
        L.DefaultTeam to "Time padrão", L.GymFarm to "Farm de Ginásios", L.EmojiMode to "Modo Emoji",
        L.Options to "Opções", L.General to "Geral",
        L.Portuguese to "Português", L.About to "Sobre", L.Version to "Versão",
        L.DevelopedBy to "Desenvolvido por: Prestrelo", L.ThanksTo to "Agradecimentos: xfallen, allen e tilapia",
        L.Opacity to "Opacidade", L.PasteHelp to "Ver Poképaste",
        L.SourceHelp to "Ver fonte da estratégia",
        L.PokekingBody to "CODE: %s\n\nCole no Pokeking (account info → CODE → save) para usar este time e extrair as soluções.",
        L.CopyCode to "Copiar CODE", L.OpenPokeking to "Abrir Pokeking", L.CodeCopied to "CODE copiado",
        L.DocNotFoundTitle to "Documento oficial",
        L.DocNotFoundBody to "Ainda não encontramos o documento oficial desta estratégia.",
        L.SettingsTitle to "Times e Opções", L.OpenSettings to "Times, Poképastes e ajustes",
        L.ComingSoon to "em breve",

        L.ModePickerPrompt to "Escolha o que você vai fazer",

        L.HomeGroupPromptDefault to "Escolha:", L.FlatHomePromptDefault to "Toque para escolher",
        L.SearchHint to "Buscar…",

        L.OpponentOnField to "no campo", L.GymLeadWith to "Lidere com", L.NextGym to "Próximo ginásio",
        L.NextLeadLabel to "Próximo lead: ", L.SkipThisStop to "Pular esta parada",
        L.SeeTeamsConfirmed to "Time confirmado — ver", L.SeeTeamsPossible to "Ver times do oponente",
        L.StepSetupBadge to "PÓS-LUTA",
        L.Next to "Próximo", L.ContinueLabel to "Continuar",
        L.OpponentHeaderFacing to "ENFRENTANDO",
        L.ChoosePrompt to "O que o oponente fez?",
        L.ConditionalTableTitleDefault to "Escolha o golpe conforme o alvo",
        L.FeedbackThanksOk to "Valeu pelo retorno! 💪", L.FeedbackThanksFail to "Obrigado! Vamos corrigir. 🙏",
        L.FeedbackFailPrompt to "O que aconteceu? (opcional)", L.Send to "Enviar",
        L.FeedbackDescribe to "Descreva…",
        L.FeedbackWorked to "👍 Funcionou", L.FeedbackDidntWork to "👎 Não funcionou",
        L.NextTrainerBadge to "PRÓXIMO", L.LeagueCompleted to "🏁 Liga concluída — escolher outra",
        L.TerminalBadge to "🏆 Fim do roteiro — finalize e leve a vitória!",

        L.TeamsDistinguishHint to "Diferencie pelo item e pela habilidade — alguns são exclusivos de um time e confirmam qual é.",
        L.TeamsConfirmedTitle to "TIME CONFIRMADO", L.TeamsPossibleTitle to "TIMES POSSÍVEIS",
        L.TeamsTeamCardTitle to "Time",

        L.LegendOfMode to "Legenda deste modo", L.EmojiSubtitle to "Combate na notação original do autor",
        L.ChooseAction to "Escolha o que você vai fazer",
        L.Restart to "Reiniciar", L.MenuLabel to "Menu",
        L.StepProgress to "passo %d/%d",

        // Guia "Como ler o overlay" (#73)
        L.LegendHowToTitle to "Como ler o overlay",
        L.LegendHowToArrow to "A seta verde mostra a próxima ação que você deve fazer no jogo.",
        L.LegendHowToIcons to "Ícones como ↩️ 🗡️ 👏 são explicados no glossário deste modo, logo abaixo.",
        L.LegendHowToChoose to "Clique na opção que corresponde ao que apareceu no jogo.",
        L.LegendNewbieTitle to "Novo na Elite 4?",
        L.LegendNewbieBody to "Antes da sua 5ª vitória (enquanto a liga ainda não está no nível 100), o jogo troca os níveis e times, e as instruções podem não bater. A partir da 5ª vez elas ficam certeiras.",
        L.LegendGotIt to "Entendi",
    )

    private val en: Map<L, String> = mapOf(
        L.Back to "Back", L.Cancel to "Cancel", L.NoneValue to "none",

        // Cooldowns (#33)
        L.CdTitle to "Cooldowns", L.CdReloginhoHelp to "Cooldowns & alarms",
        L.CdCharacters to "Characters", L.CdNoCharacters to "No characters yet.\nAdd your first one 👇",
        L.CdCharacterName to "Character name (e.g. Vinicios1)", L.CdAdd to "Add", L.CdActiveCount to "%d active",
        L.CdBattles to "Battles", L.CdBerries to "Berries", L.CdOptional to "Optional",
        L.CdDoNow to "✓ Do now", L.CdClear to "Clear",
        L.CdEmpty to "Empty — plant", L.CdPlant to "Plant", L.CdWaterNow to "Water now",
        L.CdWatered to "Watered", L.CdHarvest to "Harvest", L.CdHarvestNow to "✓ Harvest now",
        L.CdHarvestIn to "Harvest in %s", L.CdWilted to "Wilted — harvest!",
        L.CdAddBerry to "Add berry", L.CdTierLabel to "Grows in %dh",
        L.CdRenameTitle to "New character name:", L.CdRemove to "Remove",
        L.CdRemoveConfirm to "Remove character \"%s\"? This deletes its cooldowns.",
        L.CdNotifReady to "%s is ready! ⚔️", L.CdNotifCharacter to "Character: %s",
        L.CdNotifWater to "💧 Time to water %s", L.CdNotifBerryReady to "🌱 %s ready to harvest",
        L.CdNotifWilt to "⚠️ %s is wilting — harvest!",
        L.CdElite4 to "Elite 4", L.CdReset to "Reset", L.CdTapToStart to "Tap to start the CD",
        L.CdRunning to "On cooldown", L.CdWaterIn to "Water in %s", L.CdWaterDone to "Waterings %d/%d",
        L.CdRemoveBerry to "Remove berry",
        L.CdNextWater to "Next watering", L.CdHarvestShort to "Harvest",
        L.CdAllWatered to "All waterings done", L.CdReadyLabel to "Ready",
        L.CdPhoto to "Photo…", L.CdChoosePhoto to "Choose photo…", L.CdChangePhoto to "Change photo…",
        L.CdRemovePhoto to "Remove photo", L.CdPhotoHint to "The image is scaled down to a 128×128 icon.",

        L.Shortcut to "Shortcut", L.Language to "Language", L.Teams to "Teams",
        L.DefaultTeam to "Default team", L.GymFarm to "Gym Farm", L.EmojiMode to "Emoji Mode",
        L.Options to "Options", L.General to "General",
        L.Portuguese to "Portuguese", L.About to "About", L.Version to "Version",
        L.DevelopedBy to "Developed by: Prestrelo", L.ThanksTo to "Thanks: xfallen, allen and tilapia",
        L.Opacity to "Opacity", L.PasteHelp to "View Poképaste",
        L.SourceHelp to "View strategy source",
        L.PokekingBody to "CODE: %s\n\nPaste it in Pokeking (account info → CODE → save) to use this team and extract the solutions.",
        L.CopyCode to "Copy CODE", L.OpenPokeking to "Open Pokeking", L.CodeCopied to "CODE copied",
        L.DocNotFoundTitle to "Official document",
        L.DocNotFoundBody to "We haven't found the official document for this strategy yet.",
        L.SettingsTitle to "Teams & Options", L.OpenSettings to "Teams, Poképastes and settings",
        L.ComingSoon to "coming soon",

        L.ModePickerPrompt to "Choose what to do",

        L.HomeGroupPromptDefault to "Choose:", L.FlatHomePromptDefault to "Tap to choose",
        L.SearchHint to "Search…",

        L.OpponentOnField to "on the field", L.GymLeadWith to "Lead with", L.NextGym to "Next gym",
        L.NextLeadLabel to "Next lead: ", L.SkipThisStop to "Skip this stop",
        L.SeeTeamsConfirmed to "Team confirmed — view", L.SeeTeamsPossible to "View opponent teams",
        L.StepSetupBadge to "POST-BATTLE",
        L.Next to "Next", L.ContinueLabel to "Continue",
        L.OpponentHeaderFacing to "FACING",
        L.ChoosePrompt to "What did the opponent do?",
        L.ConditionalTableTitleDefault to "Choose the move based on the target",
        L.FeedbackThanksOk to "Thanks for the feedback! 💪", L.FeedbackThanksFail to "Thank you! We'll fix it. 🙏",
        L.FeedbackFailPrompt to "What happened? (optional)", L.Send to "Send",
        L.FeedbackDescribe to "Describe…",
        L.FeedbackWorked to "👍 It worked", L.FeedbackDidntWork to "👎 Didn't work",
        L.NextTrainerBadge to "NEXT", L.LeagueCompleted to "🏁 League completed — choose another",
        L.TerminalBadge to "🏆 End of the guide — finish it off and take the win!",

        L.TeamsDistinguishHint to "Tell them apart by item and ability — some are exclusive to one team and confirm which it is.",
        L.TeamsConfirmedTitle to "TEAM CONFIRMED", L.TeamsPossibleTitle to "POSSIBLE TEAMS",
        L.TeamsTeamCardTitle to "Team",

        L.LegendOfMode to "Legend for this mode", L.EmojiSubtitle to "Battle in the author's original notation",
        L.ChooseAction to "Choose what to do",
        L.Restart to "Restart", L.MenuLabel to "Menu",
        L.StepProgress to "step %d/%d",

        // Guia "Como ler o overlay" (#73)
        L.LegendHowToTitle to "How to read the overlay",
        L.LegendHowToArrow to "The green arrow shows the next action to take in the game.",
        L.LegendHowToIcons to "Icons like ↩️ 🗡️ 👏 are explained in this mode's glossary, just below.",
        L.LegendHowToChoose to "Click the option that matches what showed up in the game.",
        L.LegendNewbieTitle to "New to the Elite 4?",
        L.LegendNewbieBody to "Before your 5th win (while the league isn't level 100 yet), the game changes the levels and teams, so the instructions may not match. From the 5th time on they're accurate.",
        L.LegendGotIt to "Got it",
    )
}

/** Idioma persistido nas preferências; na 1ª abertura cai no idioma do aparelho (PT/EN). */
fun langPref(ctx: Context): Lang =
    Lang.from(TeamPrefs.language(ctx) ?: TeamPrefs.deviceDefaultLang())
