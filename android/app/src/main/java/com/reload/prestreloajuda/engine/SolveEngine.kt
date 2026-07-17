package com.reload.prestreloajuda.engine

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.reload.prestreloajuda.model.EntryGroup
import com.reload.prestreloajuda.model.GymLead
import com.reload.prestreloajuda.model.Node
import com.reload.prestreloajuda.model.Option
import com.reload.prestreloajuda.model.Solve
import com.reload.prestreloajuda.model.Step

/**
 * Máquina de estados do roteiro — espelho do SolveEngine do Swift/C#.
 * `currentNodeId == null` significa "na tela inicial" (escolha de entrada).
 */
class SolveEngine(val solve: Solve) {

    var currentNodeId by mutableStateOf<String?>(null)
        private set
    var stepIndex by mutableStateOf(0)
        private set

    /** Trilha do caminho: lead + cada escolha feita (para o feedback saber o caminho EXATO). */
    var pathTrail by mutableStateOf<List<String>>(emptyList())
        private set

    /** Grupo (região/Elite) cuja lista de leads está aberta na home. null = lista de grupos. */
    var selectedGroupName by mutableStateOf<String?>(null)

    /** Grupo da luta em andamento (Elite 4) — encadeia o "Próximo treinador". */
    var currentGroupName by mutableStateOf<String?>(null)
        private set

    /** Retrato/nome padrão do modo (fallback quando entrada/grupo não tem treinador — ex.: Red). */
    var defaultPortrait: String? = null
    var defaultTrainerName: String? = null

    /** Consultado no fluxo linear: se true, o nó é pulado automaticamente (parada "pular"). */
    var shouldAutoSkip: ((String) -> Boolean)? = null

    // Pilha de histórico para "Voltar": (nodeId, stepIndex, trilha).
    private data class Hist(val nodeId: String, val stepIndex: Int, val trail: List<String>)
    private val history = ArrayDeque<Hist>()

    val currentNode: Node?
        get() = currentNodeId?.let { solve.nodes[it] }

    val canGoBack: Boolean
        get() = currentNodeId != null

    // Índice reverso nó → treinador da entrada (só entradas COM retrato: líderes do farm).
    private val trainerByNode: Map<String, Pair<String, String>> by lazy {
        val all = (solve.groups?.flatMap { it.entries } ?: emptyList()) + (solve.entryPoints ?: emptyList())
        all.mapNotNull { e -> e.portrait?.let { e.nodeId to (it to e.label) } }.toMap()
    }

    private val currentGroup: EntryGroup?
        get() = currentGroupName?.let { n -> solve.groups?.firstOrNull { it.name == n } }

    /** Foto de quem o jogador enfrenta agora: nó (ginásio do farm) → grupo (Elite 4) → padrão (Red). */
    val topPortrait: String?
        get() = currentNodeId?.let { trainerByNode[it]?.first } ?: currentGroup?.portrait ?: defaultPortrait

    val topName: String?
        get() = currentNodeId?.let { trainerByNode[it]?.second } ?: currentGroup?.name ?: defaultTrainerName

    /** Próximo treinador da sequência (Elite 4); null se for o último (campeão) ou modo não sequencial. */
    val nextGroup: EntryGroup?
        get() {
            if (solve.sequentialGroups != true) return null
            val groups = solve.groups ?: return null
            val i = groups.indexOfFirst { it.name == currentGroupName }
            return if (i >= 0 && i + 1 < groups.size) groups[i + 1] else null
        }

    /** Estamos terminando a luta do campeão (último da sequência)? */
    val isChampionTerminal: Boolean
        get() {
            if (solve.sequentialGroups != true) return false
            val groups = solve.groups ?: return false
            val i = groups.indexOfFirst { it.name == currentGroupName }
            return i >= 0 && i == groups.size - 1
        }

    /** Estamos num nó terminal (fim da luta: sem próximo passo e sem ramificação)? */
    val isTerminal: Boolean
        get() {
            val node = currentNode ?: return false
            val atEnd = solve.revealAll == true || node.steps.isEmpty() || stepIndex >= node.steps.lastIndex
            return atEnd && node.branch == null
        }

    /**
     * Conjuntos de números de time ("Oponente está usando o time N, …") nos nós VISITADOS
     * no caminho atual (lead → nó atual). Cada conjunto estreita os times possíveis.
     * Porte fiel do lineNumberSetsAlongPath() do Mac (usado pelo overlay "Ver times").
     */
    fun lineNumberSetsAlongPath(): List<Set<Int>> {
        val ids = history.map { it.nodeId }.toMutableList()  // ArrayDeque itera lead → atual
        currentNodeId?.let { ids.add(it) }
        val out = mutableListOf<Set<Int>>()
        for (id in ids) {
            val node = solve.nodes[id] ?: continue
            for (step in node.steps) {
                if (step.kind != "setup") continue
                val text = step.text ?: continue
                if (!text.contains("usando o time")) continue
                val nums = Regex("\\d+").findAll(text).map { it.value.toInt() }.toSet()
                if (nums.isNotEmpty()) out.add(nums)
            }
        }
        return out
    }

    /** Entra numa entrada da tela inicial. `label` = nome do lead, vira o início da trilha. */
    fun jumpTo(nodeId: String, label: String, groupName: String? = null) {
        history.clear()
        currentGroupName = groupName
        pathTrail = listOf(label)
        enter(nodeId, autoSkip = false)
    }

    /** Avança para a seleção de leads do PRÓXIMO treinador (Elite 4). */
    fun advanceToNextGroup() {
        val nxt = nextGroup ?: return
        history.clear()
        currentNodeId = null
        stepIndex = 0
        currentGroupName = null
        pathTrail = emptyList()
        selectedGroupName = nxt.name
    }

    /** Avança um passo dentro do nó atual (botão "Próximo"). */
    fun next() {
        val node = currentNode ?: return
        if (stepIndex < node.steps.lastIndex) stepIndex += 1
    }

    val hasNextStep: Boolean
        get() = currentNode?.let { stepIndex < it.steps.lastIndex } ?: false

    /** Escolhe uma opção da ramificação -> vai para o nó de destino. */
    fun choose(option: Option) {
        currentNodeId?.let { history.addLast(Hist(it, stepIndex, pathTrail)) }
        pathTrail = pathTrail + option.label
        enter(option.nodeId, autoSkip = false)
    }

    /** Segue um goto ("Continuar"). Não é escolha do usuário, então não entra na trilha. */
    fun follow(nodeId: String) {
        currentNodeId?.let { history.addLast(Hist(it, stepIndex, pathTrail)) }
        enter(nodeId, autoSkip = true)
    }

    /** Volta um passo no histórico; se vazio, volta à tela inicial. */
    fun back() {
        if (history.isNotEmpty()) {
            val (nodeId, idx, trail) = history.removeLast()
            currentNodeId = nodeId
            stepIndex = idx
            pathTrail = trail
        } else {
            currentNodeId = null
            stepIndex = 0
            pathTrail = emptyList()
        }
    }

    /** Reinicia: volta para a seleção de treinadores/grupos (não para a lista de leads). */
    fun reset() {
        history.clear()
        currentNodeId = null
        stepIndex = 0
        currentGroupName = null
        pathTrail = emptyList()
        selectedGroupName = null
    }

    /** Há uma "próxima parada" para a qual se pode pular (rota de farm). */
    val canSkip: Boolean
        get() = currentNode?.skipTo != null

    /** Pula esta parada e vai direto para a próxima (cidade/ginásio seguinte). */
    fun skip() {
        val target = currentNode?.skipTo ?: return
        currentNodeId?.let { history.addLast(Hist(it, stepIndex, pathTrail)) }
        enter(target, autoSkip = true)
    }

    /** Nó do próximo ginásio (pulando os marcados como "pular") — para o lead/título no rodapé. */
    private fun resolveUpcoming(): Node? {
        val node = currentNode ?: return null
        val b = node.branch
        var tid = (if (b?.kind == "goto") b.nodeId else node.skipTo) ?: return null
        var guard = 0
        while (shouldAutoSkip?.invoke(tid) == true && guard < 40) {
            val nxt = solve.nodes[tid]?.skipTo ?: break
            tid = nxt; guard++
        }
        return solve.nodes[tid]
    }

    val upcomingGymLead: List<GymLead>?
        get() = resolveUpcoming()?.gymLead

    val upcomingGymTitle: String?
        get() = resolveUpcoming()?.title

    /** Passos "PÓS-LUTA" (setup) do PRÓXIMO ginásio ativo, mostrados no FIM do atual (branch=goto). */
    val upcomingSetupSteps: List<Step>
        get() = if (currentNode?.branch?.kind == "goto")
            resolveUpcoming()?.steps?.filter { it.kind == "setup" } ?: emptyList()
        else emptyList()

    /** nodeIds dos ginásios da sequência (alvos de skipTo). Só nesses o setup de entrada é escondido. */
    private val gymSequenceIds: Set<String> by lazy { solve.nodes.values.mapNotNull { it.skipTo }.toSet() }
    val hidesEntrySetup: Boolean
        get() = currentNodeId?.let { gymSequenceIds.contains(it) } ?: false

    /**
     * Entra num nó. Porte fiel do goto() do Mac/Windows:
     * - revealAll: mostra todos os passos de uma vez;
     * - autoSkip: parada marcada como "pular" salta direto pra próxima;
     * - nó "ponte" (sem passos + goto direto): segue em frente sozinho.
     */
    private fun enter(nodeId: String, autoSkip: Boolean) {
        currentNodeId = nodeId
        stepIndex = 0
        val node = solve.nodes[nodeId]

        if (solve.revealAll == true && node != null && node.steps.isNotEmpty()) {
            stepIndex = node.steps.lastIndex
        }

        if (autoSkip && node?.skipTo != null && shouldAutoSkip?.invoke(nodeId) == true) {
            enter(node.skipTo, autoSkip = true)
            return
        }

        if (node != null && node.steps.isEmpty()) {
            val b = node.branch
            if (b != null && b.kind == "goto" && b.nodeId != null && b.nodeId != nodeId) {
                enter(b.nodeId, autoSkip)
            }
        }
    }
}
