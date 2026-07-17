package com.reload.prestreloajuda.data

import android.content.Context
import com.reload.prestreloajuda.model.Solve
import kotlinx.serialization.json.Json

object SolveLoader {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /**
     * Carrega um Solve do `assets/data/<name>.json`.
     *
     * Quando `lang == "en"`, tenta primeiro a variante traduzida (subpasta `en/` antes do
     * último componente do caminho) e cai para o PT se ela não existir — assim um roteiro
     * ainda sem tradução nunca quebra, apenas aparece em português. Porte fiel do
     * SolveLoader.swift do Mac.
     */
    fun load(context: Context, name: String, lang: String = "pt"): Solve {
        if (lang == "en") {
            readAsset(context, "data/${enVariant(name)}.json")?.let { return decode(it) }
        }
        val text = context.assets.open("data/$name.json")
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        return decode(text)
    }

    /**
     * Insere o diretório de idioma `en/` antes do último componente do caminho.
     * "red" -> "en/red" · "teams/x/elite4_kanto" -> "teams/x/en/elite4_kanto"
     * "teams/x/emoji/elite4_kanto" -> "teams/x/emoji/en/elite4_kanto"
     */
    private fun enVariant(name: String): String {
        val parts = name.split("/").toMutableList()
        val base = if (parts.isNotEmpty()) parts.removeAt(parts.lastIndex) else name
        parts.add("en")
        parts.add(base)
        return parts.joinToString("/")
    }

    /** Lê um asset se existir; null caso contrário (sem lançar). */
    private fun readAsset(context: Context, path: String): String? = try {
        context.assets.open(path).bufferedReader(Charsets.UTF_8).use { it.readText() }
    } catch (_: Exception) {
        null
    }

    private fun decode(text: String): Solve = json.decodeFromString(Solve.serializer(), text)
}
