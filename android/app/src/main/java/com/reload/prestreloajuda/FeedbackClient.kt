package com.reload.prestreloajuda

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Envia o feedback "funcionou / não funcionou" da Elite 4 para uma planilha do Google
 * (Web App do Apps Script). Fire-and-forget: se falhar, não atrapalha o jogo.
 *
 * COMO LIGAR: publique o Apps Script (tools/feedback-apps-script.gs) como Web App e cole
 * a URL /exec em [ENDPOINT]. Enquanto vazia, os botões só agradecem (não enviam nada).
 */
object FeedbackClient {
    // Cole aqui a URL do seu Web App do Apps Script (termina em /exec).
    private const val ENDPOINT = "https://script.google.com/macros/s/AKfycby_mOTEZqwLis9jJYBYVdFhW2vk99O8R9PMF1oLYHx0ocMiWWVPH4VSTyXTdK88mMVRuA/exec"

    val isConfigured: Boolean get() = ENDPOINT.isNotEmpty()

    fun send(
        result: String, mode: String, team: String?, trainer: String?,
        lead: String?, path: String?, node: String?, description: String?,
    ) {
        if (!isConfigured) return
        val body = JSONObject()
            .put("result", result)
            .put("mode", mode)
            .put("team", team ?: "")
            .put("trainer", trainer ?: "")
            .put("lead", lead ?: "")
            .put("path", path ?: "")
            .put("node", node ?: "")
            .put("description", description ?: "")
            .put("platform", "android")
            .put("version", BuildConfig.VERSION_NAME)
            .toString()
        thread {
            try {
                val conn = (URL(ENDPOINT).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 8000
                    readTimeout = 8000
                    doOutput = true
                    // text/plain evita o preflight de CORS do Apps Script.
                    setRequestProperty("Content-Type", "text/plain;charset=utf-8")
                }
                conn.outputStream.use { it.write(body.toByteArray()) }
                conn.inputStream.use { it.readBytes() }
                conn.disconnect()
            } catch (_: Exception) {
            }
        }
    }
}
