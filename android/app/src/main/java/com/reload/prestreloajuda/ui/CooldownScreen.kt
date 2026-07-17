package com.reload.prestreloajuda.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.reload.prestreloajuda.data.BattleTask
import com.reload.prestreloajuda.data.BerryDef
import com.reload.prestreloajuda.data.CooldownStore
import com.reload.prestreloajuda.data.GameCharacter
import com.reload.prestreloajuda.data.fmtHoursLabel
import com.reload.prestreloajuda.data.fmtRemain
import com.reload.prestreloajuda.data.nowMs
import kotlinx.coroutines.delay
import java.io.ByteArrayOutputStream

/** Tradução da chave para o idioma corrente da composição. */
@Composable
private fun trc(key: L): String = Strings.text(key, LocalLang.current)

/**
 * Tela do sistema de Cooldown/Alarme (#33), aberta pelo "reloginho" da tela inicial.
 * Lista principal = os BONECOS (cadastro). Ao abrir um boneco: abas Batalhas e Berries.
 * Porte fiel do CooldownView.swift do Mac.
 */
@Composable
fun CooldownScreen(store: CooldownStore, onBack: () -> Unit) {
    val ctx = LocalContext.current

    var selectedCharId by rememberSaveable { mutableStateOf<String?>(null) }
    var berries by rememberSaveable { mutableStateOf(false) }        // aba: false=Batalhas, true=Berries
    var showElite4 by rememberSaveable { mutableStateOf(false) }
    var showOptional by rememberSaveable { mutableStateOf(false) }
    var showBerryPicker by rememberSaveable { mutableStateOf(false) }
    var newCharName by rememberSaveable { mutableStateOf("") }
    var editing by remember { mutableStateOf<GameCharacter?>(null) }
    var confirmRemove by remember { mutableStateOf<GameCharacter?>(null) }

    // Ticker de 1s: re-renderiza os cronômetros ao vivo.
    var now by remember { mutableStateOf(nowMs()) }
    LaunchedEffect(Unit) { while (true) { delay(1000); now = nowMs() } }

    // Foto do boneco: só quando há um host de Activity (não roda na sobreposição sem Activity).
    val canPickPhoto = LocalActivityResultRegistryOwner.current != null
    var photoTargetId by remember { mutableStateOf<String?>(null) }
    val photoLauncher = if (canPickPhoto) rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        val id = photoTargetId
        if (uri != null && id != null) squareIconBase64(ctx, uri, 128)?.let { store.setAvatar(id, it) }
        photoTargetId = null
    } else null

    val state = store.state
    val selectedChar = state.characters.firstOrNull { it.id == selectedCharId }

    fun handleBack() {
        when {
            showBerryPicker -> showBerryPicker = false
            selectedCharId != null -> selectedCharId = null
            else -> onBack()
        }
    }
    if (LocalOnBackPressedDispatcherOwner.current != null) BackHandler { handleBack() }

    Column(Modifier.fillMaxSize().background(Theme.Bg)) {
        // Cabeçalho
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "‹ " + (if (selectedCharId != null) trc(L.CdCharacters) else trc(L.Back)),
                color = Theme.Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                modifier = Modifier.clickable { handleBack() }
            )
            Spacer(Modifier.weight(1f))
            Text(
                (selectedChar?.name ?: trc(L.CdTitle)).uppercase(),
                color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 12.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.width(40.dp))
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Theme.Border))

        if (showBerryPicker && selectedChar != null) {
            BerryPicker(store, onClose = { showBerryPicker = false })
        } else {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(12.dp)) {
                if (selectedChar == null) {
                    CharacterList(
                        store = store, now = now, newName = newCharName,
                        onNameChange = { newCharName = it },
                        onAdd = { store.addCharacter(newCharName); newCharName = "" },
                        onOpen = { selectedCharId = it.id; berries = false },
                        onEdit = { editing = it },
                        onRemove = { confirmRemove = it },
                    )
                } else {
                    CharacterDetail(
                        store = store, char = selectedChar, now = now,
                        berriesTab = berries, onTab = { berries = it },
                        showElite4 = showElite4, onToggleElite4 = { showElite4 = !showElite4 },
                        showOptional = showOptional, onToggleOptional = { showOptional = !showOptional },
                        onAddBerry = { showBerryPicker = true },
                    )
                }
            }
        }
    }

    // Diálogo de edição do boneco (renomear + foto).
    editing?.let { char ->
        var nameField by remember(char.id) { mutableStateOf(char.name) }
        AlertDialog(
            onDismissRequest = { editing = null },
            title = { Text(trc(L.CdRenameTitle), color = Theme.Text) },
            text = {
                Column {
                    OutlinedTextField(
                        value = nameField, onValueChange = { nameField = it }, singleLine = true
                    )
                    if (canPickPhoto && photoLauncher != null) {
                        Spacer(Modifier.height(10.dp))
                        Text(trc(L.CdPhotoHint), color = Theme.TextDim, fontSize = 11.sp)
                        Spacer(Modifier.height(6.dp))
                        Row {
                            TextButton(onClick = {
                                store.renameCharacter(char.id, nameField)
                                photoTargetId = char.id
                                editing = null
                                photoLauncher.launch("image/*")
                            }) {
                                Text(
                                    if (char.avatar == null) trc(L.CdChoosePhoto) else trc(L.CdChangePhoto),
                                    color = Theme.Accent
                                )
                            }
                            if (char.avatar != null) TextButton(onClick = {
                                store.setAvatar(char.id, null)
                            }) { Text(trc(L.CdRemovePhoto), color = Theme.Danger) }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { store.renameCharacter(char.id, nameField); editing = null }) {
                    Text("OK", color = Theme.Accent)
                }
            },
            dismissButton = {
                TextButton(onClick = { editing = null }) { Text(trc(L.Cancel), color = Theme.TextDim) }
            },
            containerColor = Theme.Panel,
        )
    }

    // Confirmação de remoção do boneco.
    confirmRemove?.let { char ->
        AlertDialog(
            onDismissRequest = { confirmRemove = null },
            title = { Text(String.format(trc(L.CdRemoveConfirm), char.name), color = Theme.Text, fontSize = 14.sp) },
            confirmButton = {
                TextButton(onClick = {
                    if (selectedCharId == char.id) selectedCharId = null
                    store.removeCharacter(char.id); confirmRemove = null
                }) { Text(trc(L.CdRemove), color = Theme.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmRemove = null }) { Text(trc(L.Cancel), color = Theme.TextDim) }
            },
            containerColor = Theme.Panel,
        )
    }
}

// ---------------- Lista de personagens (cadastro) ----------------

@Composable
private fun CharacterList(
    store: CooldownStore, now: Long, newName: String,
    onNameChange: (String) -> Unit, onAdd: () -> Unit,
    onOpen: (GameCharacter) -> Unit, onEdit: (GameCharacter) -> Unit, onRemove: (GameCharacter) -> Unit,
) {
    SectionLabel(trc(L.CdCharacters))
    Spacer(Modifier.height(6.dp))
    val chars = store.state.characters
    if (chars.isEmpty()) {
        Text(
            trc(L.CdNoCharacters), color = Theme.TextDim, fontSize = 12.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 22.dp)
        )
    } else {
        GroupBox {
            chars.forEachIndexed { i, char ->
                if (i > 0) RowLine()
                val active = store.shownBattle(char).count { store.isBattleActive(char, it, now) }
                val planted = store.shownBerries.count {
                    store.berryStatus(char, it, now = now).phase != CooldownStore.BerryPhase.EMPTY
                }
                val n = active + planted
                Row(
                    Modifier.fillMaxWidth().clickable { onOpen(char) }
                        .padding(horizontal = 12.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CharAvatar(char.name, char.avatar, 30.dp)
                    Spacer(Modifier.width(9.dp))
                    Text(char.name, color = Theme.Text, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                        maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 130.dp))
                    Spacer(Modifier.width(6.dp))
                    if (n > 0) Text(String.format(trc(L.CdActiveCount), n), color = Theme.TextDim, fontSize = 9.sp)
                    Spacer(Modifier.weight(1f))
                    IconMini("✎") { onEdit(char) }
                    IconMini("🗑") { onRemove(char) }
                    Text("›", color = Theme.TextDim.copy(alpha = 0.7f), fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
    // Cadastro
    Spacer(Modifier.height(8.dp))
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        OutlinedTextField(
            value = newName, onValueChange = onNameChange, singleLine = true,
            placeholder = { Text(trc(L.CdCharacterName), color = Theme.TextDim, fontSize = 12.sp) },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onAdd() }),
            modifier = Modifier.weight(1f)
        )
        Spacer(Modifier.width(8.dp))
        Box(
            Modifier.clip(RoundedCornerShape(10.dp)).background(Theme.Good).clickable { onAdd() }
                .padding(horizontal = 14.dp, vertical = 12.dp)
        ) { Text(trc(L.CdAdd), color = Color.Black, fontWeight = FontWeight.SemiBold, fontSize = 13.sp) }
    }
}

// ---------------- Detalhe do boneco (Batalhas / Berries) ----------------

@Composable
private fun CharacterDetail(
    store: CooldownStore, char: GameCharacter, now: Long,
    berriesTab: Boolean, onTab: (Boolean) -> Unit,
    showElite4: Boolean, onToggleElite4: () -> Unit,
    showOptional: Boolean, onToggleOptional: () -> Unit,
    onAddBerry: () -> Unit,
) {
    // Abas
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        TabButton("🔥 " + trc(L.CdBattles), !berriesTab, Modifier.weight(1f)) { onTab(false) }
        TabButton("🌿 " + trc(L.CdBerries), berriesTab, Modifier.weight(1f)) { onTab(true) }
    }
    Spacer(Modifier.height(10.dp))
    if (!berriesTab) BattlesSection(store, char, now, showElite4, onToggleElite4, showOptional, onToggleOptional)
    else BerriesSection(store, char, now, onAddBerry)
}

@Composable
private fun BattlesSection(
    store: CooldownStore, char: GameCharacter, now: Long,
    showElite4: Boolean, onToggleElite4: () -> Unit,
    showOptional: Boolean, onToggleOptional: () -> Unit,
) {
    val all = store.shownBattle(char)
    val elite = all.filter { it.group == "elite4" }
    val others = all.filter { it.group != "elite4" }

    // Elite 4 vira um submenu expansível.
    if (elite.isNotEmpty()) {
        val activeCount = elite.count { store.isBattleActive(char, it, now) }
        GroupBox {
            Row(
                Modifier.fillMaxWidth().clickable { onToggleElite4() }
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                CdTaskIcon("item:trophy", "#f59e0b", 28.dp)
                Spacer(Modifier.width(11.dp))
                Column(Modifier.weight(1f)) {
                    Text(trc(L.CdElite4), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    val sub = if (activeCount > 0) String.format(trc(L.CdActiveCount), activeCount)
                    else "${elite.size} " + (if (LocalLang.current == Lang.EN) "regions" else "regiões")
                    Text(sub, color = Theme.TextDim, fontSize = 10.sp)
                }
                Text(if (showElite4) "▼" else "▶", color = Theme.TextDim, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
            if (showElite4) elite.forEach { task ->
                RowLine()
                BattleRow(store, char, task, now, isChild = true)
            }
        }
        Spacer(Modifier.height(8.dp))
    }

    // Demais batalhas (ginásio, Red, Cynthia & Morimoto, farm de treinadores).
    if (others.isNotEmpty()) {
        GroupBox {
            others.forEachIndexed { i, task ->
                if (i > 0) RowLine()
                BattleRow(store, char, task, now, isChild = false)
            }
        }
    }

    // Opcionais (recolhido).
    Spacer(Modifier.height(6.dp))
    Row(
        Modifier.fillMaxWidth().clickable { onToggleOptional() }.padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(if (showOptional) "▼" else "▶", color = Theme.TextDim, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.width(6.dp))
        Text(trc(L.CdOptional).uppercase(), color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 9.sp)
    }
    if (showOptional) {
        Spacer(Modifier.height(4.dp))
        GroupBox {
            store.catalog.optionalTasks.forEachIndexed { i, task ->
                if (i > 0) RowLine()
                BattleRow(store, char, task, now, isChild = false)
            }
        }
    }
}

/** Rótulo curto quando a tarefa está sob um submenu ("Elite 4 — Kanto" -> "Kanto"). */
private fun shortLabel(full: String): String {
    val idx = full.indexOf("—")
    return if (idx >= 0) full.substring(idx + 1).trim() else full
}

@Composable
private fun BattleRow(store: CooldownStore, char: GameCharacter, task: BattleTask, now: Long, isChild: Boolean) {
    val lang = LocalLang.current
    val phase = store.battlePhase(char, task, now)
    val remain = store.battleRemainingMs(char, task, now)
    val ready = phase == CooldownStore.BattlePhase.READY
    Row(
        Modifier.fillMaxWidth()
            .background(if (ready) Theme.GoodSoft else Color.Transparent)
            .clickable(enabled = phase != CooldownStore.BattlePhase.RUNNING) { store.markBattle(char, task) }
            .padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        CdTaskIcon(task.icon, task.color, if (isChild) 26.dp else 30.dp)
        Spacer(Modifier.width(11.dp))
        Column(Modifier.weight(1f)) {
            Text(
                if (isChild) shortLabel(task.name.localized(lang)) else task.name.localized(lang),
                color = Theme.Text, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(3.dp))
            when (phase) {
                CooldownStore.BattlePhase.RUNNING ->
                    ChronoChip("⏳", "", fmtRemain(remain), Theme.Accent, urgent = false)
                CooldownStore.BattlePhase.READY ->
                    Text(trc(L.CdDoNow), color = Theme.Good, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                CooldownStore.BattlePhase.IDLE ->
                    Text(trc(L.CdTapToStart) + " · " + fmtHoursLabel(task.hours),
                        color = Theme.TextDim, fontSize = 10.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Spacer(Modifier.width(4.dp))
        if (phase == CooldownStore.BattlePhase.RUNNING) {
            ResetPill { store.clearBattle(char, task) }
        } else {
            Text("▶", color = if (ready) Theme.Good else Theme.Good.copy(alpha = 0.85f),
                fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
    }
}

// ---------------- Berries ----------------

@Composable
private fun BerriesSection(store: CooldownStore, char: GameCharacter, now: Long, onAddBerry: () -> Unit) {
    val list = store.shownBerries
    GroupBox {
        list.forEachIndexed { i, berry ->
            if (i > 0) RowLine()
            BerryRow(store, char, berry, now)
        }
    }
    Spacer(Modifier.height(8.dp))
    Row(
        Modifier.clickable { onAddBerry() }.padding(vertical = 4.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("＋ " + trc(L.CdAddBerry), color = Theme.Accent, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
    }
}

@Composable
private fun BerryRow(store: CooldownStore, char: GameCharacter, berry: BerryDef, now: Long) {
    val lang = LocalLang.current
    val st = store.berryStatus(char, berry, now = now)
    val bg = when (st.phase) {
        CooldownStore.BerryPhase.READY -> Theme.GoodSoft
        CooldownStore.BerryPhase.WILTED -> Theme.WarningSoft
        else -> Color.Transparent
    }
    Row(
        Modifier.fillMaxWidth().background(bg).padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(Modifier.alpha(if (st.phase == CooldownStore.BerryPhase.EMPTY) 0.55f else 1f)) {
            BerryIcon(berry.id, 30.dp)
        }
        Spacer(Modifier.width(11.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(berry.name.localized(lang), color = Theme.Text, fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Spacer(Modifier.width(6.dp))
                BerryActions(store, char, berry, st)
            }
            Spacer(Modifier.height(5.dp))
            BerryLines(store, berry, st)
        }
    }
}

@Composable
private fun BerryLines(store: CooldownStore, berry: BerryDef, st: CooldownStore.BerryStatus) {
    when (st.phase) {
        CooldownStore.BerryPhase.EMPTY -> {
            val tier = store.catalog.tier(berry.tier)
            if (tier != null) {
                Text("⏱ " + fmtHoursLabel(tier.growthHours) + " · 💧 ${tier.waterWindowsHours.size}×",
                    color = Theme.TextDim, fontSize = 10.sp)
            } else {
                Text(trc(L.CdEmpty), color = Theme.TextDim, fontSize = 11.sp)
            }
        }
        CooldownStore.BerryPhase.GROWING -> {
            ChronoChip("🌿", trc(L.CdHarvestShort), fmtRemain(st.harvestRemainMs), Theme.Good, urgent = false)
            Spacer(Modifier.height(3.dp))
            val prog = " (${st.waterings}/${st.totalWaters})"
            when {
                st.waterPending ->
                    ChronoChip("💧", "", trc(L.CdWaterNow).uppercase() + prog, Theme.Choice, urgent = true)
                st.nextWaterRemainMs != null ->
                    ChronoChip("💧", trc(L.CdNextWater),
                        fmtRemain(maxOf(0L, st.nextWaterRemainMs)) + prog, Theme.Choice, urgent = false)
                st.totalWaters > 0 ->
                    ChronoChip("💧", trc(L.CdNextWater), trc(L.CdAllWatered) + " ✓", Theme.TextDim, urgent = false)
            }
        }
        CooldownStore.BerryPhase.READY ->
            ChronoChip("✅", trc(L.CdHarvestShort), trc(L.CdReadyLabel).uppercase(), Theme.Good, urgent = true)
        CooldownStore.BerryPhase.WILTED ->
            ChronoChip("⚠️", trc(L.CdHarvestShort), trc(L.CdWilted).uppercase(), Theme.Warning, urgent = true)
    }
}

@Composable
private fun BerryActions(store: CooldownStore, char: GameCharacter, berry: BerryDef, st: CooldownStore.BerryStatus) {
    when (st.phase) {
        CooldownStore.BerryPhase.EMPTY -> Row(verticalAlignment = Alignment.CenterVertically) {
            Pill(trc(L.CdPlant), Theme.Good) { store.plantBerry(char, berry) }
            Spacer(Modifier.width(6.dp))
            IconMini("🗑") { store.removeBerry(berry.id) }
        }
        CooldownStore.BerryPhase.GROWING -> Row(verticalAlignment = Alignment.CenterVertically) {
            if (st.waterPending) { Pill(trc(L.CdWatered), Theme.Choice) { store.waterBerry(char, berry) }; Spacer(Modifier.width(6.dp)) }
            ResetPill { store.harvestBerry(char, berry) }
        }
        CooldownStore.BerryPhase.READY, CooldownStore.BerryPhase.WILTED ->
            Pill(trc(L.CdHarvest), Theme.Good) { store.harvestBerry(char, berry) }
    }
}

// ---------------- Seletor de berry (biblioteca) ----------------

@Composable
private fun BerryPicker(store: CooldownStore, onClose: () -> Unit) {
    val lang = LocalLang.current
    Column(Modifier.fillMaxSize().background(Theme.Bg)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("‹ " + trc(L.Back), color = Theme.Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                modifier = Modifier.clickable { onClose() })
            Spacer(Modifier.weight(1f))
            Text(trc(L.CdAddBerry).uppercase(), color = Theme.Text, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.width(40.dp))
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Theme.Border))
        val shownIds = store.shownBerries.map { it.id }.toSet()
        val available = store.catalog.berries.filter { it.id !in shownIds }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(12.dp)) {
            store.catalog.berryTiers.forEach { tier ->
                val group = available.filter { it.tier == tier.tier }
                if (group.isNotEmpty()) {
                    Text(String.format(trc(L.CdTierLabel), tier.growthHours.toInt()),
                        color = Theme.Accent, fontWeight = FontWeight.Bold, fontSize = 9.sp,
                        modifier = Modifier.padding(top = 8.dp, start = 4.dp, bottom = 2.dp))
                    GroupBox {
                        group.forEachIndexed { i, berry ->
                            if (i > 0) RowLine()
                            Row(
                                Modifier.fillMaxWidth().clickable { store.addBerry(berry.id); onClose() }
                                    .padding(horizontal = 12.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                BerryIcon(berry.id, 24.dp)
                                Spacer(Modifier.width(10.dp))
                                Text(berry.name.localized(lang), color = Theme.Text, fontSize = 13.sp,
                                    modifier = Modifier.weight(1f))
                                Text("＋", color = Theme.Accent, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }
    }
}

// ---------------- Componentes locais ----------------

@Composable
private fun SectionLabel(text: String) {
    Text(text.uppercase(), color = Theme.Text, fontWeight = FontWeight.Black, fontSize = 12.sp)
}

@Composable
private fun GroupBox(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Theme.Panel)
            .border(1.dp, Theme.Border, RoundedCornerShape(12.dp)),
        content = content
    )
}

@Composable
private fun RowLine() {
    Box(Modifier.fillMaxWidth().padding(start = 48.dp).height(1.dp).background(Theme.Line))
}

@Composable
private fun TabButton(title: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(9.dp))
            .background(if (selected) Theme.Accent else Theme.Panel)
            .clickable { onClick() }.padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(title, color = if (selected) Color.Black else Theme.TextDim,
            fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
    }
}

@Composable
private fun IconMini(glyph: String, onClick: () -> Unit) {
    Box(
        Modifier.size(26.dp).clickable { onClick() }, contentAlignment = Alignment.Center
    ) { Text(glyph, color = Theme.TextDim, fontSize = 13.sp) }
}

@Composable
private fun Pill(title: String, bg: Color, onClick: () -> Unit) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).background(bg).clickable { onClick() }
            .padding(horizontal = 11.dp, vertical = 5.dp)
    ) { Text(title, color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 11.sp) }
}

/** Reset claro (↺ + "Resetar"), contornado em vermelho. */
@Composable
private fun ResetPill(onClick: () -> Unit) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).border(1.dp, Theme.Danger.copy(alpha = 0.55f), RoundedCornerShape(50))
            .clickable { onClick() }.padding(horizontal = 9.dp, vertical = 5.dp)
    ) { Text("↺ " + trc(L.CdReset), color = Theme.Danger, fontWeight = FontWeight.SemiBold, fontSize = 11.sp) }
}

/** Cronômetro: ícone + rótulo pequeno (opcional) + TEMPO em destaque. `urgent` = fundo colorido. */
@Composable
private fun ChronoChip(glyph: String, label: String, time: String, color: Color, urgent: Boolean) {
    Row(
        Modifier.clip(RoundedCornerShape(7.dp))
            .background(if (urgent) color.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.04f))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(glyph, fontSize = 10.sp)
        if (label.isNotEmpty()) {
            Spacer(Modifier.width(5.dp))
            Text(label.uppercase(), color = Theme.TextDim, fontWeight = FontWeight.Bold, fontSize = 8.sp)
        }
        Spacer(Modifier.width(5.dp))
        Text(time, color = color, fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 1)
    }
}

// ---------------- Ícones do sistema de cooldown ----------------

/**
 * Ícone de uma tarefa de batalha, resolvido pela spec do catálogo:
 * "region:x" (mapa) · "trainer:x" (retrato) · "item:x" · "sprite:x" (Pokémon) · "sf:símbolo".
 * Sem spec (ou desconhecida / SF Symbol) cai no ponto colorido da tarefa.
 */
@Composable
private fun CdTaskIcon(spec: String?, colorHex: String, size: Dp) {
    val sep = spec?.indexOf(':') ?: -1
    if (spec != null && sep > 0) {
        val kind = spec.substring(0, sep)
        val name = spec.substring(sep + 1)
        when (kind) {
            "region" -> { AssetImage("regions", name, Modifier.size(size)); return }
            "trainer" -> { AssetImage("trainers", name, Modifier.size(size)); return }
            "item" -> { AssetImage("items", name, Modifier.size(size)); return }
            "sprite" -> { AssetImage("sprites", name, Modifier.size(size)); return }
            else -> {} // "sf" e desconhecidos -> ponto colorido
        }
    }
    ColorDot(Theme.fromHex(colorHex), size)
}

@Composable
private fun ColorDot(color: Color, size: Dp) {
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Box(Modifier.size(size).clip(CircleShape).background(color.copy(alpha = 0.18f)))
        Box(Modifier.size(size * 0.42f).clip(CircleShape).background(color))
    }
}

/** Sprite de uma berry (assets/data/sprites/berries/<nome>.png), pelo id "berry_<nome>". */
@Composable
private fun BerryIcon(berryId: String, size: Dp) {
    val ctx = LocalContext.current
    val name = if (berryId.startsWith("berry_")) berryId.removePrefix("berry_") else berryId
    val img = remember(name) { loadAsset(ctx, "sprites/berries", name) }
    if (img != null) {
        Image(bitmap = img, contentDescription = null, modifier = Modifier.size(size), contentScale = ContentScale.Fit)
    } else {
        Box(Modifier.size(size), contentAlignment = Alignment.Center) { Text("🌿", fontSize = (size.value * 0.6).sp) }
    }
}

/** Ícone do boneco: a foto (PNG base64) recortada em círculo, ou o monograma (1ª letra). */
@Composable
private fun CharAvatar(name: String, avatarBase64: String?, size: Dp) {
    val img: ImageBitmap? = remember(avatarBase64) {
        avatarBase64?.takeIf { it.isNotEmpty() }?.let {
            try {
                val bytes = Base64.decode(it, Base64.DEFAULT)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
            } catch (e: Exception) { null }
        }
    }
    Box(
        Modifier.size(size).clip(CircleShape).background(Theme.AccentSoft)
            .border(1.dp, Theme.Border, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        if (img != null) {
            Image(bitmap = img, contentDescription = null,
                modifier = Modifier.size(size).clip(CircleShape), contentScale = ContentScale.Crop)
        } else {
            Text(name.take(1).uppercase(), color = Theme.Accent, fontWeight = FontWeight.Bold,
                fontSize = (size.value * 0.42).sp)
        }
    }
}

/** Recorta a imagem no centro (quadrado), reduz p/ `side`×`side` px e devolve PNG base64. */
private fun squareIconBase64(ctx: Context, uri: Uri, side: Int): String? = try {
    val src = ctx.contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
    if (src == null) null else {
        val s = minOf(src.width, src.height)
        val cropped = Bitmap.createBitmap(src, (src.width - s) / 2, (src.height - s) / 2, s, s)
        val scaled = Bitmap.createScaledBitmap(cropped, side, side, true)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
        Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }
} catch (e: Exception) { null }
