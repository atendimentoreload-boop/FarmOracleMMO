package com.reload.prestreloajuda.data

import android.content.Context
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** Um time jogável (define qual conjunto de soluções a Elite 4 usa). */
@Serializable
data class TeamInfo(
    val id: String = "",
    val name: String = "",
    /** Sprite usado como ícone do time (assets/data/sprites/<icon>.png). */
    val icon: String? = null,
    val pokemon: List<String> = emptyList(),
    val pokepaste: String? = null,
    /** CODE do Pokeking pra extrair o time no jogo (mostrado no botão de fonte). */
    val code: String? = null,
    /** Se o time tem versão "Modo Emoji" (combate na notação original do autor). */
    val hasEmoji: Boolean = false,
)

/** Manifesto data/teams.json: lista de times + quais modos variam por time. */
@Serializable
data class TeamsConfig(
    @SerialName("default") val defaultTeam: String = "",
    val teamScopedModes: List<String> = emptyList(),
    val teams: List<TeamInfo> = emptyList(),
) {
    fun get(id: String?): TeamInfo? = id?.let { i -> teams.firstOrNull { it.id == i } }
    fun isTeamScoped(modeId: String) = teamScopedModes.contains(modeId)
    fun resolve(id: String?): TeamInfo =
        get(id) ?: get(defaultTeam) ?: teams.firstOrNull() ?: TeamInfo(id = "", name = "Padrão")

    companion object {
        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        fun load(context: Context): TeamsConfig = try {
            val text = context.assets.open("data/teams.json")
                .bufferedReader(Charsets.UTF_8).use { it.readText() }
            json.decodeFromString(serializer(), text)
        } catch (e: Exception) {
            // Sem manifesto: um único "time" que lê os elite4 da raiz (compat retro).
            TeamsConfig(teams = listOf(TeamInfo(id = "", name = "Padrão")))
        }
    }
}
