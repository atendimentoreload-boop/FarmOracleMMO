package com.reload.prestreloajuda.model

import kotlinx.serialization.Serializable

// Modelo data-driven, espelho do Swift/C#. Uma "luta" (Solve) é um conjunto de nós
// (Node) com passos lineares e uma ramificação final opcional (escolha ou salto).

@Serializable
data class Solve(
    val id: String,
    val title: String = "",
    val lead: String? = null,
    val homePrompt: String? = null,
    val groupPrompt: String? = null,
    val allowSkip: Boolean? = null,
    val revealAll: Boolean? = null,
    /** Aviso destacado (âmbar) na tela inicial do modo (ex.: 5ª vitória na Elite 4). */
    val warning: String? = null,
    /** Grupos feitos em ordem (Elite 4): habilita "Próximo treinador" e "Reiniciar" no campeão. */
    val sequentialGroups: Boolean? = null,
    val legend: List<LegendEntry>? = null,
    val pokepaste: String? = null,
    /** Link do documento oficial (Google Docs) da estratégia, se houver. */
    val doc: String? = null,
    val entryPoints: List<EntryPoint>? = null,
    val groups: List<EntryGroup>? = null,
    val palette: List<PaletteEntry>? = null,
    val nodes: Map<String, Node> = emptyMap(),
)

@Serializable
data class PaletteEntry(
    val name: String,
    val color: String,
    val moves: List<String> = emptyList(),
)

@Serializable
data class EntryGroup(
    val name: String,
    val entries: List<EntryPoint> = emptyList(),
    val portrait: String? = null,
)

@Serializable
data class LegendEntry(
    val term: String,
    val meaning: String,
)

@Serializable
data class EntryPoint(
    val label: String,
    val nodeId: String,
    val portrait: String? = null,
)

@Serializable
data class Node(
    val id: String = "",
    val title: String? = null,
    val steps: List<Step> = emptyList(),
    val branch: Branch? = null,
    val skipTo: String? = null,
    val leadHint: String? = null,
    val gymLead: List<GymLead>? = null,
)

@Serializable
data class GymLead(
    val pokemon: String,
    val item: String? = null,
)

@Serializable
data class Step(
    val id: String = "",
    val kind: String = "action", // action | note | setup | conditional
    val text: String? = null,
    val table: ConditionalTable? = null,
)

@Serializable
data class ConditionalTable(
    val title: String? = null,
    val rows: List<ConditionalRow> = emptyList(),
)

@Serializable
data class ConditionalRow(
    val move: String,
    val targets: List<String> = emptyList(),
)

@Serializable
data class Branch(
    val kind: String = "choice", // choice | goto
    val prompt: String? = null,
    val options: List<Option>? = null,
    val nodeId: String? = null,
)

@Serializable
data class Option(
    val label: String,
    val nodeId: String,
)
