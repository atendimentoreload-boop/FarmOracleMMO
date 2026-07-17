package com.reload.prestreloajuda.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.reload.prestreloajuda.BuildConfig
import com.reload.prestreloajuda.FeedbackClient
import com.reload.prestreloajuda.ModeDef
import com.reload.prestreloajuda.categorySubtitle
import com.reload.prestreloajuda.cynthiaMorimotoStrategies
import com.reload.prestreloajuda.FarmRoute
import com.reload.prestreloajuda.farmRoutes
import com.reload.prestreloajuda.farmRoutesIn
import com.reload.prestreloajuda.farmTeamGroupsOrdered
import com.reload.prestreloajuda.farmTeamName
import com.reload.prestreloajuda.redStrategies
import com.reload.prestreloajuda.hoohStrategies
import com.reload.prestreloajuda.loadModes
import com.reload.prestreloajuda.data.OpponentCatalog
import com.reload.prestreloajuda.data.OpponentMon
import com.reload.prestreloajuda.data.OpponentTeam
import com.reload.prestreloajuda.data.SkipStore
import com.reload.prestreloajuda.data.TeamInfo
import com.reload.prestreloajuda.data.TeamPrefs
import com.reload.prestreloajuda.data.TeamsConfig
import com.reload.prestreloajuda.engine.SolveEngine
import com.reload.prestreloajuda.model.EntryGroup
import com.reload.prestreloajuda.model.EntryPoint
import com.reload.prestreloajuda.model.GymLead
import com.reload.prestreloajuda.model.LegendEntry
import com.reload.prestreloajuda.model.Step

private fun openUrl(ctx: Context, url: String) {
    try {
        ctx.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    } catch (_: Exception) {}
}

/** Tradução da chave para o idioma corrente da composição. Espelha o `appModel.t(...)` do Mac. */
@Composable
private fun tr(key: L): String = Strings.text(key, LocalLang.current)

/**
 * BackHandler do Voltar do sistema (botão/gesto) que só se registra quando existe um
 * OnBackPressedDispatcher no contexto — ou seja, no host "Abrir aqui" (a Activity), onde antes
 * o Voltar FECHAVA o app em vez de navegar (#12). Na SOBREPOSIÇÃO (janela do WindowManager, sem
 * Activity) não há dispatcher e o Voltar sequer chega à janela (ela é não-focável fora da busca),
 * então aqui viramos no-op em vez de estourar — o `BackHandler` puro lança se não houver dono.
 */
@Composable
private fun AppBackHandler(enabled: Boolean = true, onBack: () -> Unit) {
    if (LocalOnBackPressedDispatcherOwner.current != null) {
        BackHandler(enabled = enabled, onBack = onBack)
    }
}

/**
 * Estado de navegação da sobreposição, vivo FORA do trecho que é destruído ao minimizar
 * (a bolha/painel alternam no `if (expanded)` do OverlayRoot). Mantê-lo aqui faz com que
 * minimizar e restaurar volte exatamente para onde o usuário estava: mesmo modo, mesma
 * região/líder e mesmo turno do roteiro (o SolveEngine guarda o passo internamente).
 */
class AppState(ctx: Context) {
    val config = TeamsConfig.load(ctx)
    var teamId by mutableStateOf(config.resolve(TeamPrefs.team(ctx)).id)
    var emoji by mutableStateOf(TeamPrefs.emoji(ctx) && config.resolve(teamId).hasEmoji)
    var farmRouteId by mutableStateOf(TeamPrefs.farmRoute(ctx))
    var cmStrategyId by mutableStateOf(TeamPrefs.cynthiaMorimotoStrategy(ctx))
    var redStrategyId by mutableStateOf(TeamPrefs.redStrategy(ctx))
    var hoohStrategyId by mutableStateOf(TeamPrefs.hoohStrategy(ctx))
    var selectedModeId by mutableStateOf<String?>(null)
    var openCategory by mutableStateOf<String?>(null)
    var showSettings by mutableStateOf(false)
    var showCooldowns by mutableStateOf(false)
    var showHowTo by mutableStateOf(false)   // #73: guia "Como ler o overlay"

    // Sistema de Cooldown/Alarme (#33). Criado no startup do host (reconcilia no init os alarmes
    // ainda no futuro) e compartilhado por todas as telas deste AppState.
    val cooldownStore = com.reload.prestreloajuda.data.CooldownStore(ctx.applicationContext)

    // Paradas marcadas para pular: persiste em disco + espelho reativo (modeId::nodeId) p/ a UI.
    private val skipStore = SkipStore(ctx)
    private val skipState = mutableStateMapOf<String, Boolean>()
    private fun skipKey(modeId: String, nodeId: String) = "$modeId::$nodeId"

    fun isSkipped(modeId: String, nodeId: String): Boolean =
        skipState[skipKey(modeId, nodeId)] ?: skipStore.isSkipped(modeId, nodeId)

    fun toggleSkip(modeId: String, nodeId: String) {
        skipStore.toggle(modeId, nodeId)
        skipState[skipKey(modeId, nodeId)] = skipStore.isSkipped(modeId, nodeId)
    }

    // Um SolveEngine por modo, em cache, para a posição turno-a-turno sobreviver ao minimizar.
    private val engines = mutableMapOf<String, SolveEngine>()

    fun engineFor(mode: ModeDef): SolveEngine = engines.getOrPut(mode.id) {
        SolveEngine(mode.solve).apply {
            defaultPortrait = mode.portrait
            defaultTrainerName = if (mode.id == "red") "Red" else mode.title
            shouldAutoSkip = { nodeId -> isSkipped(mode.id, nodeId) }
        }
    }

    /** Trocar de time/emoji recarrega os Solve; descarta os engines em cache. */
    fun resetEngines() = engines.clear()
}

@Composable
fun AppRoot(state: AppState, onSetLanguage: (Lang) -> Unit = {}, onActivateOverlay: (() -> Unit)? = null) {
    val ctx = LocalContext.current
    val config = state.config
    val lang = LocalLang.current
    val modes = remember(state.teamId, state.emoji, state.farmRouteId, state.cmStrategyId, state.redStrategyId, state.hoohStrategyId, lang) {
        loadModes(ctx, config, state.teamId, state.emoji, lang.code, state.farmRouteId, state.cmStrategyId, state.redStrategyId, state.hoohStrategyId)
    }
    val activeTeam = config.resolve(state.teamId)

    fun selectTeam(id: String) {
        if (id == state.teamId) return
        val next = config.resolve(id)
        state.teamId = next.id
        TeamPrefs.setTeam(ctx, next.id)
        if (!next.hasEmoji && state.emoji) { state.emoji = false; TeamPrefs.setEmoji(ctx, false) }
        state.resetEngines()
    }

    fun selectFarmRoute(id: String) {
        if (id == state.farmRouteId) return
        state.farmRouteId = id
        TeamPrefs.setFarmRoute(ctx, id)
        state.resetEngines()
    }

    fun selectCmStrategy(id: String) {
        if (id == state.cmStrategyId) return
        state.cmStrategyId = id
        TeamPrefs.setCynthiaMorimotoStrategy(ctx, id)
        state.resetEngines()
    }

    fun selectRedStrategy(id: String) {
        if (id == state.redStrategyId) return
        state.redStrategyId = id
        TeamPrefs.setRedStrategy(ctx, id)
        state.resetEngines()
    }

    fun selectHoohStrategy(id: String) {
        if (id == state.hoohStrategyId) return
        state.hoohStrategyId = id
        TeamPrefs.setHoohStrategy(ctx, id)
        state.resetEngines()
    }

    fun toggleEmoji() {
        if (config.resolve(state.teamId).hasEmoji) {
            state.emoji = !state.emoji; TeamPrefs.setEmoji(ctx, state.emoji); state.resetEngines()
        }
    }

    Surface(color = Theme.Bg, modifier = Modifier.fillMaxSize()) {
        when {
            state.showHowTo -> HowToCard { state.showHowTo = false }
            state.showCooldowns -> CooldownScreen(state.cooldownStore) { state.showCooldowns = false }
            state.showSettings -> SettingsScreen(
                teams = config.teams,
                activeTeamId = state.teamId,
                activeFarmRouteId = state.farmRouteId,
                activeCmStrategyId = state.cmStrategyId,
                activeRedStrategyId = state.redStrategyId,
                activeHoohStrategyId = state.hoohStrategyId,
                emojiMode = state.emoji,
                emojiAvailable = activeTeam.hasEmoji,
                onSelectTeam = ::selectTeam,
                onSelectFarmRoute = ::selectFarmRoute,
                onSelectCmStrategy = ::selectCmStrategy,
                onSelectRedStrategy = ::selectRedStrategy,
                onSelectHoohStrategy = ::selectHoohStrategy,
                onToggleEmoji = ::toggleEmoji,
                onSetLanguage = onSetLanguage,
                onBack = { state.showSettings = false },
            )
            else -> {
                val sel = state.selectedModeId?.let { id -> modes.firstOrNull { it.id == id } }
                if (sel == null) ModePicker(
                    modes = modes,
                    openCategory = state.openCategory,
                    onOpenCategory = { state.openCategory = it },
                    onOpenSettings = { state.showSettings = true },
                    onOpen = { state.selectedModeId = it.id },
                    onSetLanguage = onSetLanguage,
                    onOpenCooldowns = { state.showCooldowns = true },
                    onOpenHowTo = { state.showHowTo = true },   // #73
                    onActivateOverlay = onActivateOverlay,
                )
                else ModeScreen(sel, state.engineFor(sel), state) { state.selectedModeId = null }
            }
        }
    }
}

// ---------------- Menu de modos ----------------

@Composable
private fun ModePicker(
    modes: List<ModeDef>,
    openCategory: String?,
    onOpenCategory: (String?) -> Unit,
    onOpenSettings: () -> Unit,
    onOpen: (ModeDef) -> Unit,
    onSetLanguage: (Lang) -> Unit,
    onOpenCooldowns: () -> Unit = {},
    onOpenHowTo: () -> Unit = {},   // #73: reabre o guia "Como ler o overlay"
    onActivateOverlay: (() -> Unit)? = null,
) {
    val categories = modes.mapNotNull { it.category }.distinct()
    // Divide os modos soltos pelo bloco de categorias (Elite 4): "antes" (Red, Farm) e
    // "depois" (Cynthia & Morimoto, Ho-Oh) — assim os novos aparecem após a Elite 4.
    val firstCatIdx = modes.indexOfFirst { it.category != null }
    val topBefore = if (firstCatIdx < 0) modes.filter { it.category == null }
        else modes.subList(0, firstCatIdx).filter { it.category == null }
    val topAfter = if (firstCatIdx < 0) emptyList()
        else modes.subList(firstCatIdx + 1, modes.size).filter { it.category == null }
    val lang = LocalLang.current

    // Voltar do sistema dentro de uma categoria (Elite 4) fecha a categoria → menu, igual ao
    // "‹ MENU" do topo. No menu principal (openCategory == null) fica desligado: aí o Voltar faz
    // o padrão (minimiza/sai), que é o topo real da navegação.
    AppBackHandler(enabled = openCategory != null) { onOpenCategory(null) }

    Column(Modifier.fillMaxSize().padding(10.dp)) {
        val cat = openCategory
        if (cat != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("‹ " + tr(L.MenuLabel), color = Theme.Accent, fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp, modifier = Modifier.clickable { onOpenCategory(null) })
                Spacer(Modifier.weight(1f))
                Text(cat, color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Spacer(Modifier.weight(1f))
            }
            Spacer(Modifier.height(8.dp))
            Column(Modifier.verticalScroll(rememberScrollState())) {
                modes.filter { it.category == cat }.forEach { mode ->
                    val region = if (mode.id.startsWith("elite4_")) mode.id.removePrefix("elite4_") else null
                    ModeCard(mode.title, mode.subtitle, region = region, pokepaste = mode.pokepaste) { onOpen(mode) }
                    Spacer(Modifier.height(8.dp))
                }
            }
        } else {
            Row(
                Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // #44: ativar a sobreposição pelo menu (só na janela; no overlay é redundante).
                if (onActivateOverlay != null) {
                    OverlayChip { onActivateOverlay() }
                    Spacer(Modifier.width(8.dp))
                }
                // #73: "?" reabre o guia "Como ler o overlay" (equivale ao "?" do header no Mac).
                HelpChip { onOpenHowTo() }
                Spacer(Modifier.width(8.dp))
                // "Reloginho" (#33): abre a tela de Cooldowns e alarmes, ao lado do chip de idioma.
                ClockChip { onOpenCooldowns() }
                Spacer(Modifier.width(8.dp))
                LangChip(lang) { onSetLanguage(if (lang == Lang.PT) Lang.EN else Lang.PT) }
                Spacer(Modifier.width(8.dp))
                // #44: Configurações vira um chip de engrenagem (antes era um card no fim do menu).
                GearChip { onOpenSettings() }
            }
            Spacer(Modifier.height(6.dp))
            Text(tr(L.ModePickerPrompt), color = Theme.TextDim, fontSize = 12.sp,
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            Column(Modifier.verticalScroll(rememberScrollState())) {
                topBefore.forEach { mode ->
                    ModeCard(mode.title, mode.subtitle, portrait = mode.portrait, item = mode.item,
                        pokepaste = mode.pokepaste, comingSoon = mode.comingSoon) { onOpen(mode) }
                    Spacer(Modifier.height(8.dp))
                }
                categories.forEach { c ->
                    val count = modes.count { it.category == c }
                    // Ícone da categoria igual ao Mac: Elite 4 → taça (trophy); rotas de farm → ginásio (gym).
                    val catItem = if (modes.any { it.category == c && it.id.startsWith("elite4_") }) "trophy" else "gym"
                    ModeCard(c, categorySubtitle(lang.code, count), item = catItem,
                        pokepaste = modes.first { it.category == c }.pokepaste) { onOpenCategory(c) }
                    Spacer(Modifier.height(8.dp))
                }
                topAfter.forEach { mode ->
                    ModeCard(mode.title, mode.subtitle, portrait = mode.portrait, item = mode.item,
                        pokepaste = mode.pokepaste, comingSoon = mode.comingSoon) { onOpen(mode) }
                    Spacer(Modifier.height(8.dp))
                }
                Text(
                    "v${BuildConfig.VERSION_NAME}", color = Theme.TextDim, fontSize = 9.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp).alpha(0.7f)
                )
                CreditsFooter()
            }
        }
    }
}

// ---------------- Entrada para as Configurações ----------------

@Composable
private fun SettingsEntryCard(onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Accent.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .clickable { onClick() }.padding(11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
            Text("⚙", color = Theme.Accent, fontSize = 24.sp)
        }
        Spacer(Modifier.width(8.dp))
        Column(Modifier.weight(1f)) {
            Text(tr(L.MenuLabel), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(tr(L.OpenSettings), color = Theme.TextDim, fontSize = 11.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Text("›", color = Theme.Accent, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun ModeCard(
    title: String, subtitle: String,
    portrait: String? = null, item: String? = null, region: String? = null,
    pokepaste: String? = null, comingSoon: Boolean = false, onPlay: () -> Unit,
) {
    val ctx = LocalContext.current
    Row(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(12.dp))
            .clickable { onPlay() }
            .padding(11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.size(46.dp).alpha(if (comingSoon) 0.55f else 1f),
            contentAlignment = Alignment.Center
        ) {
            when {
                portrait != null -> AssetImage("trainers", portrait, Modifier.size(44.dp))
                item != null -> AssetImage("items", item, Modifier.size(36.dp))
                region != null -> RegionStartersIcon(region)
                else -> Text("⚔", fontSize = 22.sp, color = Theme.Accent)
            }
        }
        Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                if (comingSoon) {
                    Spacer(Modifier.width(6.dp))
                    Box(
                        Modifier.clip(RoundedCornerShape(50)).background(Theme.PasteYellow)
                            .padding(horizontal = 6.dp, vertical = 1.dp)
                    ) {
                        Text(tr(L.ComingSoon).uppercase(), color = Color.Black,
                            fontWeight = FontWeight.Black, fontSize = 8.sp)
                    }
                }
            }
            Text(subtitle, color = Theme.TextDim, fontSize = 12.sp)
        }
        CircleBtn("▶", Theme.Good) { onPlay() }
        if (pokepaste != null) {
            Spacer(Modifier.width(7.dp))
            CircleBtn("?", Theme.PasteYellow) { openUrl(ctx, pokepaste) }
        }
    }
}

@Composable
private fun CircleBtn(glyph: String, color: Color, onClick: () -> Unit) {
    Box(
        Modifier.size(32.dp).clip(CircleShape).background(color).clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(glyph, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

/** "Reloginho" (#33): botão de relógio na tela inicial que abre a tela de Cooldowns e alarmes.
 *  Espelha o clock.arrow.circlepath do Mac, ao lado do chip de idioma. */
@Composable
private fun ClockChip(onClick: () -> Unit) {
    Box(
        Modifier.clip(CircleShape).background(Theme.Panel)
            .border(1.dp, Theme.Border, CircleShape)
            .clickable { onClick() }.padding(horizontal = 8.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("🕐", fontSize = 13.sp)
    }
}

/** #73: chip "?" que reabre o guia "Como ler o overlay", no estilo do reloginho/engrenagem. */
@Composable
private fun HelpChip(onClick: () -> Unit) {
    Box(
        Modifier.clip(CircleShape).background(Theme.Panel)
            .border(1.dp, Theme.Border, CircleShape)
            .clickable { onClick() }.padding(horizontal = 9.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("?", color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 13.sp)
    }
}

/** #44: chip de engrenagem (Configurações) no topo do menu, no estilo do reloginho/idioma. */
@Composable
private fun GearChip(onClick: () -> Unit) {
    Box(
        Modifier.clip(CircleShape).background(Theme.Panel)
            .border(1.dp, Theme.Border, CircleShape)
            .clickable { onClick() }.padding(horizontal = 8.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("⚙️", fontSize = 13.sp)
    }
}

/** #44: chip pra ativar a sobreposição pelo menu (em vez de perguntar no começo). */
@Composable
private fun OverlayChip(onClick: () -> Unit) {
    Box(
        Modifier.clip(CircleShape).background(Theme.Panel)
            .border(1.dp, Theme.Border, CircleShape)
            .clickable { onClick() }.padding(horizontal = 8.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("🟣", fontSize = 13.sp)
    }
}

/** Chip PT⇄EN de acesso rápido na tela inicial (Backlog #13): alterna o idioma na hora,
 *  sem entrar no Menu → Idioma. Reusa onSetLanguage (recompõe tudo + resetEngines). */
@Composable
private fun LangChip(lang: Lang, onToggle: () -> Unit) {
    val flag = if (lang == Lang.PT) "🇧🇷" else "🇺🇸"
    val code = if (lang == Lang.PT) "PT" else "EN"
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(50))
            .clickable { onToggle() }.padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(flag, fontSize = 12.sp)
        Spacer(Modifier.width(5.dp))
        Text(code, color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 11.sp)
        Spacer(Modifier.width(5.dp))
        Text("⇄", color = Theme.Accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

/** Os 3 iniciais de cada região — igual ao RegionStartersIcon do Mac. */
private val regionStarters: Map<String, List<String>> = mapOf(
    "kanto" to listOf("bulbasaur", "charmander", "squirtle"),
    "johto" to listOf("chikorita", "cyndaquil", "totodile"),
    "hoenn" to listOf("treecko", "torchic", "mudkip"),
    "sinnoh" to listOf("turtwig", "chimchar", "piplup"),
    "unova" to listOf("snivy", "tepig", "oshawott"),
)

/**
 * Ícone da região = os 3 iniciais sobrepostos (paridade com o Mac), no lugar do mapa.
 * Diferente do Mac, desenhamos o do MEIO por último (ordem 0,2,1) pra o inicial de fogo
 * não ficar escondido atrás do 3º — corrige o "fogo some" (Backlog #8). Cai pro mapa se
 * a região não estiver mapeada.
 */
@Composable
private fun RegionStartersIcon(region: String) {
    val names = regionStarters[region.lowercase()]
    if (names == null) { AssetImage("regions", region, Modifier.size(40.dp)); return }
    val sprite = 30.dp
    val step = 7.dp
    Box(Modifier.size(44.dp)) {
        listOf(0, 2, 1).forEach { i ->
            AssetImage("sprites", names[i], Modifier.size(sprite).offset(x = step * i, y = step))
        }
    }
}

// ---------------- Tela de Configurações (Times e Opções) ----------------

/**
 * Menu de Configurações em estilo "lista de opções", porte do SettingsView.swift do Mac:
 * Times marcáveis (lista, não mais ciclo) + Modo Emoji + opacidade do overlay + idioma + sobre.
 */
@Composable
private fun SettingsScreen(
    teams: List<TeamInfo>,
    activeTeamId: String,
    activeFarmRouteId: String,
    activeCmStrategyId: String,
    activeRedStrategyId: String,
    activeHoohStrategyId: String,
    emojiMode: Boolean,
    emojiAvailable: Boolean,
    onSelectTeam: (String) -> Unit,
    onSelectFarmRoute: (String) -> Unit,
    onSelectCmStrategy: (String) -> Unit,
    onSelectRedStrategy: (String) -> Unit,
    onSelectHoohStrategy: (String) -> Unit,
    onToggleEmoji: () -> Unit,
    onSetLanguage: (Lang) -> Unit,
    onBack: () -> Unit,
) {
    val ctx = LocalContext.current
    val lang = LocalLang.current
    val opacityCtl = LocalOpacityController.current
    var langPanel by remember { mutableStateOf(false) }
    var pokekingPanel by remember { mutableStateOf<TeamSource.Pokeking?>(null) }
    var notFoundPanel by remember { mutableStateOf(false) }
    // Grupos de time abertos nas Configurações. Vazio = todos recolhidos (a lista de times de cada
    // modo só aparece ao clicar no cabeçalho — porte do collapsibleTeamGroup do Mac/Windows; evita
    // poluir o menu com muitos times). Como é `remember` local, reseta ao reabrir as Configurações
    // (igual ao @State do Mac). Selecionar um time NÃO fecha o grupo (o estado persiste no render).
    var expandedTeamGroups by remember { mutableStateOf(setOf<String>()) }
    val toggleTeamGroup: (String) -> Unit = { key ->
        expandedTeamGroups = if (key in expandedTeamGroups) expandedTeamGroups - key else expandedTeamGroups + key
    }
    val onSourcePanel: (TeamSource) -> Unit = { s ->
        when (s) {
            is TeamSource.Pokeking -> pokekingPanel = s
            is TeamSource.NotFound -> notFoundPanel = true
            else -> {}
        }
    }

    // Voltar do sistema nas Configurações: fecha primeiro um sub-painel aberto (Pokeking/idioma/
    // "não encontrado") e só então volta ao menu — espelha o "‹" do cabeçalho.
    AppBackHandler {
        when {
            pokekingPanel != null -> pokekingPanel = null
            notFoundPanel -> notFoundPanel = false
            langPanel -> langPanel = false
            else -> onBack()
        }
    }

    Column(Modifier.fillMaxSize()) {
        // Cabeçalho
        val anyPanel = langPanel || pokekingPanel != null || notFoundPanel
        val headerTitle = when {
            langPanel -> tr(L.Language)
            pokekingPanel != null -> "Pokeking"
            notFoundPanel -> tr(L.DocNotFoundTitle)
            else -> tr(L.SettingsTitle)
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "‹ ${if (anyPanel) tr(L.MenuLabel) else tr(L.Back)}",
                color = Theme.Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                modifier = Modifier.clickable {
                    when {
                        pokekingPanel != null -> pokekingPanel = null
                        notFoundPanel -> notFoundPanel = false
                        langPanel -> langPanel = false
                        else -> onBack()
                    }
                }
            )
            Spacer(Modifier.weight(1f))
            Text(
                headerTitle.uppercase(),
                color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 12.sp
            )
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.width(50.dp))
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Theme.Border))

        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(12.dp)) {
            if (langPanel) {
                SettingsGroup {
                    LanguageRow("🇧🇷", tr(L.Portuguese), lang == Lang.PT) { onSetLanguage(Lang.PT) }
                    RowDivider()
                    LanguageRow("🇺🇸", "English", lang == Lang.EN) { onSetLanguage(Lang.EN) }
                }
                return@Column
            }
            // Painel do CODE do Pokeking (igual ao diálogo do Mac, em painel inline).
            pokekingPanel?.let { pk ->
                SettingsGroup {
                    Column(Modifier.padding(14.dp)) {
                        Text("Pokeking — ${pk.team}", color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                        Spacer(Modifier.height(8.dp))
                        Text(String.format(tr(L.PokekingBody), pk.code), color = Theme.Text, fontSize = 12.sp)
                        Spacer(Modifier.height(14.dp))
                        val codeCopiedMsg = tr(L.CodeCopied)
                        Row {
                            Box(Modifier.clip(RoundedCornerShape(8.dp)).background(Theme.Good).clickable {
                                val cb = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                cb.setPrimaryClip(android.content.ClipData.newPlainText("Pokeking", pk.code))
                                android.widget.Toast.makeText(ctx, codeCopiedMsg, android.widget.Toast.LENGTH_SHORT).show()
                            }.padding(horizontal = 14.dp, vertical = 8.dp)) {
                                Text(tr(L.CopyCode), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                            Spacer(Modifier.width(10.dp))
                            Box(Modifier.clip(RoundedCornerShape(8.dp)).border(1.dp, Theme.Accent, RoundedCornerShape(8.dp))
                                .clickable { openUrl(ctx, "https://pokeking.icu") }.padding(horizontal = 14.dp, vertical = 8.dp)) {
                                Text(tr(L.OpenPokeking), color = Theme.Accent, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
                return@Column
            }
            if (notFoundPanel) {
                SettingsGroup {
                    Column(Modifier.padding(14.dp)) {
                        Text(tr(L.DocNotFoundTitle), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Spacer(Modifier.height(8.dp))
                        Text(tr(L.DocNotFoundBody), color = Theme.TextDim, fontSize = 12.sp)
                    }
                }
                return@Column
            }

            // ----- TIMES -----
            SectionLabel(tr(L.Teams))

            val gymFarmLabel = tr(L.GymFarm)

            // Red: estratégias/times selecionáveis (Pós Choice Nerf / Colored), igual às rotas de farm.
            CollapsibleTeamGroup(
                title = "Red",
                icon = { AssetImage("trainers", "red", Modifier.size(24.dp)) },
                selected = redStrategies.firstOrNull { it.id == activeRedStrategyId }?.name,
                isOpen = "Red" in expandedTeamGroups,
                onToggle = { toggleTeamGroup("Red") },
            ) {
                redStrategies.forEachIndexed { idx, strat ->
                    if (idx > 0) RowDivider()
                    TeamLineRow(
                        icon = { AssetImage("sprites", strat.pokemon, Modifier.size(28.dp)) },
                        name = strat.name,
                        sub = strat.roster,
                        pokepaste = strat.pokepaste,
                        selected = strat.id == activeRedStrategyId,
                        onSelect = { onSelectRedStrategy(strat.id) },
                        source = strat.doc?.let { TeamSource.Doc(it) }, onSourcePanel = onSourcePanel,
                    )
                }
            }

            // Farm de Ginásios: rotas selecionáveis AGRUPADAS por time (teamGroup), igual ao Mac.
            // Grupo com 1 rota = linha normal; grupo com N rotas = cabeçalho do time (nome + roster +
            // Poképaste/doc, uma vez) + sub-linhas compactas por variante (indentadas).
            val activeFarmRoute = farmRoutes.firstOrNull { it.id == activeFarmRouteId }
            CollapsibleTeamGroup(
                title = gymFarmLabel,
                icon = { AssetImage("items", "gym", Modifier.size(20.dp)) },
                selected = activeFarmRoute?.let { "${farmTeamName(it.teamGroup)} · ${it.variant}" },
                isOpen = gymFarmLabel in expandedTeamGroups,
                onToggle = { toggleTeamGroup(gymFarmLabel) },
            ) {
                farmTeamGroupsOrdered.forEachIndexed { gi, group ->
                    val routes = farmRoutesIn(group)
                    if (gi > 0) RowDivider()
                    if (routes.size == 1) {
                        val r = routes[0]
                        TeamLineRow(
                            icon = { AssetImage("items", "gym", Modifier.size(24.dp)) },
                            name = r.name,
                            sub = r.roster,
                            pokepaste = r.pokepaste,
                            selected = r.id == activeFarmRouteId,
                            onSelect = { onSelectFarmRoute(r.id) },
                            source = r.doc?.let { TeamSource.Doc(it) }, onSourcePanel = onSourcePanel,
                        )
                    } else {
                        // MESMO time, várias rotas → cabeçalho do time (roster + Poképaste/doc) + variantes.
                        FarmTeamHeader(group, routes)
                        routes.forEach { r ->
                            FarmVariantRow(
                                route = r,
                                selected = r.id == activeFarmRouteId,
                                onSelect = { onSelectFarmRoute(r.id) },
                            )
                        }
                    }
                }
            }

            // Cynthia & Morimoto: estratégias/times selecionáveis, igual às rotas de farm.
            CollapsibleTeamGroup(
                title = "Cynthia & Morimoto",
                icon = { AssetImage("trainers", "cynthia", Modifier.size(24.dp)) },
                selected = cynthiaMorimotoStrategies.firstOrNull { it.id == activeCmStrategyId }?.name,
                isOpen = "Cynthia & Morimoto" in expandedTeamGroups,
                onToggle = { toggleTeamGroup("Cynthia & Morimoto") },
            ) {
                cynthiaMorimotoStrategies.forEachIndexed { idx, strat ->
                    if (idx > 0) RowDivider()
                    TeamLineRow(
                        icon = { AssetImage("trainers", "cynthia", Modifier.size(28.dp)) },
                        name = strat.name,
                        sub = strat.roster,
                        pokepaste = strat.pokepaste,
                        selected = strat.id == activeCmStrategyId,
                        onSelect = { onSelectCmStrategy(strat.id) },
                        source = strat.doc?.let { TeamSource.Doc(it) } ?: TeamSource.NotFound, onSourcePanel = onSourcePanel,
                    )
                }
            }

            // Ho-Oh: estratégias/times selecionáveis (Alllen - Yatsura / Trick Room), igual ao Red.
            CollapsibleTeamGroup(
                title = "Ho-Oh",
                icon = { AssetImage("sprites", "hooh", Modifier.size(22.dp)) },
                selected = hoohStrategies.firstOrNull { it.id == activeHoohStrategyId }?.name,
                isOpen = "Ho-Oh" in expandedTeamGroups,
                onToggle = { toggleTeamGroup("Ho-Oh") },
            ) {
                hoohStrategies.forEachIndexed { idx, strat ->
                    if (idx > 0) RowDivider()
                    TeamLineRow(
                        icon = { AssetImage("sprites", strat.pokemon, Modifier.size(28.dp)) },
                        name = strat.name,
                        sub = strat.roster,
                        pokepaste = strat.pokepaste,
                        selected = strat.id == activeHoohStrategyId,
                        onSelect = { onSelectHoohStrategy(strat.id) },
                        source = strat.video?.let { TeamSource.Video(it) }, onSourcePanel = onSourcePanel,
                    )
                }
            }

            // Elite 4: lista de times marcável + Modo Emoji.
            CollapsibleTeamGroup(
                title = "Elite 4",
                icon = { AssetImage("items", "trophy", Modifier.size(20.dp)) },
                selected = teams.firstOrNull { it.id == activeTeamId }?.name,
                isOpen = "Elite 4" in expandedTeamGroups,
                onToggle = { toggleTeamGroup("Elite 4") },
            ) {
                teams.forEachIndexed { idx, team ->
                    if (idx > 0) RowDivider()
                    TeamLineRow(
                        icon = {
                            if (team.icon != null) AssetImage("sprites", team.icon, Modifier.size(28.dp))
                            else Text("⚔", color = Theme.Accent, fontSize = 18.sp)
                        },
                        name = team.name,
                        sub = team.pokemon.joinToString(", ").takeIf { it.isNotEmpty() },
                        pokepaste = team.pokepaste,
                        selected = team.id == activeTeamId,
                        onSelect = { onSelectTeam(team.id) },
                        source = team.code?.let { TeamSource.Pokeking(it, team.name) }, onSourcePanel = onSourcePanel,
                    )
                }
                if (emojiAvailable) {
                    RowDivider()
                    ToggleRow("😀", tr(L.EmojiMode), emojiMode, onToggleEmoji)
                }
            }

            // ----- OPÇÕES -----
            Spacer(Modifier.height(8.dp))
            SectionLabel(tr(L.Options))

            if (opacityCtl != null) {
                GroupLabel("Overlay")
                SettingsGroup { OpacityRow(opacityCtl) }
            }

            GroupLabel(tr(L.General))
            SettingsGroup {
                NavRow("🌐", tr(L.Language),
                    if (lang == Lang.EN) "English" else tr(L.Portuguese), enabled = true) {
                    langPanel = true
                }
            }

            GroupLabel(tr(L.About))
            SettingsGroup {
                InfoRow("ℹ", tr(L.Version), "v${BuildConfig.VERSION_NAME}")
            }

            CreditsFooter()
        }
    }
}

/** Rodapé de créditos (Desenvolvido por / Agradecimentos + ícones de Discord e YouTube).
 *  Reutilizado na página inicial (ModePicker) e nas Configurações. Links centralizados aqui. */
@Composable
private fun CreditsFooter() {
    val ctx = LocalContext.current
    val discord = "https://discord.gg/9jCuB6BDBC"          // NOSSO Discord (FarmOracleMMO)
    val youtube = "https://youtube.com/@viniciosprestrelo44?si=B18HIMXP0cg2Mq74"
    Column(
        Modifier.fillMaxWidth().padding(top = 14.dp, bottom = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(tr(L.DevelopedBy), color = Theme.TextDim, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(2.dp))
        Text(tr(L.ThanksTo), color = Theme.TextDim.copy(alpha = 0.85f), fontSize = 9.sp)
        Spacer(Modifier.height(7.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            Box(Modifier.clickable { openUrl(ctx, discord) }) {
                AssetImage("items", "discord", Modifier.size(30.dp))
            }
            Box(Modifier.clickable { openUrl(ctx, youtube) }) {
                AssetImage("items", "youtube", Modifier.size(30.dp))
            }
        }
    }
}

@Composable
private fun SettingsGroup(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(12.dp)),
        content = content
    )
}

@Composable
private fun SectionLabel(text: String) {
    Text(text.uppercase(), color = Theme.Text, fontWeight = FontWeight.Black, fontSize = 12.sp,
        modifier = Modifier.padding(bottom = 2.dp))
}

@Composable
private fun GroupLabel(text: String) {
    Text(text.uppercase(), color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 9.sp,
        modifier = Modifier.padding(top = 6.dp, start = 4.dp, bottom = 2.dp))
}

/** Cabeçalho de grupo de time RECOLHÍVEL (porte do collapsibleTeamGroup do Mac / CollapsibleTeamGroup
 *  do Windows): recolhido mostra só o ícone + nome do modo + o time ativo + chevron; clicar expande a
 *  lista de times. O estado (aberto/fechado) vem de fora (`expandedTeamGroups` no SettingsScreen), então
 *  selecionar um time NÃO fecha o grupo. Evita poluir o menu quando há muitos times. */
@Composable
private fun CollapsibleTeamGroup(
    title: String,
    icon: @Composable () -> Unit,
    selected: String?,
    isOpen: Boolean,
    onToggle: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().clickable { onToggle() }
            .padding(top = 6.dp, start = 4.dp, end = 4.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) { icon() }
        Spacer(Modifier.width(8.dp))
        Text(title.uppercase(), color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 9.sp)
        Spacer(Modifier.weight(1f))
        if (!isOpen && !selected.isNullOrEmpty()) {
            Text(selected, color = Theme.TextDim, fontSize = 10.sp, maxLines = 1,
                overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 150.dp))
            Spacer(Modifier.width(6.dp))
        }
        Text(if (isOpen) "▼" else "▶", color = Theme.TextDim, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
    if (isOpen) SettingsGroup(content = content)
}

@Composable
private fun RowDivider() {
    Box(Modifier.fillMaxWidth().padding(start = 42.dp).height(1.dp).background(Theme.Line))
}

/** Fonte da estratégia mostrada no botão ao lado do time (igual ao Mac). */
sealed class TeamSource {
    data class Doc(val url: String) : TeamSource()
    data class Video(val url: String) : TeamSource()
    data class Pokeking(val code: String, val team: String) : TeamSource()
    object NotFound : TeamSource()
}

@Composable
private fun TeamLineRow(
    icon: @Composable () -> Unit,
    name: String,
    sub: String?,
    pokepaste: String?,
    selected: Boolean,
    onSelect: (() -> Unit)?,
    source: TeamSource? = null,
    onSourcePanel: ((TeamSource) -> Unit)? = null,
) {
    val ctx = LocalContext.current
    Row(
        Modifier.fillMaxWidth()
            .then(if (onSelect != null) Modifier.clickable { onSelect() } else Modifier)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(30.dp), contentAlignment = Alignment.Center) { icon() }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(name, color = Theme.Text, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            if (sub != null) Text(sub, color = Theme.TextDim, fontSize = 9.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (pokepaste != null) {
            Spacer(Modifier.width(8.dp))
            Box(
                Modifier.size(24.dp).clip(CircleShape).background(Theme.PasteYellow)
                    .clickable { openUrl(ctx, pokepaste) },
                contentAlignment = Alignment.Center
            ) { Text("?", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
        }
        if (source != null) {
            Spacer(Modifier.width(6.dp))
            val glyph = when (source) {
                is TeamSource.Video -> "▶"
                is TeamSource.Pokeking -> "i"
                is TeamSource.NotFound -> "!"
                is TeamSource.Doc -> "↗"
            }
            val bg = if (source is TeamSource.Video) Color(0xFFE63832) else Color(0xFF5C99F2)
            Box(
                Modifier.size(24.dp).clip(CircleShape).background(bg).clickable {
                    when (source) {
                        is TeamSource.Doc -> openUrl(ctx, source.url)
                        is TeamSource.Video -> openUrl(ctx, source.url)
                        else -> onSourcePanel?.invoke(source)
                    }
                },
                contentAlignment = Alignment.Center
            ) { Text(glyph, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
        }
        Spacer(Modifier.width(8.dp))
        Text(
            if (selected) "◉" else "○",
            color = if (selected) Theme.Good else Theme.TextDim.copy(alpha = 0.45f),
            fontSize = 16.sp, fontWeight = FontWeight.Bold
        )
    }
}

/** Cabeçalho de um time de farm com VÁRIAS rotas: nome do time + roster + Poképaste/doc (uma vez só).
 *  Porte do farmTeamHeader do Mac — usa a 1ª rota do grupo como referência de roster/links. */
@Composable
private fun FarmTeamHeader(group: String, routes: List<FarmRoute>) {
    val ctx = LocalContext.current
    val r = routes.first()
    Row(
        Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(30.dp), contentAlignment = Alignment.Center) {
            AssetImage("items", "gym", Modifier.size(24.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(farmTeamName(group), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Text(r.roster, color = Theme.TextDim, fontSize = 9.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(8.dp))
        Box(
            Modifier.size(24.dp).clip(CircleShape).background(Theme.PasteYellow)
                .clickable { openUrl(ctx, r.pokepaste) },
            contentAlignment = Alignment.Center
        ) { Text("?", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
        r.doc?.let { doc ->
            Spacer(Modifier.width(6.dp))
            Box(
                Modifier.size(24.dp).clip(CircleShape).background(Color(0xFF5C99F2))
                    .clickable { openUrl(ctx, doc) },
                contentAlignment = Alignment.Center
            ) { Text("↗", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
        }
    }
}

/** Linha compacta de uma VARIANTE de rota (dentro do submenu do time): indicador + nome curto,
 *  indentado. Porte do farmVariantRow do Mac. Selecionar chama o setter existente (onSelectFarmRoute). */
@Composable
private fun FarmVariantRow(route: FarmRoute, selected: Boolean, onSelect: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onSelect() }
            .padding(start = 42.dp, end = 12.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            if (selected) "◉" else "○",
            color = if (selected) Theme.Good else Theme.TextDim.copy(alpha = 0.45f),
            fontSize = 14.sp, fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.width(8.dp))
        Text(route.variant, color = Theme.Text, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
    }
}

@Composable
private fun ToggleRow(glyph: String, title: String, on: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 12.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(glyph, fontSize = 15.sp, modifier = Modifier.padding(end = 10.dp))
        Text(title, color = Theme.Text, fontWeight = FontWeight.Medium, fontSize = 13.sp,
            modifier = Modifier.weight(1f))
        Box(
            Modifier.clip(RoundedCornerShape(50)).background(if (on) Theme.Good else Theme.PanelHi)
                .padding(horizontal = 10.dp, vertical = 4.dp)
        ) {
            Text(if (on) "ON" else "OFF", color = if (on) Color.Black else Theme.TextDim,
                fontSize = 11.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun OpacityRow(ctl: OpacityController) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 11.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("◐", color = Theme.Accent, fontSize = 14.sp, modifier = Modifier.padding(end = 10.dp))
            Text(tr(L.Opacity), color = Theme.Text, fontWeight = FontWeight.Medium, fontSize = 13.sp,
                modifier = Modifier.weight(1f))
            Text("${(ctl.opacity * 100).toInt()}%", color = Theme.Accent,
                fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
        Spacer(Modifier.height(6.dp))
        androidx.compose.material3.Slider(
            value = ctl.opacity,
            onValueChange = { ctl.setOpacity(it) },
            valueRange = OpacityController.MIN..OpacityController.MAX,
            colors = androidx.compose.material3.SliderDefaults.colors(
                thumbColor = Theme.Accent,
                activeTrackColor = Theme.Accent,
                inactiveTrackColor = Theme.PanelHi,
            ),
            modifier = Modifier.fillMaxWidth().padding(start = 24.dp)
        )
    }
}

@Composable
private fun NavRow(glyph: String, title: String, value: String, enabled: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth()
            .then(if (enabled) Modifier.clickable { onClick() } else Modifier)
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(glyph, color = Theme.Accent, fontSize = 14.sp, modifier = Modifier.padding(end = 10.dp))
        Text(title, color = Theme.Text, fontWeight = FontWeight.Medium, fontSize = 13.sp)
        Spacer(Modifier.weight(1f))
        Text(value, color = Theme.TextDim, fontSize = 12.sp, maxLines = 1,
            overflow = TextOverflow.Ellipsis)
        if (enabled) {
            Spacer(Modifier.width(6.dp))
            Text("›", color = Theme.TextDim.copy(alpha = 0.7f), fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun InfoRow(glyph: String, title: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(glyph, color = Theme.Accent, fontSize = 14.sp, modifier = Modifier.padding(end = 10.dp))
        Text(title, color = Theme.Text, fontWeight = FontWeight.Medium, fontSize = 13.sp)
        Spacer(Modifier.weight(1f))
        Text(value, color = Theme.TextDim, fontWeight = FontWeight.Bold, fontSize = 12.sp)
    }
}

@Composable
private fun LanguageRow(flag: String, name: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 12.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(flag, fontSize = 16.sp, modifier = Modifier.width(24.dp))
        Spacer(Modifier.width(6.dp))
        Text(name, color = Theme.Text, fontWeight = FontWeight.Medium, fontSize = 13.sp,
            modifier = Modifier.weight(1f))
        if (selected) Text("◉", color = Theme.Good, fontSize = 15.sp, fontWeight = FontWeight.Bold)
    }
}

// ---------------- Tela de um modo ----------------

@Composable
private fun ModeScreen(mode: ModeDef, engine: SolveEngine, state: AppState, onExit: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.clip(RoundedCornerShape(50)).background(Theme.Accent)
                    .clickable { onExit() }.padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text("‹ " + tr(L.MenuLabel), color = Color.Black, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            }
            Spacer(Modifier.width(8.dp))
            Text(mode.title, color = Theme.Text, fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        var teamsData by remember(mode.id) { mutableStateOf<PossibleTeams?>(null) }
        // Voltar do sistema num modo aberto, um nível por vez (espelha ✕ / "‹ Voltar" / "‹ MENU"):
        // fecha o overlay "Ver times" → volta um passo do roteiro → fecha a lista de leads do grupo
        // → sai do modo para o menu. Nunca fecha o app aqui.
        AppBackHandler {
            when {
                teamsData != null -> teamsData = null
                engine.canGoBack -> engine.back()
                engine.selectedGroupName != null -> engine.selectedGroupName = null
                else -> onExit()
            }
        }
        Box(Modifier.weight(1f)) {
            if (engine.currentNodeId == null)
                HomeView(
                    engine,
                    allowSkip = mode.solve.allowSkip == true,
                    isSkipped = { state.isSkipped(mode.id, it) },
                    onToggleSkip = { state.toggleSkip(mode.id, it) },
                )
            else NodeView(engine, mode, state.teamId, onExit, onShowTeams = { teamsData = it })
            teamsData?.let { TeamsOverlay(it) { teamsData = null } }
        }
        Row(Modifier.fillMaxWidth().padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            PillBtn("‹ " + tr(L.Back)) { engine.back() }
            Spacer(Modifier.width(8.dp))
            PillBtn("⟲ " + tr(L.Restart)) { engine.reset() }

            // Indicador "passo x/y" — espelha Mac/Windows: só em solves multi-passo (não revealAll).
            val progressNode = engine.currentNode
            if (engine.solve.revealAll != true && progressNode != null && progressNode.steps.isNotEmpty()) {
                Spacer(Modifier.weight(1f))
                val current = minOf(engine.stepIndex + 1, progressNode.steps.size)
                Text(
                    String.format(tr(L.StepProgress), current, progressNode.steps.size),
                    color = Theme.TextDim,
                    fontSize = 10.sp,
                )
            }
        }
    }
}

@Composable
private fun PillBtn(text: String, onClick: () -> Unit) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).background(Theme.Panel)
            .clickable { onClick() }.padding(horizontal = 12.dp, vertical = 6.dp)
    ) { Text(text, color = Theme.Text, fontSize = 12.sp) }
}

// ---------------- Tela inicial (entradas) ----------------

/**
 * Largura REAL do painel/conteúdo, em dp-base (sem o zoom do conteúdo), alimentada por quem
 * hospeda o AppRoot (overlay = largura do painel; Activity = largura da tela). O layout reage
 * a ISSO, não à orientação — painel largo = mais colunas e cards compactos; estreito = espaçoso.
 */
val LocalContentWidthDp = androidx.compose.runtime.compositionLocalOf { 320f }

/**
 * Avisa o serviço do overlay quando a BUSCA ganha/perde foco, pra ele tornar a janela focável
 * só durante a digitação (e não-focável o resto do tempo, deixando tocar/andar no jogo).
 * Null fora do overlay (ex.: modo "Abrir aqui", onde a Activity já é focável).
 */
val LocalSearchFocus = androidx.compose.runtime.compositionLocalOf<((Boolean) -> Unit)?> { null }

/** Largura atual do conteúdo (dp). */
@Composable
private fun contentWidth(): Float = LocalContentWidthDp.current

/** "Largo" = a partir daqui usamos o layout compacto/denso (esconde avisos, aperta o respiro). */
@Composable
private fun isWide(): Boolean = contentWidth() >= 420f

/** Nº de colunas da grade de leads, reativo à largura (≈110dp por card), de 2 a 6. */
@Composable
private fun gridColumns(): Int = (contentWidth() / 110f).toInt().coerceIn(2, 6)

private fun filterEntries(entries: List<EntryPoint>, q: String): List<EntryPoint> {
    val s = q.trim().lowercase()
    return if (s.isEmpty()) entries else entries.filter { it.label.lowercase().contains(s) }
}

@Composable
private fun HomeView(
    engine: SolveEngine,
    allowSkip: Boolean,
    isSkipped: (String) -> Boolean,
    onToggleSkip: (String) -> Unit,
) {
    val solve = engine.solve
    var search by remember(solve.id) { mutableStateOf("") }
    // Painel largo: layout compacto e focado no caminho — sem os avisos (que comem a tela),
    // grade mais densa, menos respiro. Reage à LARGURA real do painel (não à orientação).
    val wide = isWide()

    Column(Modifier.fillMaxSize().padding(if (wide) 7.dp else 10.dp)) {
        if (!wide) {
            solve.lead?.let { LeadBanner(it) }
            // Aviso "5ª vez" da Elite 4 fica OCULTO no celular (regra fixa do usuário — 23/06).
            if (!solve.id.startsWith("elite4_")) solve.warning?.let { WarningBanner(it) }
        }
        solve.legend?.takeIf { it.isNotEmpty() }?.let { LegendCard(it) }
        val groups = solve.groups
        if (groups != null) {
            val g = engine.selectedGroupName?.let { n -> groups.firstOrNull { it.name == n } }
            if (g == null) {
                Text(solve.groupPrompt ?: tr(L.HomeGroupPromptDefault), color = Theme.TextDim, fontSize = 11.sp,
                    textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp))
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    groups.forEach { grp ->
                        // Sem portrait (rotas de farm) → mostra os 3 iniciais da região, igual ao Mac.
                        RowButton(grp.name, grp.portrait, "trainers",
                            regionName = if (grp.portrait == null) grp.name else null) {
                            engine.selectedGroupName = grp.name; search = ""
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            } else {
                RowButton("‹ ${g.name}", null, null) { engine.selectedGroupName = null }
                Spacer(Modifier.height(6.dp))
                SearchField(search) { search = it }
                Spacer(Modifier.height(8.dp))
                EntryFlow(filterEntries(g.entries, search), engine, g.name, allowSkip, isSkipped, onToggleSkip)
            }
        } else {
            Text(solve.homePrompt ?: tr(L.FlatHomePromptDefault), color = Theme.TextDim, fontSize = 11.sp,
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp))
            SearchField(search) { search = it }
            Spacer(Modifier.height(8.dp))
            EntryFlow(filterEntries(solve.entryPoints ?: emptyList(), search), engine, null, allowSkip, isSkipped, onToggleSkip)
        }
    }
}

@Composable
private fun WarningBanner(text: String) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.WarningSoft)
            .border(1.dp, Theme.Warning.copy(alpha = 0.35f), RoundedCornerShape(10.dp))
            .padding(horizontal = 9.dp, vertical = 7.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text("⚠️ ", fontSize = 12.sp)
        Text(text, color = Theme.Warning, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun LegendCard(legend: List<LegendEntry>) {
    var open by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(10.dp))
    ) {
        Row(
            Modifier.fillMaxWidth().clickable { open = !open }.padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("📖 " + tr(L.LegendOfMode), color = Theme.Text, fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp, modifier = Modifier.weight(1f))
            Text(if (open) "▲" else "▼", color = Theme.TextDim, fontSize = 11.sp)
        }
        if (open) {
            Column(Modifier.fillMaxWidth().padding(start = 10.dp, end = 10.dp, bottom = 10.dp)) {
                legend.forEach { item ->
                    Text(item.term, color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    Text(item.meaning, color = Theme.TextDim, fontSize = 11.sp,
                        modifier = Modifier.padding(bottom = 6.dp))
                }
            }
        }
    }
    Spacer(Modifier.height(8.dp))
}

/**
 * #73: guia "Como ler o overlay". Porte fiel do LegendView.howToCard do Mac: título + 3 dicas
 * (seta/ícones/escolha) + sub-card de aviso da "5ª vez" + "Entendi". No Android abre SOMENTE
 * pelo "?" (nunca sozinho — regra fixa de não auto-exibir avisos da Elite 4 no celular); o
 * callout amarelo é opt-in, só aparece quando o usuário toca no "?". Tela própria porque no
 * Android o glossário mora inline no HomeView.
 */
@Composable
private fun HowToCard(onClose: () -> Unit) {
    // Voltar do sistema fecha o guia (igual às telas de Configurações/Cooldowns).
    AppBackHandler { onClose() }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(12.dp)
    ) {
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(Theme.Panel).padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(tr(L.LegendHowToTitle), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 14.sp)

            HowToRow(tr(L.LegendHowToArrow))
            HowToRow(tr(L.LegendHowToIcons))
            HowToRow(tr(L.LegendHowToChoose))

            // Sub-card amarelo: aviso da "5ª vez" da Elite 4 (níveis/times mudam antes disso).
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(Theme.PanelHi).padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("⚠️", fontSize = 11.sp)
                    Spacer(Modifier.width(6.dp))
                    Text(tr(L.LegendNewbieTitle), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }
                Text(tr(L.LegendNewbieBody), color = Theme.TextDim, fontSize = 11.sp)
            }

            // "Entendi" (accent, largura total) — fecha o guia.
            Box(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(Theme.Accent)
                    .clickable { onClose() }.padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(tr(L.LegendGotIt), color = Color.Black, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            }
        }
    }
}

/** Uma dica do guia: seta "→" (accent, mono, largura fixa) + texto que quebra linha. */
@Composable
private fun HowToRow(text: String) {
    Row(verticalAlignment = Alignment.Top) {
        Text(
            "→", color = Theme.Accent, fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace, fontSize = 12.sp,
            textAlign = TextAlign.Center, modifier = Modifier.width(14.dp)
        )
        Spacer(Modifier.width(8.dp))
        Text(text, color = Theme.TextDim, fontSize = 11.sp, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun LeadBanner(text: String) {
    Box(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.AccentSoft)
            .padding(8.dp), contentAlignment = Alignment.Center
    ) {
        Text("🔥 $text", color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 13.sp,
            textAlign = TextAlign.Center)
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun RowButton(label: String, image: String?, dir: String?, regionName: String? = null, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(11.dp)).clickable { onClick() }
            .padding(12.dp), verticalAlignment = Alignment.CenterVertically
    ) {
        when {
            image != null && dir != null -> {
                AssetImage(dir, image, Modifier.size(34.dp)); Spacer(Modifier.width(10.dp))
            }
            regionName != null -> {
                RegionStartersIcon(regionName); Spacer(Modifier.width(10.dp))
            }
        }
        Text(label, color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 14.sp)
    }
}

@Composable
private fun EntryFlow(
    entries: List<EntryPoint>,
    engine: SolveEngine,
    groupName: String?,
    allowSkip: Boolean,
    isSkipped: (String) -> Boolean,
    onToggleSkip: (String) -> Unit,
) {
    Column(Modifier.verticalScroll(rememberScrollState())) {
        if (allowSkip) {
            // Rota de farm: lista com marcador de "pular" por parada.
            // #42 (Lewis): os marcados pra pular SOMEM da lista; um botão reexibe pra desmarcar.
            val lang = LocalLang.current
            var showSkipped by remember { mutableStateOf(false) }
            val visible = entries.filter { !isSkipped(it.nodeId) }
            val skippedList = entries.filter { isSkipped(it.nodeId) }
            visible.forEach { e ->
                EntrySkipRow(
                    e, false,
                    onToggle = { onToggleSkip(e.nodeId) },
                    onOpen = { engine.jumpTo(e.nodeId, e.label, groupName) },
                )
            }
            if (skippedList.isNotEmpty()) {
                Box(
                    Modifier.fillMaxWidth().padding(top = 4.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Theme.Panel.copy(alpha = 0.5f))
                        .border(1.dp, Theme.Border, RoundedCornerShape(8.dp))
                        .clickable { showSkipped = !showSkipped }
                        .padding(vertical = 6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        if (showSkipped) (if (lang == Lang.PT) "Ocultar pulados" else "Hide skipped")
                        else (if (lang == Lang.PT) "Mostrar pulados (${skippedList.size})"
                              else "Show skipped (${skippedList.size})"),
                        color = Theme.TextDim, fontSize = 11.sp, fontWeight = FontWeight.SemiBold
                    )
                }
                if (showSkipped) {
                    skippedList.forEach { e ->
                        EntrySkipRow(
                            e, true,
                            onToggle = { onToggleSkip(e.nodeId) },
                            onOpen = { engine.jumpTo(e.nodeId, e.label, groupName) },
                        )
                    }
                }
            }
        } else {
            // Colunas reativas à LARGURA do painel: mais largo = mais colunas e cards menores.
            val cols = gridColumns()
            val compact = cols >= 3
            entries.chunked(cols).forEach { rowEntries ->
                Row(Modifier.fillMaxWidth().padding(vertical = if (compact) 2.dp else 4.dp)) {
                    rowEntries.forEach { e ->
                        Box(Modifier.weight(1f).padding(horizontal = if (compact) 3.dp else 4.dp)) {
                            EntryCard(e, compact) { engine.jumpTo(e.nodeId, e.label, groupName) }
                        }
                    }
                    repeat(cols - rowEntries.size) {
                        Spacer(Modifier.weight(1f).padding(horizontal = if (compact) 3.dp else 4.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun EntrySkipRow(e: EntryPoint, skipped: Boolean, onToggle: () -> Unit, onOpen: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            if (skipped) "⊗" else "○",
            color = if (skipped) Theme.Accent else Theme.TextDim, fontSize = 16.sp,
            modifier = Modifier.clickable { onToggle() }.padding(end = 8.dp)
        )
        Row(
            Modifier.weight(1f).clip(RoundedCornerShape(11.dp)).background(Theme.Panel)
                .border(1.dp, Theme.Border, RoundedCornerShape(11.dp)).clickable { onOpen() }
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (e.portrait != null) AssetImage("trainers", e.portrait, Modifier.size(24.dp))
            else EntrySprite(e.label, Modifier.size(24.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                e.label, color = if (skipped) Theme.TextDim else Theme.Text, fontSize = 13.sp,
                fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f),
                textDecoration = if (skipped) TextDecoration.LineThrough else null
            )
        }
    }
}

@Composable
private fun EntryCard(e: EntryPoint, compact: Boolean = false, onClick: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(if (compact) 9.dp else 11.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(if (compact) 9.dp else 11.dp)).clickable { onClick() }
            .padding(vertical = if (compact) 6.dp else 12.dp), horizontalAlignment = Alignment.CenterHorizontally
    ) {
        EntrySprite(e.label, Modifier.size(if (compact) 28.dp else 40.dp))
        Spacer(Modifier.height(if (compact) 2.dp else 4.dp))
        Text(e.label, color = Theme.Text, fontWeight = FontWeight.Bold,
            fontSize = if (compact) 10.sp else 13.sp, textAlign = TextAlign.Center,
            maxLines = 1)
    }
}

@Composable
private fun SearchField(value: String, onChange: (String) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(9.dp)).padding(horizontal = 9.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("🔍", fontSize = 12.sp)
        Spacer(Modifier.width(6.dp))
        OverlayEditText(value, onChange, tr(L.SearchHint), Modifier.weight(1f))
    }
}

/**
 * Campo de texto NATIVO (EditText) para a SOBREPOSIÇÃO — o único jeito de o teclado (IME) abrir E
 * entregar o texto numa janela de overlay: o BasicTextField do Compose NÃO recebe o IME aqui, e o
 * IME_FLAG_NO_EXTRACT_UI evita o teclado em TELA CHEIA do landscape (que não serve sobreposições).
 * Compartilhado pela BUSCA e pela CAIXA DE FEEDBACK ("não funcionou") — as duas precisam do MESMO
 * malabarismo de foco/janela-focável descrito abaixo (antes o feedback usava BasicTextField e o
 * teclado nem abria no overlay). `singleLine = false` habilita várias linhas (feedback).
 *
 * FOCO/TECLADO: numa janela de overlay o EditText não recebe foco nem chama o IME sozinho. Ao tocar
 * (e ao ganhar foco) pedimos ao serviço tornar a janela FOCÁVEL (LocalSearchFocus) e repetimos
 * requestFocus() + showSoftInput() por ~700ms; ao perder o foco / o IME sumir, devolvemos a janela
 * pra não-focável (deixa jogar). A janela já é focável quando o painel está expandido.
 */
@Composable
private fun OverlayEditText(
    value: String,
    onChange: (String) -> Unit,
    hint: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    imeAction: Int = android.view.inputmethod.EditorInfo.IME_ACTION_SEARCH,
    textSizeSp: Float = 13f,
) {
    val textArgb = Theme.Text.toArgb()
    val hintArgb = Theme.TextDim.toArgb()
    val latestOnChange by rememberUpdatedState(onChange)
    // Liga/desliga o foco da janela do overlay SÓ enquanto o campo está ativo (ver LocalSearchFocus).
    val latestFocus by rememberUpdatedState(LocalSearchFocus.current)
    val suppress = remember { booleanArrayOf(false) } // ignora o eco do setText programático
    AndroidView(
        modifier = modifier,
        factory = { c ->
            android.widget.EditText(c).apply {
                background = null
                setPadding(0, 0, 0, 0)
                this.hint = hint
                setHintTextColor(hintArgb)
                setTextColor(textArgb)
                textSize = textSizeSp
                isSingleLine = singleLine
                if (!singleLine) {
                    // Feedback: várias linhas, texto começando no topo da caixa.
                    gravity = android.view.Gravity.TOP or android.view.Gravity.START
                    maxLines = 6
                }
                isFocusable = true
                isFocusableInTouchMode = true
                inputType = android.text.InputType.TYPE_CLASS_TEXT or
                    (if (singleLine) 0 else android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE)
                imeOptions = android.view.inputmethod.EditorInfo.IME_FLAG_NO_EXTRACT_UI or imeAction
                addTextChangedListener(object : android.text.TextWatcher {
                    override fun afterTextChanged(s: android.text.Editable?) {
                        if (!suppress[0]) latestOnChange(s?.toString().orEmpty())
                    }
                    override fun beforeTextChanged(s: CharSequence?, st: Int, c: Int, a: Int) {}
                    override fun onTextChanged(s: CharSequence?, st: Int, b: Int, c: Int) {}
                })
                fun showKeyboard() {
                    // 1) Pede pro serviço tornar a janela FOCÁVEL (só agora, enquanto digita).
                    latestFocus?.invoke(true)
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE)
                        as? android.view.inputmethod.InputMethodManager
                    // 2) A janela vira focável num updateViewLayout ASSÍNCRONO e o IME só
                    //    "serve" o EditText alguns frames depois de a janela ganhar foco.
                    //    Por isso repetimos requestFocus()+showSoftInput() por ~700ms (em vez
                    //    de parar no 1º foco) — assim sobe num toque só, sem tocar 2x.
                    fun attempt(tries: Int) {
                        requestFocus()
                        imm?.showSoftInput(this, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
                        if (tries > 0) postDelayed({ attempt(tries - 1) }, 100)
                    }
                    postDelayed({ attempt(6) }, 50)
                }
                setOnClickListener { showKeyboard() }
                // GATILHO CONFIÁVEL: a janela começa NÃO-focável (pra deixar jogar), então
                // tocar o EditText não consegue dar foco (janela não-focável bloqueia foco) e
                // o onFocusChange nunca dispara — deadlock. O toque, porém, CHEGA em janela
                // não-focável: no toque pedimos pro serviço tornar a janela focável e aí o
                // teclado conecta. `false` = não consome (o EditText ainda posiciona o cursor).
                setOnTouchListener { _, ev ->
                    if (ev.action == android.view.MotionEvent.ACTION_UP) showKeyboard()
                    false
                }
                setOnFocusChangeListener { v, hasFocus ->
                    latestFocus?.invoke(hasFocus)   // perdeu o foco → janela volta a NÃO-focável (joga normal)
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE)
                        as? android.view.inputmethod.InputMethodManager
                    if (hasFocus) {
                        v.post {
                            imm?.showSoftInput(v, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
                        }
                    } else {
                        imm?.hideSoftInputFromWindow(v.windowToken, 0)
                    }
                }
                // Quando o teclado é FECHADO (ex.: botão Voltar) mas o campo continua com foco,
                // a janela ficaria "presa" focável/modal (jogo travado). Ao detectar o IME some,
                // largamos o foco → dispara onFocusChange(false) → janela volta a deixar jogar.
                if (android.os.Build.VERSION.SDK_INT >= 30) {
                    setOnApplyWindowInsetsListener { v, insets ->
                        if (!insets.isVisible(android.view.WindowInsets.Type.ime()) && v.isFocused) {
                            v.clearFocus()
                        }
                        insets
                    }
                }
            }
        },
        update = { et ->
            if (et.text.toString() != value) {
                suppress[0] = true
                et.setText(value)
                et.setSelection(value.length)
                suppress[0] = false
            }
        },
        onRelease = { et ->
            // Ao remover o campo (ex.: minimizar/navegar), desliga o foco da janela e
            // esconde o teclado pra não deixar o IME órfão sobre o jogo.
            latestFocus?.invoke(false)
            val imm = et.context.getSystemService(Context.INPUT_METHOD_SERVICE)
                as? android.view.inputmethod.InputMethodManager
            imm?.hideSoftInputFromWindow(et.windowToken, 0)
        }
    )
}

// ---------------- Tela de um nó ----------------

@Composable
private fun NodeView(engine: SolveEngine, mode: ModeDef, teamId: String, onExit: () -> Unit, onShowTeams: (PossibleTeams) -> Unit) {
    val node = engine.currentNode ?: return
    val ctx = LocalContext.current
    val colorizer = remember(mode.id) { Colorizer(mode.solve.palette) }
    val revealAll = mode.solve.revealAll == true
    // Lê currentNodeId/pathTrail (estado) -> recompõe e recalcula os times possíveis a cada navegação.
    val possible = possibleOpponentTeams(ctx, engine)
    val wide = isWide()
    val gap = if (wide) 3.dp else 6.dp

    Column(Modifier.fillMaxSize().padding(if (wide) 7.dp else 10.dp).verticalScroll(rememberScrollState())) {
        engine.topPortrait?.let { OpponentHeader(it, engine.topName) }
        activeOpponentMon(ctx, engine)?.let { mon ->
            Row(Modifier.fillMaxWidth().padding(bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("▶ ", color = Theme.Accent, fontSize = 10.sp)
                AssetImage("sprites", mon, Modifier.size(20.dp))
                Spacer(Modifier.width(5.dp))
                Text(mon, color = Theme.Text, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
                Text(" " + tr(L.OpponentOnField), color = Theme.TextDim, fontSize = 9.sp)
            }
        }
        node.title?.let {
            Text(it, color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                modifier = Modifier.padding(bottom = 6.dp))
        }
        node.gymLead?.takeIf { it.isNotEmpty() }?.let { GymLeadHeader(tr(L.GymLeadWith), it, Theme.Accent) }
        // "Ver times": no topo da luta da Elite 4, abre o overlay com os times possíveis do oponente.
        possible?.let { pt -> VerTimesButton(pt) { onShowTeams(pt) } }
        node.steps.forEachIndexed { i, step ->
            if (revealAll || i <= engine.stepIndex) {
                // Ginásio da sequência: esconde o `setup` de entrada (surfaceado no fim do anterior).
                if (!(engine.hidesEntrySetup && step.kind == "setup")) {
                    StepRow(step, isCurrent = !revealAll && i == engine.stepIndex, colorizer)
                    Spacer(Modifier.height(gap))
                }
            }
        }
        if (!revealAll && engine.hasNextStep) {
            Box(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.AccentSoft)
                    .clickable { engine.next() }.padding(10.dp), contentAlignment = Alignment.Center
            ) { Text(tr(L.Next) + " ▶", color = Theme.Accent, fontWeight = FontWeight.Bold) }
            Spacer(Modifier.height(6.dp))
        }
        val showBranch = revealAll || engine.stepIndex >= node.steps.lastIndex || node.steps.isEmpty()
        if (showBranch) {
            val b = node.branch
            // #68: feedback "funcionou/não" no FIM de cada ginásio do Gym Rerun (farm = allowSkip),
            // quando a solve acabou (branch "Continuar"/goto ou nó terminal). Na E4 o feedback já
            // vem pelo EliteEndControls, então o gate `allowSkip` evita duplicar.
            if (mode.solve.allowSkip == true && (b == null || (b.kind == "goto" && b.nodeId != null))) {
                FeedbackControls(engine, mode, teamId)
                Spacer(Modifier.height(8.dp))
            }
            when {
                b == null && mode.solve.sequentialGroups == true ->
                    EliteEndControls(engine, mode, teamId, onExit)
                b == null -> TerminalBadge()
                b.kind == "choice" -> {
                    Text(b.prompt ?: tr(L.ChoosePrompt), color = Theme.TextDim, fontSize = 12.sp,
                        modifier = Modifier.padding(vertical = 4.dp))
                    b.options?.forEach { opt ->
                        // Pokémon citado na opção; senão o ativo do oponente; senão Master Ball.
                        // Catch-all "Demais times/Other teams" (nó *_def): sempre Master Ball, nunca
                        // herda o oponente ativo do trail (#65). Espelha o iconName do Mac.
                        val mon = optionSpriteName(ctx, opt.label)
                            ?: if (opt.nodeId.endsWith("_def")) null else activeOpponentMon(ctx, engine)
                        ChoiceButton(opt.label, colorizer, mon = mon, withIcon = true) { engine.choose(opt) }
                        Spacer(Modifier.height(6.dp))
                    }
                }
                b.kind == "goto" && b.nodeId != null ->
                    ChoiceButton(tr(L.ContinueLabel) + " →", colorizer) { engine.follow(b.nodeId) }
            }
        }

        // "PÓS-LUTA" de entrada do próximo ginásio ativo, mostrado no fim do atual.
        engine.upcomingSetupSteps.forEach { step ->
            StepRow(step, isCurrent = false, colorizer)
            Spacer(Modifier.height(gap))
        }

        // Dicas de próximo lead/ginásio + pular parada (rota de farm).
        val up = engine.upcomingGymLead
        if (up != null && up.isNotEmpty()) {
            val t = engine.upcomingGymTitle
            GymLeadHeader(tr(L.NextGym) + (if (t != null) " · ${shortStop(t)}" else ""), up, Theme.Good)
        } else {
            nextLeadHint(engine)?.let { NextLeadRow(it, colorizer) }
        }
        if (engine.canSkip) {
            Box(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.Panel)
                    .border(1.dp, Theme.Border, RoundedCornerShape(9.dp)).clickable { engine.skip() }
                    .padding(8.dp), contentAlignment = Alignment.Center
            ) { Text("⤼ " + tr(L.SkipThisStop), color = Theme.TextDim, fontSize = 12.sp) }
        }
    }
}

@Composable
private fun StepRow(step: Step, isCurrent: Boolean, colorizer: Colorizer) {
    when (step.kind) {
        "note" -> Row(verticalAlignment = Alignment.Top, modifier = Modifier.padding(horizontal = 2.dp)) {
            Text("ⓘ ", color = Theme.TextDim, fontSize = 11.sp)
            Text(colorizer.build(step.text ?: "", Theme.TextDim), fontSize = 11.sp)
        }
        "setup" -> Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.GoodSoft).padding(8.dp)
        ) {
            Text(tr(L.StepSetupBadge), color = Theme.Good, fontSize = 8.sp, fontWeight = FontWeight.Black)
            Text(colorizer.build(step.text ?: "", Theme.Text), fontSize = 12.sp)
        }
        "conditional" -> step.table?.let { table ->
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.Panel)
                    .border(1.dp, Theme.Border, RoundedCornerShape(9.dp)).padding(horizontal = 10.dp, vertical = 8.dp)
            ) {
                Text(table.title ?: tr(L.ConditionalTableTitleDefault),
                    color = Theme.TextDim, fontWeight = FontWeight.SemiBold, fontSize = 11.sp,
                    modifier = Modifier.padding(bottom = 4.dp))
                table.rows.forEach { row ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.Top) {
                        Text(colorizer.build(row.move, Theme.Accent), fontSize = 12.sp,
                            fontWeight = FontWeight.Bold)
                        Text(" → ", color = Theme.TextDim, fontSize = 11.sp)
                        Text(colorizer.build(row.targets.joinToString(", "), Theme.Text), fontSize = 11.sp,
                            modifier = Modifier.weight(1f))
                    }
                }
            }
        }
        else -> {
            val base = if (isCurrent) Theme.Text else Theme.TextDim
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp))
                    .background(if (isCurrent) Theme.AccentSoft else Theme.Panel)
                    .border(1.dp, if (isCurrent) Theme.Accent else Theme.Border, RoundedCornerShape(9.dp))
                    .padding(10.dp), verticalAlignment = Alignment.Top
            ) {
                Text(if (isCurrent) "▶ " else "→ ", color = if (isCurrent) Theme.Accent else Theme.Good,
                    fontSize = 13.sp)
                Text(colorizer.build(step.text ?: "", base), fontSize = 13.sp,
                    fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Normal)
            }
        }
    }
}

@Composable
private fun ChoiceButton(
    label: String, colorizer: Colorizer, mon: String? = null, withIcon: Boolean = false,
    onClick: () -> Unit
) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.ChoiceSoft)
            .border(1.dp, Theme.Choice.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
            .clickable { onClick() }.padding(11.dp), verticalAlignment = Alignment.CenterVertically
    ) {
        // Opção de batalha → sprite do Pokémon (ou Master Ball se não houver); navegação → seta.
        if (withIcon) {
            MonOrBall(mon, Modifier.size(22.dp))
            Spacer(Modifier.width(8.dp))
        } else {
            Text("→ ", color = Theme.Choice, fontWeight = FontWeight.Bold)
        }
        Text(colorizer.build(label, Theme.Text), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun TerminalBadge() {
    Box(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.GoodSoft).padding(12.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(tr(L.TerminalBadge), color = Theme.Good,
            fontWeight = FontWeight.SemiBold, fontSize = 12.sp, textAlign = TextAlign.Center)
    }
}

// ---------------- Lead do ginásio + dicas de próximo lead (rota de farm) ----------------

@Composable
private fun GymLeadHeader(title: String, leads: List<GymLead>, tint: Color) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp))
            .background(if (tint == Theme.Good) Theme.GoodSoft else Theme.AccentSoft)
            .border(1.dp, tint, RoundedCornerShape(9.dp)).padding(horizontal = 9.dp, vertical = 6.dp)
    ) {
        Text(title.uppercase(), color = tint, fontSize = 8.sp, fontWeight = FontWeight.Black,
            modifier = Modifier.padding(bottom = 3.dp))
        Row {
            leads.forEach { lead ->
                Row(Modifier.padding(end = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    AssetImage("sprites", lead.pokemon, Modifier.size(22.dp))
                    Spacer(Modifier.width(4.dp))
                    Column {
                        Text(lead.pokemon, color = Theme.Text, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        lead.item?.let { Text(it, color = Theme.TextDim, fontSize = 9.sp) }
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(6.dp))
}

@Composable
private fun NextLeadRow(hint: String, colorizer: Colorizer) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.GoodSoft)
            .padding(horizontal = 9.dp, vertical = 6.dp)
    ) {
        Text(tr(L.NextLeadLabel), color = Theme.Good, fontWeight = FontWeight.Bold, fontSize = 11.sp)
        Text(colorizer.build(hint, Theme.Text), fontSize = 11.sp)
    }
    Spacer(Modifier.height(6.dp))
}

/**
 * Pokémon ATIVO do oponente: começa no lead e só muda quando ele troca (rótulo = nome de Pokémon
 * com sprite). Em golpe/"ficou"/manter, continua o mesmo. null se a trilha não tem Pokémon (farm).
 */
private val ourSwitchVerbs = setOf("troque", "troca", "trocar", "volte", "volta", "mande", "manda", "use", "lidere", "lidera", "puxe", "puxa")

private fun activeOpponentMon(ctx: Context, engine: SolveEngine): String? {
    var mon: String? = null
    for (label in engine.pathTrail) if (loadAsset(ctx, "sprites", label) != null) mon = label
    // Ciente do contexto: passos revelados que citam o mon do oponente (ex.: "Habilidade do Claydol",
    // "→ sai Gengar") passam a valer — ignorando as NOSSAS trocas ("troque para Dragonite").
    val node = engine.currentNode
    if (node != null) {
        val upper = minOf(engine.stepIndex, node.steps.lastIndex)
        for (i in 0..upper) {
            val text = node.steps[i].text ?: continue
            val first = text.trimStart().takeWhile { it.isLetter() }.lowercase()
            if (first in ourSwitchVerbs) continue
            optionSpriteName(ctx, text)?.let { mon = it }
        }
    }
    return mon
}

/** Lead do próximo nó (alvo do goto "Continuar") — espelha o NextLeadHint do Mac/Windows. */
private fun nextLeadHint(engine: SolveEngine): String? {
    val b = engine.currentNode?.branch
    if (b?.kind == "goto" && b.nodeId != null) return engine.solve.nodes[b.nodeId]?.leadHint
    return null
}

private fun shortStop(title: String): String {
    val idx = title.indexOf("· ")
    return if (idx >= 0) title.substring(idx + 2) else title
}

// ---------------- Cabeçalho do oponente (foto de quem você enfrenta agora) ----------------

@Composable
private fun OpponentHeader(portrait: String, name: String?) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.AccentSoft)
            .padding(horizontal = 9.dp, vertical = 5.dp).padding(bottom = 0.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AssetImage("trainers", portrait, Modifier.size(30.dp))
        Spacer(Modifier.width(8.dp))
        Column {
            Text(tr(L.OpponentHeaderFacing), color = Theme.Accent, fontSize = 8.sp, fontWeight = FontWeight.Black)
            name?.let {
                Text(it, color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
    Spacer(Modifier.height(8.dp))
}

// ---------------- Fim da luta na Elite 4: feedback + próximo treinador / reiniciar ----------------

@Composable
private fun EliteEndControls(engine: SolveEngine, mode: ModeDef, teamId: String, onExit: () -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        // Feedback "funcionou/não" — reusado no Gym Rerun (#68) via FeedbackControls.
        FeedbackControls(engine, mode, teamId)

        Spacer(Modifier.height(8.dp))

        val nxt = engine.nextGroup
        when {
            nxt != null -> Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.Accent)
                    .clickable { engine.advanceToNextGroup() }.padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                nxt.portrait?.let { AssetImage("trainers", it, Modifier.size(22.dp)); Spacer(Modifier.width(7.dp)) }
                Column(Modifier.weight(1f)) {
                    Text(tr(L.NextTrainerBadge), color = Color.Black.copy(alpha = 0.6f), fontSize = 8.sp,
                        fontWeight = FontWeight.Black)
                    Text(nxt.name, color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
                Text("›", color = Color.Black, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
            engine.isChampionTerminal -> Box(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.Good)
                    .clickable { engine.reset() }.padding(vertical = 10.dp), contentAlignment = Alignment.Center
            ) {
                Text(tr(L.LeagueCompleted), color = Color.Black,
                    fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
        }
    }
}

/** Feedback "funcionou / não funcionou" (#68): reusado no fim da luta da Elite 4 (EliteEndControls)
 *  e no fim de cada ginásio do Gym Rerun (NodeView). Estado com key no nó → reseta por ginásio. */
@Composable
private fun FeedbackControls(engine: SolveEngine, mode: ModeDef, teamId: String) {
    var sent by remember(engine.currentNodeId) { mutableStateOf<String?>(null) }
    var showFailBox by remember(engine.currentNodeId) { mutableStateOf(false) }
    var failText by remember(engine.currentNodeId) { mutableStateOf("") }

    fun submit(result: String, description: String?) {
        FeedbackClient.send(
            result = result, mode = mode.title, team = teamId, trainer = engine.topName,
            lead = engine.pathTrail.firstOrNull(), path = engine.pathTrail.joinToString(" → "),
            node = engine.currentNodeId, description = description
        )
        sent = if (result == "funcionou") "ok" else "fail"
    }

    Column(Modifier.fillMaxWidth()) {
        when {
            sent != null -> Text(
                if (sent == "ok") tr(L.FeedbackThanksOk) else tr(L.FeedbackThanksFail),
                color = Theme.TextDim, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)
            )
            showFailBox -> Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(Theme.Panel).padding(8.dp)
            ) {
                Text(tr(L.FeedbackFailPrompt), color = Theme.TextDim, fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(4.dp))
                Box(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(Theme.Bg).padding(8.dp)
                ) {
                    // Mesmo campo NATIVO da busca (OverlayEditText): garante que o teclado ABRA e
                    // entregue o texto na sobreposição — o BasicTextField não recebia o IME aqui.
                    // O hint ("descreva o que aconteceu") já vem do próprio EditText nativo.
                    OverlayEditText(
                        value = failText,
                        onChange = { failText = it },
                        hint = tr(L.FeedbackDescribe),
                        singleLine = false,
                        imeAction = android.view.inputmethod.EditorInfo.IME_ACTION_NONE,
                        textSizeSp = 12f,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                    )
                }
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr(L.Cancel), color = Theme.TextDim, fontSize = 11.sp,
                        modifier = Modifier.clickable { showFailBox = false; failText = "" })
                    Spacer(Modifier.weight(1f))
                    Box(
                        Modifier.clip(RoundedCornerShape(50)).background(Theme.Warning)
                            .clickable { submit("nao_funcionou", failText) }
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                    ) { Text(tr(L.Send), color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }
                }
            }
            else -> Row(Modifier.fillMaxWidth()) {
                FeedbackBtn(tr(L.FeedbackWorked), Theme.Good, Theme.GoodSoft, Modifier.weight(1f)) {
                    submit("funcionou", null)
                }
                Spacer(Modifier.width(6.dp))
                FeedbackBtn(tr(L.FeedbackDidntWork), Theme.Danger, Theme.DangerSoft, Modifier.weight(1f)) {
                    showFailBox = true
                }
            }
        }
    }
}

@Composable
private fun FeedbackBtn(label: String, fg: Color, bg: Color, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(9.dp)).background(bg)
            .border(1.dp, fg.copy(alpha = 0.4f), RoundedCornerShape(9.dp))
            .clickable { onClick() }.padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) { Text(label, color = fg, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }
}

// ---------------- "Ver times" do oponente (porte do TeamsOverlayView.swift) ----------------

/** Times possíveis do adversário no ponto atual do roteiro. */
data class PossibleTeams(
    val teams: List<OpponentTeam>,
    val confirmed: Boolean,
    val trainer: String,
    val lead: String,
)

/**
 * Calcula os times possíveis: base = todos os times do treinador que CONTÊM o lead;
 * estreitada pelo lineList do roteiro (com segurança: filtro que zeraria é ignorado).
 * Retorna null fora da Elite 4 ou quando não há dado pra mostrar. Porte fiel do AppModel.swift.
 */
private fun possibleOpponentTeams(ctx: Context, engine: SolveEngine): PossibleTeams? {
    val region = OpponentCatalog.regionName(engine.solve.id) ?: return null
    val group = engine.currentGroupName?.takeIf { it.isNotEmpty() } ?: return null
    val lead = engine.pathTrail.firstOrNull()?.takeIf { it.isNotEmpty() } ?: return null

    val key = OpponentCatalog.trainerKey(region, group)
    val all = OpponentCatalog.teams(ctx, region, key)
    if (all.isEmpty()) return null

    // Base: times que contêm o lead. Se nenhum casar, cai pra todos.
    val base = all.filter { it.contains(lead) }
    var nums = (if (base.isEmpty()) all else base).map { it.team }.toSet()

    // Estreita pelo lineList; só aplica a interseção se ela NÃO zerar.
    for (set in engine.lineNumberSetsAlongPath()) {
        val inter = nums intersect set
        if (inter.isNotEmpty()) nums = inter
    }

    val teams = all.filter { nums.contains(it.team) }.sortedBy { it.team }
    if (teams.isEmpty()) return null
    return PossibleTeams(teams, teams.size == 1, group, lead)
}

@Composable
private fun VerTimesButton(data: PossibleTeams, onClick: () -> Unit) {
    val tint = if (data.confirmed) Theme.Good else Theme.Accent
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))
            .background(if (data.confirmed) Theme.GoodSoft else Theme.AccentSoft)
            .border(1.dp, tint, RoundedCornerShape(10.dp))
            .clickable { onClick() }.padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(tint))
        Spacer(Modifier.width(8.dp))
        Text(
            if (data.confirmed) tr(L.SeeTeamsConfirmed) else "${tr(L.SeeTeamsPossible)} · ${data.teams.size}",
            color = Theme.Text, fontWeight = FontWeight.SemiBold, fontSize = 12.sp,
            modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis
        )
        Text("›", color = Theme.TextDim, fontSize = 16.sp, fontWeight = FontWeight.Bold)
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun TeamsOverlay(data: PossibleTeams, onClose: () -> Unit) {
    Column(Modifier.fillMaxSize().background(Theme.Bg)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    if (data.confirmed) tr(L.TeamsConfirmedTitle)
                    else "${tr(L.TeamsPossibleTitle)} · ${data.teams.size}",
                    color = if (data.confirmed) Theme.Good else Theme.Accent,
                    fontSize = 9.sp, fontWeight = FontWeight.Black
                )
                Text(
                    "${data.trainer} · lead ${data.lead}", color = Theme.Text,
                    fontWeight = FontWeight.Bold, fontSize = 12.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis
                )
            }
            Text("✕", color = Theme.TextDim, fontSize = 15.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable { onClose() }.padding(6.dp))
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Theme.Border))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(10.dp)) {
            if (!data.confirmed) {
                Text(
                    tr(L.TeamsDistinguishHint),
                    color = Theme.TextDim, fontSize = 10.sp, modifier = Modifier.padding(bottom = 8.dp)
                )
            }
            data.teams.forEach { team ->
                TeamCard(team)
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun TeamCard(team: OpponentTeam) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(10.dp)).padding(9.dp)
    ) {
        Text("${tr(L.TeamsTeamCardTitle)} ${team.team}", color = Theme.Choice, fontWeight = FontWeight.Black, fontSize = 11.sp,
            modifier = Modifier.padding(bottom = 4.dp))
        team.pokemon.forEach { MonRow(it) }
    }
}

@Composable
private fun MonRow(mon: OpponentMon) {
    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.Top) {
        AssetImage("sprites", mon.pokemon, Modifier.size(26.dp))
        Spacer(Modifier.width(7.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(mon.pokemon, color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                if (mon.item.isNotEmpty()) {
                    Spacer(Modifier.width(5.dp))
                    Text(mon.item, color = Theme.Accent, fontWeight = FontWeight.SemiBold, fontSize = 9.sp)
                }
            }
            if (mon.ability.isNotEmpty())
                Text(mon.ability, color = Theme.Good, fontSize = 9.sp)
            Text(mon.moves.joinToString(" · "), color = Theme.TextDim, fontSize = 9.sp)
        }
    }
}
