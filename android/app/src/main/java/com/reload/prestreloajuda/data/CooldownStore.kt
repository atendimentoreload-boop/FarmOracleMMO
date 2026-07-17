package com.reload.prestreloajuda.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.reload.prestreloajuda.ui.L
import com.reload.prestreloajuda.ui.Lang
import com.reload.prestreloajuda.ui.Strings
import com.reload.prestreloajuda.ui.langPref
import kotlinx.serialization.json.Json

/**
 * Estado do sistema de Cooldown/Alarme (#33) — porte fiel do CooldownStore.swift do Mac.
 * Carrega o catálogo-semente, guarda os personagens e as marcações do usuário (persistido em
 * SharedPreferences, um único blob JSON), calcula tempo restante e AGENDA os alarmes.
 * A VERDADE é sempre o timestamp absoluto (ms) — o alarme e o contador são derivados.
 *
 * O estado é exposto num Compose `State` (`state`), então qualquer Composable que o leia recompõe
 * ao mutar — espelha o `@Published` do `ObservableObject` do Mac.
 */
class CooldownStore(private val appCtx: Context) {

    val catalog: CooldownCatalog = CooldownCatalog.load(appCtx)

    var state by mutableStateOf(loadState())
        private set

    private val prefs = appCtx.getSharedPreferences("cooldowns", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; isLenient = true; encodeDefaults = true }

    init {
        reconcile()
    }

    // MARK: - Persistência

    private fun loadState(): CooldownState {
        val blob = appCtx.getSharedPreferences("cooldowns", Context.MODE_PRIVATE)
            .getString(STATE_KEY, null) ?: return CooldownState()
        return try {
            Json { ignoreUnknownKeys = true; isLenient = true }
                .decodeFromString(CooldownState.serializer(), blob)
        } catch (e: Exception) {
            CooldownState()
        }
    }

    /** Aplica um novo estado: carimba `updatedAt` e persiste (equivalente ao `touch()` do Mac). */
    private fun save(next: CooldownState) {
        state = next.copy(updatedAt = nowMs())
        try {
            prefs.edit().putString(STATE_KEY, json.encodeToString(CooldownState.serializer(), state)).apply()
        } catch (_: Exception) {
        }
    }

    private fun lang(): Lang = langPref(appCtx)

    /** Ao abrir: re-agenda os alarmes ainda no futuro (sobrevive a reinício/reboot). */
    private fun reconcile() {
        for (char in state.characters) {
            for (task in shownBattle(char)) if (isBattleActive(char, task)) scheduleBattle(char, task)
            for (berry in shownBerries) if (state.berry[berryKey(char, berry)] != null) scheduleBerry(char, berry)
        }
    }

    // MARK: - Personagens (cadastro)

    fun addCharacter(name: String) {
        val n = name.trim()
        if (n.isEmpty()) return
        val newChar = GameCharacter(id = "char_" + shortId(), name = n.take(30))
        save(state.copy(characters = state.characters + newChar))
    }

    fun renameCharacter(id: String, name: String) {
        val n = name.trim()
        if (n.isEmpty()) return
        save(state.copy(characters = state.characters.map {
            if (it.id == id) it.copy(name = n.take(30)) else it
        }))
    }

    /** Define (ou limpa, com null) a foto do boneco. `pngBase64` = PNG 128×128 já redimensionado. */
    fun setAvatar(id: String, pngBase64: String?) {
        save(state.copy(characters = state.characters.map {
            if (it.id == id) it.copy(avatar = pngBase64) else it
        }))
    }

    fun removeCharacter(id: String) {
        CooldownNotifications.cancelPrefix(appCtx, "cd.battle.$id.")
        CooldownNotifications.cancelPrefix(appCtx, "cd.berry.$id.")
        save(
            state.copy(
                characters = state.characters.filterNot { it.id == id },
                battle = state.battle.filterKeys { !it.startsWith("$id:") },
                berry = state.berry.filterKeys { !it.startsWith("$id:") },
            )
        )
    }

    // MARK: - Tarefas de batalha

    /** Batalhas mostradas por boneco: as obrigatórias; as opcionais ficam num grupo à parte na UI. */
    fun shownBattle(char: GameCharacter): List<BattleTask> = catalog.battleTasks

    private fun battleKey(char: GameCharacter, id: String) = "${char.id}:$id"
    private fun battleNotifId(char: GameCharacter, id: String) = "cd.battle.${char.id}.$id"

    fun isBattleActive(char: GameCharacter, task: BattleTask, now: Long = nowMs()): Boolean =
        state.battle[battleKey(char, task.id)] != null && battleRemainingMs(char, task, now) > 0

    /** Ms restantes; <= 0 (ou nunca marcado) = pronto. */
    fun battleRemainingMs(char: GameCharacter, task: BattleTask, now: Long = nowMs()): Long {
        val markedAt = state.battle[battleKey(char, task.id)] ?: return 0
        return markedAt + (task.hours * 3_600_000).toLong() - now
    }

    fun battleReady(char: GameCharacter, task: BattleTask, now: Long = nowMs()): Boolean =
        battleRemainingMs(char, task, now) <= 0

    enum class BattlePhase { IDLE, RUNNING, READY }

    /** idle = nunca marcado · running = em cooldown · ready = já marcado e liberou. */
    fun battlePhase(char: GameCharacter, task: BattleTask, now: Long = nowMs()): BattlePhase {
        if (state.battle[battleKey(char, task.id)] == null) return BattlePhase.IDLE
        return if (battleRemainingMs(char, task, now) > 0) BattlePhase.RUNNING else BattlePhase.READY
    }

    fun markBattle(char: GameCharacter, task: BattleTask) {
        save(state.copy(battle = state.battle + (battleKey(char, task.id) to nowMs())))
        scheduleBattle(char, task)
    }

    fun clearBattle(char: GameCharacter, task: BattleTask) {
        CooldownNotifications.cancel(appCtx, battleNotifId(char, task.id))
        save(state.copy(battle = state.battle - battleKey(char, task.id)))
    }

    private fun scheduleBattle(char: GameCharacter, task: BattleTask) {
        val markedAt = state.battle[battleKey(char, task.id)] ?: return
        val lang = lang()
        CooldownNotifications.schedule(
            appCtx,
            battleNotifId(char, task.id),
            markedAt + (task.hours * 3_600_000).toLong(),
            Strings.text(L.CdNotifReady, lang).format(task.name.localized(lang)),
            Strings.text(L.CdNotifCharacter, lang).format(char.name),
        )
    }

    // MARK: - Berries

    /** Berries mostradas: as defaultOn + as que o usuário adicionou (enabledBerry). */
    val shownBerries: List<BerryDef>
        get() = catalog.berries.filter { it.defaultOn || state.enabledBerry.contains(it.id) }

    fun addBerry(id: String) {
        if (state.enabledBerry.contains(id)) return
        save(state.copy(enabledBerry = state.enabledBerry + id))
    }

    fun removeBerry(id: String) {
        for (c in state.characters) CooldownNotifications.cancelPrefix(appCtx, "cd.berry.${c.id}.$id.")
        save(
            state.copy(
                enabledBerry = state.enabledBerry.filterNot { it == id },
                berry = state.berry.filterKeys { !it.contains(":$id:") },
            )
        )
    }

    private fun berryKey(char: GameCharacter, berry: BerryDef, plot: Int = 0) =
        "${char.id}:${berry.id}:$plot"

    private fun berryNotifPrefix(char: GameCharacter, berry: BerryDef, plot: Int = 0) =
        "cd.berry.${char.id}.${berry.id}.$plot."

    enum class BerryPhase { EMPTY, GROWING, READY, WILTED }

    /** Instantâneo do canteiro: fase + tempos (plantar/regar/colher) + progresso de rega. */
    data class BerryStatus(
        val phase: BerryPhase,
        val harvestRemainMs: Long,
        val nextWaterRemainMs: Long?,
        val waterPending: Boolean,
        val waterings: Int,      // regas já confirmadas
        val totalWaters: Int,    // regas do tier no ciclo todo
    )

    /** Fase atual + tempos derivados do `plantedAt` + tier. */
    fun berryStatus(char: GameCharacter, berry: BerryDef, plot: Int = 0, now: Long = nowMs()): BerryStatus {
        val p = state.berry[berryKey(char, berry, plot)]
        val tier = catalog.tier(berry.tier)
        if (p == null || tier == null) {
            return BerryStatus(BerryPhase.EMPTY, 0, null, false, 0, 0)
        }
        val total = tier.waterWindowsHours.size
        val harvestAt = p.plantedAt + (tier.growthHours * 3_600_000).toLong()
        val wiltAt = harvestAt + (tier.wiltHours * 3_600_000).toLong()
        var nextWaterRemain: Long? = null
        var pending = false
        if (p.waterings < total) {
            val limit = (tier.waterWindowsHours[p.waterings] * 3_600_000).toLong()
            val fireAt = p.plantedAt + limit - (tier.waterLeadHours * 3_600_000).toLong()
            nextWaterRemain = fireAt - now
            pending = now >= fireAt          // já entrou na janela de regar
        }
        val phase = if (now < harvestAt) BerryPhase.GROWING
        else if (now < wiltAt) BerryPhase.READY else BerryPhase.WILTED
        return BerryStatus(phase, harvestAt - now, nextWaterRemain, pending, p.waterings, total)
    }

    fun plantBerry(char: GameCharacter, berry: BerryDef, plot: Int = 0) {
        save(state.copy(berry = state.berry + (berryKey(char, berry, plot) to BerryProgress(nowMs(), 0))))
        scheduleBerry(char, berry, plot)
    }

    fun waterBerry(char: GameCharacter, berry: BerryDef, plot: Int = 0) {
        val key = berryKey(char, berry, plot)
        val p = state.berry[key] ?: return
        val tier = catalog.tier(berry.tier) ?: return
        if (p.waterings >= tier.waterWindowsHours.size) return
        val np = p.copy(waterings = p.waterings + 1)
        CooldownNotifications.cancel(appCtx, berryNotifPrefix(char, berry, plot) + "w${np.waterings - 1}")
        save(state.copy(berry = state.berry + (key to np)))
    }

    fun harvestBerry(char: GameCharacter, berry: BerryDef, plot: Int = 0) {
        CooldownNotifications.cancelPrefix(appCtx, berryNotifPrefix(char, berry, plot))
        save(state.copy(berry = state.berry - berryKey(char, berry, plot)))
    }

    private fun scheduleBerry(char: GameCharacter, berry: BerryDef, plot: Int = 0) {
        val p = state.berry[berryKey(char, berry, plot)] ?: return
        val tier = catalog.tier(berry.tier) ?: return
        val prefix = berryNotifPrefix(char, berry, plot)
        val lang = lang()
        val body = Strings.text(L.CdNotifCharacter, lang).format(char.name)
        // lembretes de rega (a partir da próxima ainda não feita)
        for (i in p.waterings until tier.waterWindowsHours.size) {
            val fireAt = p.plantedAt + ((tier.waterWindowsHours[i] - tier.waterLeadHours) * 3_600_000).toLong()
            CooldownNotifications.schedule(
                appCtx, prefix + "w$i", fireAt,
                Strings.text(L.CdNotifWater, lang).format(berry.name.localized(lang)), body
            )
        }
        // pronta pra colher
        val harvestAt = p.plantedAt + (tier.growthHours * 3_600_000).toLong()
        CooldownNotifications.schedule(
            appCtx, prefix + "harvest", harvestAt,
            Strings.text(L.CdNotifBerryReady, lang).format(berry.name.localized(lang)), body
        )
        // aviso de wilt (1h antes de murchar)
        val wiltAt = harvestAt + (tier.wiltHours * 3_600_000).toLong()
        CooldownNotifications.schedule(
            appCtx, prefix + "wilt", wiltAt - 3_600_000,
            Strings.text(L.CdNotifWilt, lang).format(berry.name.localized(lang)), body
        )
    }

    // MARK: - Util

    private fun shortId(): String {
        val hex = "0123456789abcdef"
        return (0 until 8).map { hex.random() }.joinToString("")
    }

    companion object {
        private const val STATE_KEY = "cooldowns.state.v2"
    }
}
