package com.reload.prestreloajuda

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Dados de versão publicados em /version.json (raw do GitHub). */
data class UpdateInfo(val latest: String, val minimum: String, val url: String)

/**
 * Checa a versão mínima exigida online e compara com a versão local.
 * Política "fail-open": se não der pra checar (offline/erro), retorna null e NÃO bloqueia.
 */
object UpdateChecker {
    private const val VERSION_URL =
        "https://raw.githubusercontent.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/main/version.json"
    const val RELEASES_URL =
        "https://github.com/viniciospmarinho-prestrelo/prestrelo-ajuda-download/releases/latest"

    suspend fun fetch(): UpdateInfo? = withContext(Dispatchers.IO) {
        try {
            val conn = (URL(VERSION_URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = 6000
                readTimeout = 6000
                requestMethod = "GET"
            }
            conn.inputStream.bufferedReader().use { reader ->
                val obj = JSONObject(reader.readText())
                UpdateInfo(
                    obj.optString("latest", ""),
                    obj.optString("minimum", ""),
                    obj.optString("url", RELEASES_URL),
                )
            }
        } catch (_: Exception) {
            null // fail-open
        }
    }

    /** Compara "x.y.z". <0 se a<b, 0 se iguais, >0 se a>b. */
    fun compare(a: String, b: String): Int {
        val pa = parse(a); val pb = parse(b)
        for (i in 0..2) if (pa[i] != pb[i]) return pa[i].compareTo(pb[i])
        return 0
    }

    private fun parse(v: String): IntArray {
        val r = intArrayOf(0, 0, 0)
        val parts = v.split(".")
        for (i in 0 until minOf(3, parts.size)) r[i] = parts[i].toIntOrNull() ?: 0
        return r
    }
}
