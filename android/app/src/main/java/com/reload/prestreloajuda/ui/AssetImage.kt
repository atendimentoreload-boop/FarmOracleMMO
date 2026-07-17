package com.reload.prestreloajuda.ui

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext

private val cache = HashMap<String, ImageBitmap?>()

/** Carrega um PNG de assets/data/<dir>/<name>.png (com cache). dir: sprites|trainers|regions|items. */
fun loadAsset(context: Context, dir: String, name: String): ImageBitmap? {
    val norm = if (dir == "sprites")
        name.lowercase().filter { it.isLetterOrDigit() }
    else
        name.lowercase().filter { it.isLetterOrDigit() || it == '-' }
    if (norm.isEmpty()) return null
    val key = "$dir/$norm"
    if (cache.containsKey(key)) return cache[key]
    val bmp = try {
        context.assets.open("data/$dir/$norm.png").use {
            BitmapFactory.decodeStream(it)?.asImageBitmap()
        }
    } catch (e: Exception) {
        null
    }
    cache[key] = bmp
    return bmp
}

@Composable
fun AssetImage(dir: String, name: String?, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val img = remember(dir, name) { name?.let { loadAsset(ctx, dir, it) } }
    if (img != null) {
        Image(bitmap = img, contentDescription = null, modifier = modifier, contentScale = ContentScale.Fit)
    }
}

// --- Master Ball ("money ball", ícone do app) como placeholder de rota sem Pokémon. ---
private var ballCache: ImageBitmap? = null
private fun loadBall(ctx: Context): ImageBitmap? {
    ballCache?.let { return it }
    // Fora de data/ (que é sincronizado de /data e gitignorado): a bola é asset fixo, versionado.
    val b = try {
        ctx.assets.open("masterball.png").use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
    } catch (e: Exception) { null }
    ballCache = b
    return b
}

/** Sprite do Pokémon `sprite` (já resolvido); se null/sem sprite, cai na Master Ball. */
@Composable
fun MonOrBall(sprite: String?, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val img = remember(sprite) { sprite?.let { loadAsset(ctx, "sprites", it) } ?: loadBall(ctx) }
    if (img != null) Image(bitmap = img, contentDescription = null, modifier = modifier, contentScale = ContentScale.Fit)
}

/** Ícone de uma ENTRADA (rota): resolve o Pokémon no rótulo; se não houver, Master Ball. */
@Composable
fun EntrySprite(label: String, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val name = remember(label) { optionSpriteName(ctx, label) }
    MonOrBall(name, modifier)
}

// --- Resolvedor de sprite por rótulo (porte do leadingSpriteName/optionSpriteName do Mac/Windows). ---
private var spriteKeys: Set<String>? = null
private fun spriteSet(ctx: Context): Set<String> {
    spriteKeys?.let { return it }
    val s = (ctx.assets.list("data/sprites") ?: emptyArray())
        .map { it.removeSuffix(".png").lowercase() }.toSet()
    spriteKeys = s
    return s
}
private fun spriteKey(s: String) = s.lowercase().filter { it.isLetterOrDigit() }

/** Casa um sprite começando na palavra `start`, testando janelas de 3→1 palavras. */
private fun spriteSequence(keys: Set<String>, words: List<String>, start: Int): String? {
    val max = minOf(3, words.size - start)
    for (n in max downTo 1) {
        val seq = words.subList(start, start + n).joinToString(" ")
        val k = spriteKey(seq)
        if (k.isNotEmpty() && k in keys) return seq
    }
    return null
}

private val opponentMarkers = setOf("contra", "vs", "versus")

/** Melhor sprite p/ um rótulo de OPÇÃO. Prioridade: 1) Pokémon no INÍCIO; 2) logo após um marcador
 *  de oponente ("vs."/"Contra"/"versus" → "vs. Blastoise", "troque para Dragonite Contra Gengar" →
 *  Gengar); 3) primeiro em qualquer posição. Divide em espaço E "/" (ex.: "Cacturne/Maractus"). */
fun optionSpriteName(ctx: Context, label: String): String? {
    val keys = spriteSet(ctx)
    val words = label.split(' ', '/').filter { it.isNotEmpty() }
    if (words.isEmpty()) return null
    spriteSequence(keys, words, 0)?.let { return it }
    for (i in words.indices)
        if (spriteKey(words[i]) in opponentMarkers && i + 1 < words.size)
            spriteSequence(keys, words, i + 1)?.let { return it }
    for (i in words.indices)
        spriteSequence(keys, words, i)?.let { return it }
    return null
}

/** Sprite de um rótulo de opção: resolve o Pokémon no rótulo (nada se não houver). */
@Composable
fun OptionSprite(label: String, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val name = remember(label) { optionSpriteName(ctx, label) }
    if (name != null) AssetImage("sprites", name, modifier)
}
