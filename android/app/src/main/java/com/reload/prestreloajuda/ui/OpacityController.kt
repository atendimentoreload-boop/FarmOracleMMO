package com.reload.prestreloajuda.ui

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.setValue

/**
 * Controla a opacidade do overlay. O valor vive aqui (estado observável p/ o slider) e cada
 * mudança é persistida + aplicada na janela do serviço via `apply`. Espelha o OverlayController
 * do Mac (setOpacity). Fora do overlay (app "Abrir aqui") o `apply` é no-op.
 */
class OpacityController(initial: Float, private val apply: (Float) -> Unit) {
    // Backing privado: evita o clash de assinatura JVM entre o setter gerado de `opacity`
    // e a função pública setOpacity(). `opacity` fica só-leitura (observável p/ o slider).
    private var _opacity by mutableFloatStateOf(initial.coerceIn(MIN, MAX))
    val opacity: Float get() = _opacity

    fun setOpacity(value: Float) {
        val v = value.coerceIn(MIN, MAX)
        _opacity = v
        apply(v)
    }

    companion object {
        const val MIN = 0.35f
        const val MAX = 1.0f
    }
}

/** Controlador disponível para as Configurações. Default no-op (modo "Abrir aqui"). */
val LocalOpacityController = compositionLocalOf<OpacityController?> { null }
