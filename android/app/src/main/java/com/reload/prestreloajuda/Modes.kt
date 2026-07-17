package com.reload.prestreloajuda

import android.content.Context
import com.reload.prestreloajuda.data.SolveLoader
import com.reload.prestreloajuda.data.TeamsConfig
import com.reload.prestreloajuda.model.Solve

data class ModeDef(
    val id: String,
    val title: String,
    val subtitle: String,
    val solve: Solve,
    val portrait: String? = null,
    val item: String? = null,
    val category: String? = null,
    /** Modo ainda sem conteúdo pronto: mostra o selo "em breve" no card (ex.: Ho-Oh). */
    val comingSoon: Boolean = false,
) {
    val pokepaste: String? get() = solve.pokepaste
    val doc: String? get() = solve.doc
}

/** Textos de título/subtítulo dos modos por idioma (o conteúdo das lutas vem do JSON). */
private data class ModeText(
    val redTitle: String, val redSub: String,
    val veteranTitle: String, val veteranSub: String,
    val categoryRegions: String,
    val kanto: String, val hoenn: String, val unova: String, val sinnoh: String, val johto: String,
    val cmTitle: String, val cmSub: String,
    val hoohTitle: String, val hoohSub: String,
)

private fun modeText(lang: String): ModeText = if (lang == "en") ModeText(
    redTitle = "Red Battle", redSub = "Turn-by-turn guide to beat Red.",
    veteranTitle = "Gym Farm",
    veteranSub = "Defeat the gym leaders again in double battles.",
    categoryRegions = "regions — pick one",
    kanto = "Lorelei, Bruno, Agatha, Lance and Gary.",
    hoenn = "Sidney, Phoebe, Glacia, Drake and Wallace.",
    unova = "Shauntal, Grimsley, Caitlin, Marshal and Alder.",
    sinnoh = "Aaron, Bertha, Flint, Lucian and Cynthia.",
    johto = "Will, Koga, Bruno, Karen and Lance.",
    cmTitle = "Cynthia & Morimoto", cmSub = "Beat Cynthia and Morimoto in Unova.",
    hoohTitle = "Ho-Oh", hoohSub = "Beat Ho-Oh in the rematch.",
) else ModeText(
    redTitle = "Luta do Red", redSub = "Roteiro turno a turno para vencer o Red.",
    veteranTitle = "Farm de Ginásios",
    veteranSub = "Derrote os líderes dos ginásios novamente em batalhas em dupla.",
    categoryRegions = "regiões — escolha uma",
    kanto = "Lorelei, Bruno, Agatha, Lance e Gary.",
    hoenn = "Sidney, Phoebe, Glacia, Drake e Wallace.",
    unova = "Shauntal, Grimsley, Caitlin, Marshal e Alder.",
    sinnoh = "Aaron, Bertha, Flint, Lucian e Cynthia.",
    johto = "Will, Koga, Bruno, Karen e Lance.",
    cmTitle = "Cynthia & Morimoto", cmSub = "Derrote a Cynthia e o Morimoto em Unova.",
    hoohTitle = "Ho-Oh", hoohSub = "Derrote o Ho-Oh no rematch.",
)

/** Rota de Farm de Ginásios (time + solve próprios), trocável nas Configurações — igual ao Mac.
 *  Rotas do MESMO `teamGroup` (mesmo time) são agrupadas num submenu; muda só a rota/variante. */
data class FarmRoute(
    val id: String, val name: String, val roster: String, val pokepaste: String,
    /** Time a que a rota pertence (agrupa no seletor). Ex.: "six_pillars", "seven_hells". */
    val teamGroup: String,
    /** Nome curto da variante (mostrado dentro do submenu). Ex.: "Veteran", "BASIC". */
    val variant: String,
    /** Documento oficial (Google Docs) que originou a estratégia. */
    val doc: String? = null,
)

val farmRoutes: List<FarmRoute> = listOf(
    FarmRoute("veteran", "Six Pillars (Veteran Route)",
        "Typhlosion, Togekiss, Blastoise, Vanilluxe, Weezing, Garchomp",
        "https://pokepast.es/f00df8948e58939c",
        teamGroup = "six_pillars", variant = "Veteran",
        doc = "https://docs.google.com/document/d/1XnFfsSVh1x5sEBLzvkletNfBuKY5ymSL_UHKNjoDaeE/edit"),
    FarmRoute("6pillars_basic", "Six Pillars (BASIC Route)",
        "Typhlosion, Togekiss, Blastoise, Vanilluxe, Weezing, Garchomp",
        "https://pokepast.es/f00df8948e58939c",
        teamGroup = "six_pillars", variant = "BASIC",
        doc = "https://docs.google.com/document/d/1cWYvyJ7JxlkQqnrIeLZj0l_Yra0JKMuT2dIPwGwNjGA/edit"),
    FarmRoute("lucky_girl", "Seven Hells (Lucky Girl)",
        "Typhlosion, Blastoise, Vanilluxe, Aerodactyl, Excadrill, Meloetta",
        "https://pokepast.es/852ceef5515a4f85",
        teamGroup = "seven_hells", variant = "Lucky Girl"),
)

/** Nome de exibição de um teamGroup (cabeçalho do submenu). Espelha AppModel.farmTeamName do Mac. */
fun farmTeamName(group: String): String = when (group) {
    "six_pillars" -> "Six Pillars"
    "seven_hells" -> "Seven Hells (Lucky Girl)"
    else -> group
}

/** teamGroups na ordem de 1ª aparição (pro seletor agrupar preservando a ordem). */
val farmTeamGroupsOrdered: List<String> get() = farmRoutes.map { it.teamGroup }.distinct()

/** Rotas de um teamGroup, na ordem em que aparecem em `farmRoutes`. */
fun farmRoutesIn(group: String): List<FarmRoute> = farmRoutes.filter { it.teamGroup == group }

/** Estratégia/time do modo Cynthia & Morimoto (solve + time próprios), trocável nas Configurações. */
data class CynthiaMorimotoStrategy(val id: String, val name: String, val roster: String,
                                   val pokepaste: String, val doc: String? = null)

/** Estratégias cadastradas. Novas entram aqui + um JSON `<id>.json` (PT + en/). */
val cynthiaMorimotoStrategies: List<CynthiaMorimotoStrategy> = listOf(
    CynthiaMorimotoStrategy("cynthia_morimoto", "Metagross / Swellow (padrão)",
        "Metagross, Swellow, Umbreon, Garchomp ×2, Slowking",
        "https://pokepast.es/73afd6d7af99592f"),
    CynthiaMorimotoStrategy("cynthia_morimoto_cadozz", "cadozz — Torterra/Scyther",
        "Chansey, Smeargle, Infernape, Torterra, Scyther",
        "https://pokepast.es/acbe0d2c63e3c68c",
        "https://forums.pokemmo.com/index.php?/topic/198035-beating-cynthia-fast-a-strategy-guide/"),
)

/** Estratégia/time do modo Red (solve + time próprios), trocável nas Configurações — igual ao Cynthia & Morimoto. */
data class RedStrategy(val id: String, val name: String, val roster: String, val pokepaste: String,
                       val pokemon: String, val doc: String? = null)

/** Estratégias cadastradas do Red. Novas entram aqui + um JSON `<id>.json` (PT + en/). */
val redStrategies: List<RedStrategy> = listOf(
    RedStrategy("red", "Pós Choice Nerf (JinxedBoon)",
        "Infernape, Weavile, Jolteon, Bisharp, Breloom, Gliscor",
        "https://pokepast.es/8a207ad044e70c5a", "infernape",
        "https://docs.google.com/document/d/1dXaJNGqA2xjUACgcCshcIktBlCjcZgTT839O-Q1pGoA/edit"),
    RedStrategy("red_colored", "Colored (ZzPSYCHOzZ)",
        "Blissey, Honchkrow, Gliscor, Lapras, Golduck, Breloom",
        "https://pokepast.es/433ccc371e07d52c", "blissey",
        "https://docs.google.com/document/d/1hcpaFvBere2nWb0C61PVqteTeouoNiMMsmln3YLmFk8/edit"),
)

/** Estratégia/time do modo Ho-Oh (rematch), trocável nas Configurações — igual ao Red. */
data class HoohStrategy(val id: String, val name: String, val roster: String, val pokepaste: String,
                        val pokemon: String, val video: String? = null)

/** Estratégias cadastradas do Ho-Oh. Novas entram aqui + um JSON `<id>.json` (PT + en/). */
val hoohStrategies: List<HoohStrategy> = listOf(
    HoohStrategy("hooh", "Allen - Yatsura",
        "Shuckle, Rotom, Ducklett",
        "https://pokepast.es/95c7ab2b67af6a1a", "rotom",
        "https://youtu.be/TR-8IkhyRJE"),
    HoohStrategy("hooh_trickroom", "Trick Room (Lewis Nield)",
        "Chandelure, Rotom-Heat, Lunatone",
        "https://pokepast.es/bf35cfea0d1b7356", "chandelure",
        "https://youtu.be/_fcYxnPJKA0"),
)

/** Monta a biblioteca de modos para o time/visual/idioma ativos. */
fun loadModes(
    context: Context,
    config: TeamsConfig,
    teamId: String,
    emoji: Boolean,
    lang: String = "pt",
    farmRouteId: String = "veteran",
    cmStrategyId: String = "cynthia_morimoto",
    redStrategyId: String = "red",
    hoohStrategyId: String = "hooh",
): List<ModeDef> {
    val team = config.resolve(teamId)
    val useEmoji = emoji && team.hasEmoji
    val t = modeText(lang)

    // Caminho de um modo: compartilhado (raiz) ou por time (teams/<id>[/emoji]/<nome>).
    fun path(name: String): String {
        if (!config.isTeamScoped(name) || team.id.isEmpty()) return name
        val base = "teams/" + team.id + (if (useEmoji) "/emoji" else "")
        return "$base/$name"
    }

    fun elite(name: String, title: String, sub: String) = ModeDef(
        name, title, sub,
        // botão "?" mostra o Poképaste do time
        SolveLoader.load(context, path(name), lang).copy(pokepaste = team.pokepaste),
        category = "Elite 4",
    )

    // A rota Veteran embute a luta de Cynthia & Morimoto no fim. Se o jogador escolheu a
    // estratégia cadozz de C&M, carrega a variante veteran_cadozz (injeta o TIME cadozz nessa
    // seção), pra bater com o time selecionado no menu de C&M. #veteran-cadozz
    val farmRouteResolved = farmRoutes.firstOrNull { it.id == farmRouteId }?.id ?: "veteran"
    val farmSolveName = if (farmRouteResolved == "veteran" && cmStrategyId == "cynthia_morimoto_cadozz")
        "veteran_cadozz" else farmRouteResolved

    // A ORDEM aqui é a ordem dos cards na home: Elite 4 (categoria) → Farm → Cynthia &
    // Morimoto → Red → Ho-Oh. O card de Configurações é renderizado à parte pelo picker.
    return listOf(
        elite("elite4_kanto", "Kanto", t.kanto),
        elite("elite4_hoenn", "Hoenn", t.hoenn),
        elite("elite4_unova", "Unova", t.unova),
        elite("elite4_sinnoh", "Sinnoh", t.sinnoh),
        elite("elite4_johto", "Johto", t.johto),
        ModeDef(
            // Farm de Ginásios: 1 modo só; a rota ativa (Six Pillars / Seven Hells) vem do
            // farmRouteId (escolhida nas Configurações). Ícone = ginásio (gym), igual ao Mac.
            "veteran", t.veteranTitle, t.veteranSub,
            SolveLoader.load(context, farmSolveName, lang),
            item = "gym"
        ),
        ModeDef(
            // Cynthia & Morimoto: 1 modo só; a estratégia ativa (o time) vem do cmStrategyId
            // (escolhida nas Configurações), como as rotas de farm.
            "cynthia_morimoto", t.cmTitle, t.cmSub,
            SolveLoader.load(context, cynthiaMorimotoStrategies.firstOrNull { it.id == cmStrategyId }?.id ?: "cynthia_morimoto", lang),
            portrait = "cynthia"
        ),
        ModeDef(
            // Red: 1 modo só; a estratégia ativa (o time) vem do redStrategyId (escolhida nas
            // Configurações), como as rotas de farm e o Cynthia & Morimoto.
            "red", t.redTitle, t.redSub,
            SolveLoader.load(context, redStrategies.firstOrNull { it.id == redStrategyId }?.id ?: "red", lang),
            portrait = "red"
        ),
        ModeDef(
            // Ho-Oh: 1 modo só; a estratégia ativa (o time) vem do hoohStrategyId (escolhida
            // nas Configurações), como o Red e o Cynthia & Morimoto.
            "hooh", t.hoohTitle, t.hoohSub,
            SolveLoader.load(context, hoohStrategies.firstOrNull { it.id == hoohStrategyId }?.id ?: "hooh", lang)
        ),
    )
}

/** Subtítulo da categoria "Elite 4" no menu (depende do idioma). */
fun categorySubtitle(lang: String, count: Int): String = "$count ${modeText(lang).categoryRegions}"
