package com.reload.prestreloajuda.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import com.reload.prestreloajuda.model.PaletteEntry

/** Constrói os termos coloridos a partir da paleta do modo + avisos de alerta. */
class Colorizer(palette: List<PaletteEntry>?) {

    // (texto, cor), ordenado por comprimento desc para casar frases longas antes.
    private val tokens: List<Pair<String, Color>>
    private val nameColor: HashMap<String, Color> = HashMap()

    init {
        val list = ArrayList<Pair<String, Color>>()
        palette?.forEach { entry ->
            val color = Theme.fromHex(entry.color)
            nameColor[entry.name] = color
            list.add(entry.name to color)
            entry.moves.forEach { list.add(it to color) }
        }
        // Avisos sempre destacados em âmbar (em todos os modos).
        ALERTS.forEach { list.add(it to Theme.Warning) }
        tokens = list.sortedByDescending { it.first.length }
    }

    private fun isWord(c: Char) = c.isLetterOrDigit()

    fun build(text: String, base: Color): AnnotatedString = buildAnnotatedString {
        val chars = text
        var i = 0
        val plain = StringBuilder()

        fun flush() {
            if (plain.isNotEmpty()) {
                withStyle(SpanStyle(color = base)) { append(plain.toString()) }
                plain.clear()
            }
        }

        while (i < chars.length) {
            // Markup inline {Golpe|Pokémon}
            if (chars[i] == '{') {
                val close = chars.indexOf('}', i + 1)
                if (close > i) {
                    val inner = chars.substring(i + 1, close)
                    val bar = inner.indexOf('|')
                    if (bar >= 0) {
                        val move = inner.substring(0, bar)
                        val owner = inner.substring(bar + 1)
                        flush()
                        val c = nameColor[owner] ?: base
                        withStyle(SpanStyle(color = c)) { append(move) }
                        i = close + 1
                        continue
                    }
                }
            }
            var matched = false
            for ((phrase, color) in tokens) {
                val len = phrase.length
                if (i + len > chars.length) continue
                if (chars.regionMatches(i, phrase, 0, len)) {
                    val beforeOk = i == 0 || !isWord(chars[i - 1])
                    val after = i + len
                    val afterOk = after >= chars.length || !isWord(chars[after])
                    if (beforeOk && afterOk) {
                        flush()
                        withStyle(SpanStyle(color = color)) { append(phrase) }
                        i = after
                        matched = true
                        break
                    }
                }
            }
            if (!matched) {
                plain.append(chars[i]); i += 1
            }
        }
        flush()
    }

    companion object {
        private val ALERTS = listOf(
            "(não precisa usar Encore para bufar)",
            "Não precisa usar Encore para bufar",
        )
    }
}
