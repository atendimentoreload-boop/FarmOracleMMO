package com.reload.prestreloajuda

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.compose.runtime.CompositionLocalProvider
import com.reload.prestreloajuda.data.TeamPrefs
import com.reload.prestreloajuda.overlay.OverlayService
import com.reload.prestreloajuda.ui.AppRoot
import com.reload.prestreloajuda.ui.AppState
import com.reload.prestreloajuda.ui.Lang
import com.reload.prestreloajuda.ui.LocalContentWidthDp
import com.reload.prestreloajuda.ui.LocalLang
import com.reload.prestreloajuda.ui.Theme
import com.reload.prestreloajuda.ui.langPref

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationsIfNeeded()
        setContent {
            // Bloqueio de versão obrigatória: checa a versão mínima online ao abrir.
            var block by remember { mutableStateOf<UpdateInfo?>(null) }
            LaunchedEffect(Unit) {
                // Builds de desenvolvimento (debug) NUNCA bloqueiam — só as distribuídas (release).
                if (!BuildConfig.DEBUG) {
                    val info = UpdateChecker.fetch()
                    if (info != null && info.minimum.isNotEmpty() &&
                        UpdateChecker.compare(BuildConfig.VERSION_NAME, info.minimum) < 0
                    ) {
                        block = info
                    }
                }
            }
            val blocked = block
            if (blocked != null) {
                UpdateBlockScreen(blocked)
            } else {
                val ctx = LocalContext.current
                // #44: modo de abertura lembrado — não pergunta mais no começo depois da 1ª escolha.
                var inApp by remember { mutableStateOf(TeamPrefs.launchMode(ctx) == "window") }
                val appState = remember { AppState(ctx) }
                var lang by remember { mutableStateOf(langPref(ctx)) }
                // 1ª abertura: pede o idioma antes de tudo (quem não entende a sobreposição
                // já escolhe PT/EN logo de cara). Mostra só uma vez (flag em TeamPrefs).
                var langChosen by remember { mutableStateOf(TeamPrefs.langChosen(ctx)) }
                CompositionLocalProvider(LocalLang provides lang) {
                    when {
                        !langChosen -> LanguagePicker(suggested = Lang.from(TeamPrefs.deviceDefaultLang()), onPick = { l: Lang ->
                            lang = l
                            TeamPrefs.setLanguage(ctx, l.code)
                            TeamPrefs.setLangChosen(ctx)
                            appState.resetEngines()
                            langChosen = true
                        })
                        inApp -> BoxWithConstraints {
                            // Tela cheia: a largura do conteúdo = largura da tela (sem zoom aqui).
                            CompositionLocalProvider(LocalContentWidthDp provides maxWidth.value) {
                                AppRoot(appState, onSetLanguage = { l: Lang ->
                                    lang = l
                                    TeamPrefs.setLanguage(ctx, l.code)
                                    appState.resetEngines()
                                }, onActivateOverlay = {
                                    TeamPrefs.setLaunchMode(ctx, "overlay"); startOverlay()
                                })
                            }
                        }
                        // Modo lembrado = overlay: abre a bolha automaticamente, com escape pra janela.
                        TeamPrefs.launchMode(ctx) == "overlay" -> OverlayActiveScreen(
                            lang = lang,
                            onOpenWindow = { TeamPrefs.setLaunchMode(ctx, "window"); inApp = true },
                            onActivateOverlay = { startOverlay() },
                        )
                        else -> Launcher(
                            lang = lang,
                            onOverlay = { TeamPrefs.setLaunchMode(ctx, "overlay"); startOverlay() },
                            onOpenHere = { TeamPrefs.setLaunchMode(ctx, "window"); inApp = true },
                        )
                    }
                }
            }
        }
    }

    private fun startOverlay() {
        if (!Settings.canDrawOverlays(this)) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
            return
        }
        OverlayService.start(this)
        moveTaskToBack(true)
    }

    private fun requestNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }
}

/** Seletor de idioma da 1ª abertura. Bilíngue de propósito (o usuário ainda não escolheu). */
@androidx.compose.runtime.Composable
private fun LanguagePicker(suggested: Lang, onPick: (Lang) -> Unit) {
    Surface(color = Theme.Bg, modifier = Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("FarmOracleMMO", color = Theme.Text, fontSize = 24.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Black)
            Spacer(Modifier.height(10.dp))
            Text(
                "Escolha o idioma  ·  Choose your language",
                color = Theme.TextDim, fontSize = 14.sp, textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(28.dp))
            // Idioma do aparelho vem em destaque (1º botão); o outro fica como alternativa.
            val other = if (suggested == Lang.PT) Lang.EN else Lang.PT
            LangPickButton(suggested, primary = true, onPick = onPick)
            Spacer(Modifier.height(12.dp))
            LangPickButton(other, primary = false, onPick = onPick)
        }
    }
}

@androidx.compose.runtime.Composable
private fun LangPickButton(lang: Lang, primary: Boolean, onPick: (Lang) -> Unit) {
    val label = if (lang == Lang.PT) "🇧🇷  Português" else "🇺🇸  English"
    BigButton(label,
        if (primary) Theme.Accent else Theme.Panel,
        if (primary) Color.Black else Theme.Text) { onPick(lang) }
}

@androidx.compose.runtime.Composable
private fun Launcher(lang: Lang, onOverlay: () -> Unit, onOpenHere: () -> Unit) {
    val ctx = LocalContext.current
    val canOverlay = Settings.canDrawOverlays(ctx)
    val en = lang == Lang.EN
    Surface(color = Theme.Bg, modifier = Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("FarmOracleMMO", color = Theme.Text, fontSize = 24.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Black)
            Spacer(Modifier.height(8.dp))
            Text(
                if (en) "Turn-by-turn PokeMMO guide. Turn on the floating bubble to read the route over the game."
                else "Guia turno-a-turno do PokeMMO. Ative a bolha flutuante para consultar o roteiro por cima do jogo.",
                color = Theme.TextDim, fontSize = 14.sp, textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(28.dp))

            BigButton(if (en) "🟣  Turn on floating guide" else "🟣  Ativar guia flutuante",
                Theme.Accent, Color.Black, onOverlay)
            Spacer(Modifier.height(12.dp))
            BigButton(if (en) "Open here (no overlay)" else "Abrir aqui (sem overlay)",
                Theme.Panel, Theme.Text, onOpenHere)

            if (!canOverlay) {
                Spacer(Modifier.height(16.dp))
                Text(
                    if (en) "First tap: Android will ask for the \"Display over other apps\" permission. Enable it and tap again."
                    else "1º toque: o Android vai pedir a permissão \"Sobrepor a outros apps\". Ative e toque de novo.",
                    color = Theme.TextDim, fontSize = 12.sp, textAlign = TextAlign.Center
                )
            }
        }
    }
}

/** #44: mostrada quando o modo lembrado é "overlay". Dispara a bolha ao entrar e dá o escape
 *  "Abrir em janela" pra quem quiser voltar ao modo tela-cheia (nunca fica preso no overlay). */
@androidx.compose.runtime.Composable
private fun OverlayActiveScreen(lang: Lang, onOpenWindow: () -> Unit, onActivateOverlay: () -> Unit) {
    val en = lang == Lang.EN
    LaunchedEffect(Unit) { onActivateOverlay() }
    Surface(color = Theme.Bg, modifier = Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("FarmOracleMMO", color = Theme.Text, fontSize = 24.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Black)
            Spacer(Modifier.height(8.dp))
            Text(
                if (en) "The floating guide is on — it opens over the game."
                else "O guia flutuante está ativado — ele abre por cima do jogo.",
                color = Theme.TextDim, fontSize = 14.sp, textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(28.dp))
            BigButton(if (en) "🟣  Bring back the floating guide" else "🟣  Voltar pra bolha flutuante",
                Theme.Accent, Color.Black, onActivateOverlay)
            Spacer(Modifier.height(12.dp))
            BigButton(if (en) "Open here (window mode)" else "Abrir aqui (modo janela)",
                Theme.Panel, Theme.Text, onOpenWindow)
        }
    }
}

@androidx.compose.runtime.Composable
private fun UpdateBlockScreen(info: UpdateInfo) {
    val ctx = LocalContext.current
    Surface(color = Theme.Bg, modifier = Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("⬇️", fontSize = 40.sp)
            Spacer(Modifier.height(10.dp))
            Text("Atualização obrigatória", color = Theme.Text, fontSize = 20.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(
                "Você está na v${BuildConfig.VERSION_NAME}. A versão mínima agora é v${info.minimum}. " +
                    "Baixe a nova para continuar.",
                color = Theme.TextDim, fontSize = 14.sp, textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(24.dp))
            BigButton("Baixar atualização", Theme.Accent, Color.Black) {
                ctx.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(info.url))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun BigButton(text: String, bg: Color, fg: Color, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(bg)
            .clickable { onClick() }.padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, color = fg, fontSize = 15.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
    }
}
