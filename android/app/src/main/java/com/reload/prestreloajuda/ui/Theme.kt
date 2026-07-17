package com.reload.prestreloajuda.ui

import androidx.compose.ui.graphics.Color

/** Paleta espelhando o Theme do Mac/Windows. */
object Theme {
    val Bg = Color(0xFF121213)
    val Panel = Color(0xFF1F1F24)
    val PanelHi = Color(0xFF2B2B33)
    val Border = Color(0x1AFFFFFF)
    val Line = Color(0x12FFFFFF)

    val Text = Color(0xFFEBEBF0)
    val TextDim = Color(0xFF9E9EA8)

    val Accent = Color(0xFFFF9E33)          // laranja (Infernape)
    val AccentSoft = Color(0x2EFF9E33)
    val Choice = Color(0xFF66B8FF)          // azul p/ escolhas
    val ChoiceSoft = Color(0x2966B8FF)
    val Good = Color(0xFF73D980)            // verde
    val GoodSoft = Color(0x2673D980)
    val Warning = Color(0xFFFFC747)         // âmbar (avisos/alertas)
    val WarningSoft = Color(0x22FFC747)
    val Danger = Color(0xFFFF6B6B)          // vermelho (não funcionou)
    val DangerSoft = Color(0x22FF6B6B)
    val PasteYellow = Color(0xFFFFD140)     // amarelo do botão Poképaste

    fun fromHex(hex: String): Color {
        val s = hex.trim().removePrefix("#")
        return try {
            val v = s.toLong(16)
            when (s.length) {
                6 -> Color(0xFF000000L or v)
                8 -> Color(v)
                else -> Text
            }
        } catch (e: Exception) {
            Text
        }
    }
}
