package com.reload.prestreloajuda.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.reload.prestreloajuda.data.TeamPrefs

/** Serviço em primeiro plano que desenha a bolha/painel flutuante sobre os outros apps. */
class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var composeView: ComposeView? = null
    private val lifecycleOwner = OverlayLifecycleOwner()
    private lateinit var params: WindowManager.LayoutParams
    private val expanded = mutableStateOf(false)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        lifecycleOwner.onCreate()
        addOverlay()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    private fun addOverlay() {
        val view = ComposeView(this).apply {
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeViewModelStoreOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent {
                OverlayRoot(
                    expanded = expanded,
                    onDrag = { dx, dy -> moveBy(dx, dy) },
                    onClose = { stopSelf() },
                    onSearchFocus = { focused -> setSearchFocused(focused) },
                    onOpacityChange = { value -> setOpacity(value) },
                    onResizePanel = { wDp, hDp -> setPanelSize(wDp, hDp) },
                    onCollapseToBubble = { resetToBubble() },
                    maxPanelDp = { maxPanelDp() },
                )
            }
        }
        composeView = view

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 24
            y = 160
            // Quando a janela está focável (busca), reflui acima do teclado em vez de ficar atrás.
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            // Opacidade persistida da janela inteira (0.35–1.0). Espelha o alphaValue do Mac.
            alpha = TeamPrefs.opacity(this@OverlayService)
        }
        windowManager.addView(view, params)
    }

    /** Ajusta a opacidade da janela inteira (afeta só o overlay, não o jogo atrás). */
    private fun setOpacity(value: Float) {
        val v = value.coerceIn(TeamPrefs.MIN_OPACITY, TeamPrefs.MAX_OPACITY)
        if (params.alpha != v) {
            params.alpha = v
            composeView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
        }
    }

    private fun moveBy(dx: Float, dy: Float) {
        params.x += dx.toInt()
        params.y += dy.toInt()
        clampPosition()
        composeView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
    }

    /** Tamanho real da tela AGORA em px (reflete a rotação). */
    private fun screenSizePx(): Pair<Int, Int> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = windowManager.currentWindowMetrics.bounds
            b.width() to b.height()
        } else {
            val dm = android.util.DisplayMetrics()
            @Suppress("DEPRECATION") windowManager.defaultDisplay.getRealMetrics(dm)
            dm.widthPixels to dm.heightPixels
        }

    /** Teto do painel em dp (largura/altura da tela atual) — a UI usa pra limitar a alça. */
    fun maxPanelDp(): Pair<Float, Float> {
        val density = resources.displayMetrics.density
        val (w, h) = screenSizePx()
        return (w / density) to (h / density)
    }

    /** Mantém a janela inteira dentro da tela (quando tem tamanho explícito). */
    private fun clampPosition() {
        val (sw, sh) = screenSizePx()
        val w = if (params.width > 0) params.width else 0
        val h = if (params.height > 0) params.height else 0
        if (w > 0) params.x = params.x.coerceIn(0, (sw - w).coerceAtLeast(0))
        if (h > 0) params.y = params.y.coerceIn(0, (sh - h).coerceAtLeast(0))
    }

    /**
     * Define o tamanho do painel EXPLICITAMENTE (em dp → px), em vez de depender do
     * WRAP_CONTENT acompanhar o conteúdo Compose — que no overlay nem sempre re-mede a janela
     * e era por isso que "não dava pra alargar". Limita à tela atual e mantém na tela.
     */
    fun setPanelSize(wDp: Float, hDp: Float) {
        val density = resources.displayMetrics.density
        val (sw, sh) = screenSizePx()
        val wPx = (wDp * density).toInt().coerceIn((TeamPrefs.MIN_W * density).toInt(), sw)
        val hPx = (hDp * density).toInt().coerceIn((TeamPrefs.MIN_H * density).toInt(), sh)
        // Painel aberto, por padrão: NÃO-focável + NOT_TOUCH_MODAL (toques fora vão pro jogo,
        // teclado físico anda no jogo) e sem NO_LIMITS (fica preso na tela). O foco só liga
        // enquanto a busca está ativa (setSearchFocused). Isso conserta "não dá pra jogar com o
        // painel aberto" sem perder a busca.
        val expandedFlags = (params.flags or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL) and
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS.inv()
        if (params.width == wPx && params.height == hPx && params.flags == expandedFlags) return
        params.width = wPx
        params.height = hPx
        params.flags = expandedFlags
        clampPosition()
        composeView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
    }

    /** Volta a janela pro tamanho automático da bolha (WRAP_CONTENT) e NÃO focável (deixa tocar o jogo). */
    fun resetToBubble() {
        val bubbleFlags = params.flags or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        if (params.width == WindowManager.LayoutParams.WRAP_CONTENT && params.flags == bubbleFlags) return
        params.width = WindowManager.LayoutParams.WRAP_CONTENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        params.flags = bubbleFlags
        composeView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
    }

    /**
     * Foco SÓ enquanto a busca está ativa. Por padrão o painel aberto é NÃO-focável + NOT_TOUCH_MODAL
     * (toques/teclas passam pro jogo — dá pra jogar com o guia aberto). Ao tocar a busca, tiramos
     * OS DOIS flags: a janela vira totalmente focável e o IME consegue "servir" o EditText (com
     * NOT_TOUCH_MODAL ligado o teclado dava "is not served" e não subia). Enquanto digita, os toques
     * fora do painel ficam bloqueados — tudo bem, você está digitando; ao sair da busca volta tudo.
     */
    fun setSearchFocused(focused: Boolean) {
        val notFocusable = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        val notTouchModal = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        val newFlags = if (focused) params.flags and notFocusable.inv() and notTouchModal.inv()
                       else params.flags or notFocusable or notTouchModal
        if (newFlags != params.flags) {
            params.flags = newFlags
            composeView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        composeView?.let { runCatching { windowManager.removeView(it) } }
        composeView = null
        lifecycleOwner.onDestroy()
    }

    private fun startInForeground() {
        val channelId = "prestrelo_overlay"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(channelId, "Guia flutuante", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(ch)
        }
        val notif: Notification = Notification.Builder(this, channelId)
            .setContentTitle("FarmOracleMMO")
            .setContentText("Guia flutuante ativo")
            .setSmallIcon(android.R.drawable.ic_menu_help)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notif)
        }
    }

    companion object {
        fun start(context: Context) {
            val i = Intent(context, OverlayService::class.java)
            context.startForegroundService(i)
        }
        fun stop(context: Context) {
            context.stopService(Intent(context, OverlayService::class.java))
        }
    }
}
