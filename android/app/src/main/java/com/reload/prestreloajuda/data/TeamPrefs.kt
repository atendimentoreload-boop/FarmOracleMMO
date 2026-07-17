package com.reload.prestreloajuda.data

import android.content.Context

/** Preferências de time/visualização, em SharedPreferences. */
object TeamPrefs {
    private const val PREFS = "team_prefs"
    private const val KEY_TEAM = "team"
    private const val KEY_EMOJI = "emoji"
    private const val KEY_SCALE = "ui_scale"
    private const val KEY_OVL_W = "overlay_w"
    private const val KEY_OVL_H = "overlay_h"
    private const val KEY_OPACITY = "overlay_opacity"
    private const val KEY_LANG = "ui_lang"
    private const val KEY_LANG_CHOSEN = "ui_lang_chosen"
    private const val KEY_LAUNCH_MODE = "ui_launch_mode"   // #44: modo de abertura lembrado
    private const val KEY_FARM_ROUTE = "farm_route"
    private const val KEY_CM_STRATEGY = "cynthia_morimoto_strategy"
    private const val KEY_RED_STRATEGY = "red_strategy"
    private const val KEY_HOOH_STRATEGY = "hooh_strategy"

    // Tamanho padrão do painel (em dp). Largura cabe num celular em pé; altura idem.
    const val DEFAULT_W = 300f
    const val DEFAULT_H = 430f
    const val MIN_W = 220f
    const val MIN_H = 220f

    // Opacidade do overlay: padrão e limites espelham o Mac (OverlayController).
    const val DEFAULT_OPACITY = 1.0f
    const val MIN_OPACITY = 0.35f
    const val MAX_OPACITY = 1.0f

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun team(ctx: Context): String? = prefs(ctx).getString(KEY_TEAM, null)
    fun setTeam(ctx: Context, id: String) = prefs(ctx).edit().putString(KEY_TEAM, id).apply()

    fun emoji(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_EMOJI, false)
    fun setEmoji(ctx: Context, on: Boolean) = prefs(ctx).edit().putBoolean(KEY_EMOJI, on).apply()

    /** Nível de tamanho da sobreposição: 0 = Compacto, 1 = Normal, 2 = Grande. */
    fun uiScale(ctx: Context): Int = prefs(ctx).getInt(KEY_SCALE, 1).coerceIn(0, 2)
    fun setUiScale(ctx: Context, level: Int) =
        prefs(ctx).edit().putInt(KEY_SCALE, level.coerceIn(0, 2)).apply()

    /** Largura/altura do painel flutuante (dp), ajustadas pela alça de redimensionar. */
    fun overlayW(ctx: Context): Float = prefs(ctx).getFloat(KEY_OVL_W, DEFAULT_W)
    fun overlayH(ctx: Context): Float = prefs(ctx).getFloat(KEY_OVL_H, DEFAULT_H)
    fun setOverlaySize(ctx: Context, w: Float, h: Float) =
        prefs(ctx).edit().putFloat(KEY_OVL_W, w).putFloat(KEY_OVL_H, h).apply()

    /** Opacidade do overlay (0.35–1.0). A escolha sobrevive entre aberturas. */
    fun opacity(ctx: Context): Float =
        prefs(ctx).getFloat(KEY_OPACITY, DEFAULT_OPACITY).coerceIn(MIN_OPACITY, MAX_OPACITY)
    fun setOpacity(ctx: Context, value: Float) =
        prefs(ctx).edit().putFloat(KEY_OPACITY, value.coerceIn(MIN_OPACITY, MAX_OPACITY)).apply()

    /** Idioma da interface ("pt"/"en"). null = ainda não escolhido (cai no idioma do aparelho). */
    fun language(ctx: Context): String? = prefs(ctx).getString(KEY_LANG, null)
    fun setLanguage(ctx: Context, code: String) =
        prefs(ctx).edit().putString(KEY_LANG, code).apply()

    /** Idioma do aparelho reduzido a "pt"/"en" (default usado só na 1ª abertura). */
    fun deviceDefaultLang(): String =
        if (java.util.Locale.getDefault().language.equals("pt", ignoreCase = true)) "pt" else "en"

    /** Se o usuário já escolheu o idioma na 1ª abertura (mostra o seletor só uma vez). */
    fun langChosen(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_LANG_CHOSEN, false)
    fun setLangChosen(ctx: Context) = prefs(ctx).edit().putBoolean(KEY_LANG_CHOSEN, true).apply()

    // #44: "overlay" | "window" | null (ainda não escolheu → mostra o Launcher). Depois de escolher,
    // não pergunta mais no começo; o chip de overlay/o botão "Abrir em janela" trocam o modo.
    fun launchMode(ctx: Context): String? = prefs(ctx).getString(KEY_LAUNCH_MODE, null)
    fun setLaunchMode(ctx: Context, mode: String) = prefs(ctx).edit().putString(KEY_LAUNCH_MODE, mode).apply()

    /** Rota ativa do Farm de Ginásios ("veteran"/"lucky_girl"). Default "veteran". */
    fun farmRoute(ctx: Context): String = prefs(ctx).getString(KEY_FARM_ROUTE, "veteran") ?: "veteran"
    fun setFarmRoute(ctx: Context, id: String) = prefs(ctx).edit().putString(KEY_FARM_ROUTE, id).apply()

    /** Estratégia/time ativo do modo Cynthia & Morimoto. Default "cynthia_morimoto" (a 1ª). */
    fun cynthiaMorimotoStrategy(ctx: Context): String =
        prefs(ctx).getString(KEY_CM_STRATEGY, "cynthia_morimoto") ?: "cynthia_morimoto"
    fun setCynthiaMorimotoStrategy(ctx: Context, id: String) =
        prefs(ctx).edit().putString(KEY_CM_STRATEGY, id).apply()

    /** Estratégia/time ativo do modo Red ("red"/"red_colored"). Default "red" (a 1ª). */
    fun redStrategy(ctx: Context): String =
        prefs(ctx).getString(KEY_RED_STRATEGY, "red") ?: "red"
    fun setRedStrategy(ctx: Context, id: String) =
        prefs(ctx).edit().putString(KEY_RED_STRATEGY, id).apply()

    /** Estratégia/time ativo do modo Ho-Oh ("hooh"/"hooh_trickroom"). Default "hooh" (a 1ª). */
    fun hoohStrategy(ctx: Context): String =
        prefs(ctx).getString(KEY_HOOH_STRATEGY, "hooh") ?: "hooh"
    fun setHoohStrategy(ctx: Context, id: String) =
        prefs(ctx).edit().putString(KEY_HOOH_STRATEGY, id).apply()
}
