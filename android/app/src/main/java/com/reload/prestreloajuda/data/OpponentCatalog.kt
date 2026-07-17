package com.reload.prestreloajuda.data

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

// Catálogo dos times do adversário (Elite 4), extraído do Pokeking sem filtro de CODE.
// Porte fiel do OpponentCatalog.swift (Mac). Fonte: assets/data/elite4-opponents.json.
// Estrutura: regiões → treinador → [times]. Usado pelo overlay "Ver times".

@Serializable
data class OpponentMon(
    val pokemon: String,
    val ability: String = "",
    val item: String = "",
    val moves: List<String> = emptyList(),
)

@Serializable
data class OpponentTeam(
    val team: Int,                 // número "N号队伍" (bate com o lineList do roteiro)
    val pokemon: List<OpponentMon> = emptyList(),
) {
    fun contains(name: String): Boolean {
        val n = name.lowercase()
        return pokemon.any { it.pokemon.lowercase() == n }
    }
}

@Serializable
private data class CatalogFile(
    val regions: Map<String, Map<String, List<OpponentTeam>>> = emptyMap(),
)

object OpponentCatalog {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private var cache: Map<String, Map<String, List<OpponentTeam>>>? = null

    /** regiões → treinador → [times]. Carregado uma vez do assets. Fail-safe: vazio se faltar. */
    fun regions(context: Context): Map<String, Map<String, List<OpponentTeam>>> {
        cache?.let { return it }
        val loaded = try {
            val text = context.assets.open("data/elite4-opponents.json")
                .bufferedReader(Charsets.UTF_8).use { it.readText() }
            json.decodeFromString(CatalogFile.serializer(), text).regions
        } catch (_: Exception) {
            emptyMap()
        }
        cache = loaded
        return loaded
    }

    /** `elite4_sinnoh` → `Sinnoh`. null para modos que não são da Elite 4. */
    fun regionName(modeId: String): String? = when (modeId) {
        "elite4_kanto" -> "Kanto"
        "elite4_hoenn" -> "Hoenn"
        "elite4_sinnoh" -> "Sinnoh"
        "elite4_johto" -> "Johto"
        "elite4_unova" -> "Unova"
        else -> null
    }

    /** Nome do grupo no roteiro → chave no catálogo. Kanto "Gary" = "Blue"; Johto Bruno/Lance distintos. */
    fun trainerKey(region: String, group: String): String {
        if (region == "Johto") {
            if (group == "Bruno") return "Bruno (Johto)"
            if (group == "Lance") return "Lance (Johto)"
        }
        if (region == "Kanto" && group == "Gary") return "Blue"
        return group
    }

    fun teams(context: Context, region: String, trainer: String): List<OpponentTeam> =
        regions(context)[region]?.get(trainer) ?: emptyList()
}
