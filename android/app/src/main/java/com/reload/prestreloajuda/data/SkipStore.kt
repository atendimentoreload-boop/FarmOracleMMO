package com.reload.prestreloajuda.data

import android.content.Context

/**
 * Guarda, por modo (solve), as paradas marcadas para pular. Persiste em SharedPreferences.
 * O fluxo linear ("Próximo"/goto) salta automaticamente as paradas marcadas.
 * Porte do SkipStore.swift (Mac).
 */
class SkipStore(context: Context) {
    private val prefs = context.getSharedPreferences("skips", Context.MODE_PRIVATE)

    fun isSkipped(modeId: String, nodeId: String): Boolean =
        prefs.getStringSet(modeId, emptySet())?.contains(nodeId) == true

    fun toggle(modeId: String, nodeId: String) {
        val set = (prefs.getStringSet(modeId, emptySet()) ?: emptySet()).toMutableSet()
        if (!set.add(nodeId)) set.remove(nodeId)
        prefs.edit().putStringSet(modeId, set).apply()
    }

    fun count(modeId: String): Int = prefs.getStringSet(modeId, emptySet())?.size ?: 0
}
