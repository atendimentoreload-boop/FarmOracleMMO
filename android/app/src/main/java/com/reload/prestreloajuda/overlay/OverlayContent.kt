package com.reload.prestreloajuda.overlay

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.reload.prestreloajuda.R
import com.reload.prestreloajuda.data.TeamPrefs
import com.reload.prestreloajuda.ui.AppRoot
import com.reload.prestreloajuda.ui.AppState
import com.reload.prestreloajuda.ui.Lang
import com.reload.prestreloajuda.ui.LocalContentWidthDp
import com.reload.prestreloajuda.ui.LocalLang
import com.reload.prestreloajuda.ui.LocalSearchFocus
import com.reload.prestreloajuda.ui.LocalOpacityController
import com.reload.prestreloajuda.ui.OpacityController
import com.reload.prestreloajuda.ui.Theme
import com.reload.prestreloajuda.ui.langPref

@Composable
fun OverlayRoot(
    expanded: MutableState<Boolean>,
    onDrag: (Float, Float) -> Unit,
    onClose: () -> Unit,
    onSearchFocus: (Boolean) -> Unit,
    onOpacityChange: (Float) -> Unit,
    onResizePanel: (Float, Float) -> Unit,
    onCollapseToBubble: () -> Unit,
    maxPanelDp: () -> Pair<Float, Float>,
) {
    val ctx = LocalContext.current
    // Estado e tamanho vivem AQUI (sempre composto), não dentro do painel que some ao minimizar.
    val appState = remember { AppState(ctx) }
    var scaleLevel by remember { mutableStateOf(TeamPrefs.uiScale(ctx)) }

    // Idioma reativo: trocar no menu recompõe toda a sobreposição.
    var lang by remember { mutableStateOf(langPref(ctx)) }
    // Controlador de opacidade compartilhado (slider nas Configurações -> janela do serviço).
    val opacityController = remember {
        OpacityController(
            initial = TeamPrefs.opacity(ctx),
            apply = { v -> TeamPrefs.setOpacity(ctx, v); onOpacityChange(v) },
        )
    }

    LaunchedEffect(expanded.value) {
        // Ao recolher: garante foco da busca desligado e volta a janela pro tamanho da bolha.
        // (Ao expandir, o setPanelSize do painel já define as flags certas — não-focável.)
        if (!expanded.value) { onSearchFocus(false); onCollapseToBubble() }
    }
    CompositionLocalProvider(
        LocalLang provides lang,
        LocalOpacityController provides opacityController,
        LocalSearchFocus provides onSearchFocus,
    ) {
        if (expanded.value) {
            OverlayPanel(
                appState = appState,
                scaleLevel = scaleLevel,
                onCycleScale = {
                    val next = (scaleLevel + 1) % 3
                    scaleLevel = next
                    TeamPrefs.setUiScale(ctx, next)
                },
                onSetLanguage = { l: Lang ->
                    lang = l
                    TeamPrefs.setLanguage(ctx, l.code)
                    appState.resetEngines()
                },
                onCollapse = { expanded.value = false },
                onClose = onClose,
                onDrag = onDrag,
                onResizePanel = onResizePanel,
                maxPanelDp = maxPanelDp,
            )
        } else {
            OverlayBubble(onExpand = { expanded.value = true }, onDrag = onDrag)
        }
    }
}

@Composable
private fun OverlayBubble(onExpand: () -> Unit, onDrag: (Float, Float) -> Unit) {
    Box(
        Modifier
            .size(58.dp)
            .clip(CircleShape)
            .pointerInput(Unit) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    var dragged = false
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        if (!change.pressed) break
                        val pan = change.positionChange()
                        if (dragged || pan.getDistance() > 8f) {
                            dragged = true
                            onDrag(pan.x, pan.y)
                            change.consume()
                        }
                    }
                    if (!dragged) onExpand()
                }
            },
        contentAlignment = Alignment.Center
    ) {
        // Ícone novo do app (a "Money Ball" roxa+dourada), não mais a Master Ball desenhada à mão.
        // O Box já está com clip(CircleShape), então a imagem fica recortada em círculo.
        Image(
            bitmap = rememberAppIconBitmap(),
            contentDescription = "FarmOracleMMO",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
        )
    }
}

/**
 * Ícone do app rasterizado para bitmap. NÃO usamos `painterResource(R.mipmap.ic_launcher…)`:
 * no Android 8+ esse recurso é um **adaptive-icon** (XML em `mipmap-anydpi-v26/`), que vira um
 * `AdaptiveIconDrawable` — e `painterResource` NÃO suporta esse tipo, lançando exceção e
 * derrubando o serviço de overlay ao abrir a bolha. Aqui carregamos o drawable e o desenhamos
 * num bitmap (compõe fundo + frente), seguro em qualquer API. Cacheado com `remember`.
 */
@Composable
private fun rememberAppIconBitmap(): ImageBitmap {
    val ctx = LocalContext.current
    return remember {
        val d = androidx.core.content.ContextCompat.getDrawable(ctx, R.mipmap.ic_launcher)
        val w = (d?.intrinsicWidth ?: 0).takeIf { it > 0 } ?: 192
        val h = (d?.intrinsicHeight ?: 0).takeIf { it > 0 } ?: 192
        val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bmp)
        d?.setBounds(0, 0, w, h)
        d?.draw(canvas)
        bmp.asImageBitmap()
    }
}

/** Fator de escala da sobreposição por nível: Compacto / Normal / Grande.
 *  Ajustado pra baixo (22/06): no celular o conteúdo ficava grande demais. */
private fun scaleFactor(level: Int): Float = when (level) {
    0 -> 0.72f
    2 -> 1.05f
    else -> 0.85f
}

private fun scaleGlyph(level: Int): String = when (level) {
    0 -> "A−"
    2 -> "A+"
    else -> "A"
}

@Composable
private fun OverlayPanel(
    appState: AppState,
    scaleLevel: Int,
    onCycleScale: () -> Unit,
    onSetLanguage: (Lang) -> Unit,
    onCollapse: () -> Unit,
    onClose: () -> Unit,
    onDrag: (Float, Float) -> Unit,
    onResizePanel: (Float, Float) -> Unit,
    maxPanelDp: () -> Pair<Float, Float>,
) {
    val ctx = LocalContext.current
    // Escala só do CONTEÚDO (sprites/dp/textos), ignorando a fonte do sistema.
    // O TAMANHO do painel é separado (alça de redimensionar), igual no PC.
    val base = LocalDensity.current
    val factor = scaleFactor(scaleLevel)
    val scaled = Density(density = base.density * factor, fontScale = 1f)

    // Teto = a tela inteira AGORA, vindo do serviço (WindowManager). Recalcula a cada
    // recomposição (inclusive durante o arraste da alça), então reflete a rotação atual —
    // em paisagem o painel agora estica de verdade pro lado.
    val (maxW, maxH) = maxPanelDp()

    var panelW by remember { mutableStateOf(TeamPrefs.overlayW(ctx)) }
    var panelH by remember { mutableStateOf(TeamPrefs.overlayH(ctx)) }
    val w = panelW.coerceIn(TeamPrefs.MIN_W, maxW)
    val h = panelH.coerceIn(TeamPrefs.MIN_H, maxH)

    // O TAMANHO DA JANELA é setado explicitamente no serviço (não via WRAP_CONTENT, que no
    // overlay nem sempre re-mede). Sempre que w/h mudam (abrir, arrastar a alça, girar), aplica.
    LaunchedEffect(w, h) { onResizePanel(w, h) }

    Box(Modifier.size(w.dp, h.dp)) {
        CompositionLocalProvider(LocalDensity provides scaled) {
            Surface(
                color = Theme.Bg,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(14.dp))
                    .border(1.dp, Theme.Border, RoundedCornerShape(14.dp))
            ) {
                Column(Modifier.fillMaxSize()) {
                    // Barra superior: arrastar + tamanho + recolher + fechar
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .background(Theme.Panel)
                            .pointerInput(Unit) {
                                detectDragGestures { change, drag ->
                                    change.consume(); onDrag(drag.x, drag.y)
                                }
                            }
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("⠿  FarmOracleMMO", color = Theme.TextDim, fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold, maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f))
                        ChromeBtn(scaleGlyph(scaleLevel), Theme.Accent, factor, filled = true) { onCycleScale() }
                        Spacer(Modifier.width(4.dp))
                        ChromeBtn("—", Theme.TextDim, factor) { onCollapse() }
                        Spacer(Modifier.width(4.dp))
                        ChromeBtn("✕", Theme.TextDim, factor) { onClose() }
                    }
                    Box(Modifier.weight(1f).fillMaxWidth()) {
                        // Passa a LARGURA real do painel (dp-base) pro conteúdo decidir colunas
                        // e modo compacto reativos à largura. `w` é o tamanho atual do painel.
                        CompositionLocalProvider(LocalContentWidthDp provides w) {
                            AppRoot(appState, onSetLanguage = onSetLanguage)
                        }
                    }
                }
            }
        }
        // Alça de redimensionar (canto inferior-direito) — dp reais, fora do zoom.
        ResizeHandle(
            modifier = Modifier.align(Alignment.BottomEnd),
            pxPerDp = base.density,
            onResize = { dxDp, dyDp ->
                panelW = (panelW.coerceIn(TeamPrefs.MIN_W, maxW) + dxDp).coerceIn(TeamPrefs.MIN_W, maxW)
                panelH = (panelH.coerceIn(TeamPrefs.MIN_H, maxH) + dyDp).coerceIn(TeamPrefs.MIN_H, maxH)
            },
            onResizeEnd = { TeamPrefs.setOverlaySize(ctx, panelW, panelH) },
        )
    }
}

/** Alça de canto pra ajustar largura+altura (igual puxar o canto de uma janela). */
@Composable
private fun ResizeHandle(
    modifier: Modifier,
    pxPerDp: Float,
    onResize: (Float, Float) -> Unit,
    onResizeEnd: () -> Unit,
) {
    Box(
        modifier
            .size(40.dp)                       // #55: alvo de toque generoso, fácil de pegar (era 30)
            .pointerInput(Unit) {
                detectDragGestures(onDragEnd = { onResizeEnd() }) { change, drag ->
                    change.consume()
                    onResize(drag.x / pxPerDp, drag.y / pxPerDp)
                }
            },
        contentAlignment = Alignment.BottomEnd
    ) {
        // #55 "deixar a alça óbvia": antes eram 3 tracinhos lilás fracos (0xFF9A8FC0, fora da
        // paleta) que o usuário casual não achava. Agora é um selo no accent (laranja) recuado
        // ~4dp pra assentar dentro do canto arredondado do painel (14dp), com tracinhos escuros
        // de alto contraste — lê como "arraste este canto pra mudar o tamanho".
        val grip = RoundedCornerShape(topStart = 12.dp, topEnd = 5.dp, bottomEnd = 12.dp, bottomStart = 5.dp)
        Box(
            Modifier
                .padding(end = 4.dp, bottom = 4.dp)
                .size(24.dp)
                .clip(grip)
                .background(Theme.Accent)
                .border(1.dp, Color.Black.copy(alpha = 0.2f), grip),
            contentAlignment = Alignment.Center
        ) {
            Canvas(Modifier.size(14.dp)) {
                val s = size.minDimension
                val ink = Theme.Bg            // near-preto (Theme.Bg): alto contraste no laranja
                for (i in 0..2) {
                    val o = s * (0.30f + i * 0.26f)
                    drawLine(ink, Offset(s, s - o), Offset(s - o, s),
                             strokeWidth = 2.4f, cap = StrokeCap.Round)
                }
            }
        }
    }
}

@Composable
private fun ChromeBtn(glyph: String, color: Color, factor: Float, filled: Boolean = false, onClick: () -> Unit) {
    // Alvo de toque em dp REAIS constante, independente do zoom de conteúdo (A-/A/A+).
    // Dentro da densidade escalada, X.dp/X.sp viram X*factor px; dividimos por factor pra o
    // botão não encolher no A- (compacto/paisagem). ~40dp reais de área tocável.
    // `filled` (#46): dá fundo/borda de CHIP pro controle de fonte não passar batido.
    Box(
        Modifier.size((40f / factor).dp).clip(RoundedCornerShape(8.dp))
            .then(if (filled) Modifier.background(Theme.PanelHi).border(1.dp, Theme.Border, RoundedCornerShape(8.dp)) else Modifier)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) { Text(glyph, color = color, fontSize = (15f / factor).sp, fontWeight = FontWeight.Bold) }
}
