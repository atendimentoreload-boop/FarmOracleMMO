package com.reload.prestreloajuda.data

import android.content.Context
import com.reload.prestreloajuda.ui.Lang
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

// Modelo do sistema de Cooldown/Alarme (#33) — porte fiel do CooldownModel.swift do Mac.
// - CATÁLOGO: templates lidos de `assets/data/cooldowns.json` (batalhas, tiers de berry, 64 berries).
// - ESTADO: o que o usuário criou/marcou (personagens + marcações), salvo em SharedPreferences.
//
// Regra de robustez (igual ao Mac): a VERDADE é sempre um timestamp absoluto (epoch em
// MILISSEGUNDOS). Contador e alarme são DERIVADOS; reconciliar no startup a partir dos timestamps.

/** Milissegundos desde 1970 — mesma base do Mac/protótipo web. */
fun nowMs(): Long = System.currentTimeMillis()

// MARK: - Catálogo (assets/data/cooldowns.json)

/** Nome bilíngue (PT/EN) vindo do catálogo. */
@Serializable
data class LocalizedName(val pt: String = "", val en: String = "") {
    fun localized(lang: Lang): String = if (lang == Lang.EN) en else pt
}

/** Tarefa de batalha com cooldown simples (um timer). Campos extras (type/note/source) são ignorados. */
@Serializable
data class BattleTask(
    val id: String,
    val category: String = "",
    val name: LocalizedName = LocalizedName(),
    val hours: Double = 0.0,
    val color: String = "#888888",
    val confidence: String = "",
    val defaultOn: Boolean = false,
    /** "region:x" | "trainer:x" | "item:x" | "sprite:x" | "sf:símbolo". null = ponto colorido. */
    val icon: String? = null,
    /** Agrupador na UI (ex.: "elite4" junta as 5 ligas num submenu). null = tarefa avulsa. */
    val group: String? = null,
)

/** Tier de berry: guarda a matemática do ciclo (uma vez), compartilhada por várias berries. */
@Serializable
data class BerryTier(
    val tier: String,
    val growthHours: Double = 0.0,        // plantar -> pronta pra colher (fixo)
    val wiltHours: Double = 0.0,          // janela de colheita depois de pronta
    val waterWindowsHours: List<Double> = emptyList(), // limite (h após plantar) de cada rega
    val waterLeadHours: Double = 0.0,     // disparar o lembrete tantas h ANTES do limite
    val yield: String = "",
)

/** Uma berry específica (nome/ícone) que aponta pro seu tier. */
@Serializable
data class BerryDef(
    val id: String,
    val tier: String = "",
    val name: LocalizedName = LocalizedName(),
    val popular: Boolean = false,
    val defaultOn: Boolean = false,
)

/** O catálogo-semente inteiro. */
@Serializable
data class CooldownCatalog(
    val battleTasks: List<BattleTask> = emptyList(),
    val optionalTasks: List<BattleTask> = emptyList(),
    val berryTiers: List<BerryTier> = emptyList(),
    val berries: List<BerryDef> = emptyList(),
) {
    /** Todas as tarefas de batalha (obrigatórias + opcionais). */
    val allBattle: List<BattleTask> get() = battleTasks + optionalTasks

    fun battleTask(id: String): BattleTask? = allBattle.firstOrNull { it.id == id }
    fun berry(id: String): BerryDef? = berries.firstOrNull { it.id == id }
    fun tier(id: String): BerryTier? = berryTiers.firstOrNull { it.tier == id }

    companion object {
        val EMPTY = CooldownCatalog()

        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        fun load(ctx: Context): CooldownCatalog = try {
            val text = ctx.assets.open("data/cooldowns.json")
                .bufferedReader(Charsets.UTF_8).use { it.readText() }
            json.decodeFromString(serializer(), text)
        } catch (e: Exception) {
            EMPTY
        }
    }
}

// MARK: - Estado do usuário (persistido)

/** Um "boneco" (conta/ALT) cadastrado pelo usuário. avatar = PNG 128×128 em base64 (null = monograma). */
@Serializable
data class GameCharacter(val id: String, val name: String, val avatar: String? = null)

/** Progresso de uma berry plantada num canteiro. `plantedAt` é a verdade — tudo deriva dele + do tier. */
@Serializable
data class BerryProgress(val plantedAt: Long = 0L, val waterings: Int = 0)

/**
 * Estado completo do usuário, salvo como um único blob JSON (preparado pra sync futuro).
 * Decoder TOLERANTE: todos os campos têm default + `ignoreUnknownKeys`, então campos ausentes
 * (versões antigas / campos novos) não quebram.
 */
@Serializable
data class CooldownState(
    val version: Int = 2,
    val characters: List<GameCharacter> = emptyList(),
    /** "charId:battleTaskId" -> ms da marcação. */
    val battle: Map<String, Long> = emptyMap(),
    /** "charId:berryId:plot" -> progresso. */
    val berry: Map<String, BerryProgress> = emptyMap(),
    /** Ids de tarefas de batalha que o usuário DESATIVOU (as defaultOn começam ligadas). */
    val hiddenBattle: List<String> = emptyList(),
    /** Ids de berries que o usuário ATIVOU além das defaultOn. */
    val enabledBerry: List<String> = emptyList(),
    val updatedAt: Long = 0L,
)

// MARK: - Formatação (igual ao protótipo/Mac)

/** Formata ms restantes em "Xd Yh" / "Xh YYm" / "Xm YYs" / "Xs". 0 -> "0s". Arredonda p/ cima. */
fun fmtRemain(ms: Long): String {
    if (ms <= 0) return "0s"
    var s = (ms + 999) / 1000            // segundos, arredondado p/ cima
    val d = s / 86400; s -= d * 86400
    val h = s / 3600; s -= h * 3600
    val m = s / 60; s -= m * 60
    return when {
        d > 0 -> "${d}d ${h}h"
        h > 0 -> "${h}h ${"%02d".format(m)}m"
        m > 0 -> "${m}m ${"%02d".format(s)}s"
        else -> "${s}s"
    }
}

/** "6h", "18h", "7d" — rótulo curto de uma duração em horas. */
fun fmtHoursLabel(hours: Double): String =
    if (hours >= 24 && hours % 24.0 == 0.0) "${(hours / 24).toInt()}d" else "${hours.toInt()}h"
