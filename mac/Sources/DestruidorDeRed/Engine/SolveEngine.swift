import Foundation
import Combine

/// Máquina de estado que percorre a árvore de um `Solve`.
///
/// Estado = nó atual + índice do passo revelado dentro do nó. Mantém uma pilha de histórico
/// para o botão "Voltar". `nil` em `currentNodeId` significa a tela inicial (escolha de entrada).
@MainActor
final class SolveEngine: ObservableObject {
    let solve: Solve

    @Published private(set) var currentNodeId: String?
    @Published private(set) var stepIndex: Int = 0

    /// Grupo (região/Elite) cuja lista de entradas está aberta na tela inicial. `nil` = lista de grupos.
    /// Em modos com `groups`, a HomeView observa isto para abrir direto a lista certa.
    @Published var selectedGroupName: String?

    /// Grupo (Elite/região) da luta em andamento — para encadear o "Próximo treinador".
    @Published private(set) var currentGroupName: String?

    /// Retrato/nome padrão do modo (fallback quando a entrada/grupo não tem treinador — ex.: Red).
    var defaultPortrait: String?
    var defaultTrainerName: String?

    /// Índice reverso nó → treinador da entrada (só entradas COM retrato, ex.: líderes do farm).
    /// Faz a foto do topo atualizar sozinha a cada ginásio da rota de farm.
    private lazy var trainerByNode: [String: (portrait: String, label: String)] = {
        var map: [String: (String, String)] = [:]
        let all = (solve.groups?.flatMap { $0.entries } ?? []) + (solve.entryPoints ?? [])
        for e in all { if let p = e.portrait { map[e.nodeId] = (p, e.label) } }
        return map
    }()

    private var currentGroup: EntryGroup? {
        guard let n = currentGroupName, let groups = solve.groups else { return nil }
        return groups.first { $0.name == n }
    }

    /// Foto (Resources/trainers) de quem o jogador está enfrentando AGORA.
    /// Prioridade: treinador do próprio nó (ginásio do farm) → grupo (Elite 4) → padrão (Red).
    var topPortrait: String? {
        if let id = currentNodeId, let hit = trainerByNode[id] { return hit.portrait }
        if let p = currentGroup?.portrait { return p }
        return defaultPortrait
    }
    /// Nome de quem está enfrentando agora (ex.: "Flannery", "Lorelei", "Red").
    var topName: String? {
        if let id = currentNodeId, let hit = trainerByNode[id] { return hit.label }
        if let g = currentGroup { return g.name }
        return defaultTrainerName
    }

    /// Trilha do caminho percorrido: lead escolhido + cada escolha feita (para o feedback
    /// saber o caminho EXATO que deu problema). Ex.: ["Articuno", "Lucario", "Earthquake"].
    @Published private(set) var pathTrail: [String] = []

    /// Snapshots (nó, passo, trilha) para o "Voltar".
    private var history: [Snapshot] = []
    private struct Snapshot { let nodeId: String?; let stepIndex: Int; let trail: [String] }

    /// Consultado no fluxo linear: se retornar true para o nó, ele é pulado automaticamente
    /// (cidade marcada como "pular"). Não se aplica a saltos explícitos (jumpTo/choose).
    var shouldAutoSkip: ((String) -> Bool)?

    init(solve: Solve) {
        self.solve = solve
        self.currentNodeId = nil
    }

    // MARK: - Consultas

    var isHome: Bool { currentNodeId == nil }
    var currentNode: Node? { currentNodeId.flatMap { solve.nodes[$0] } }

    /// nodeIds dos ginásios da SEQUÊNCIA (alvos de `skipTo`). Só nesses o `setup` de entrada é
    /// escondido — ele aparece no FIM do ginásio ativo anterior (via `upcomingSetupSteps`). Sub-nós
    /// de opção com `gymLead` (ex.: Driftveil, com aviso de PP) NÃO são alvo de skipTo → mantêm o setup.
    private lazy var gymSequenceIds: Set<String> = Set(solve.nodes.values.compactMap { $0.skipTo })
    var hidesEntrySetup: Bool { currentNodeId.map { gymSequenceIds.contains($0) } ?? false }
    var canBack: Bool { !history.isEmpty }
    /// Há uma "próxima parada" para a qual se pode pular (pular ginásio/cidade).
    var canSkip: Bool { currentNode?.skipTo != nil }

    /// Passos já revelados (do início até o índice atual).
    var revealedSteps: [Step] {
        guard let node = currentNode, !node.steps.isEmpty else { return [] }
        let upper = min(stepIndex, node.steps.count - 1)
        guard upper >= 0 else { return [] }
        return Array(node.steps[0...upper])
    }

    /// Verdadeiro quando ainda há passos a revelar neste nó.
    var canAdvanceStep: Bool {
        guard let node = currentNode else { return false }
        return stepIndex < node.steps.count - 1
    }

    /// Verdadeiro quando estamos no último passo (ou o nó não tem passos).
    var atLastStep: Bool {
        guard let node = currentNode else { return false }
        return stepIndex >= node.steps.count - 1
    }

    /// A ramificação a oferecer agora (só quando chegamos ao fim dos passos).
    var pendingBranch: Branch? {
        guard atLastStep else { return nil }
        return currentNode?.branch
    }

    /// O botão "Próximo" deve aparecer? (há mais passos, ou um salto automático a seguir).
    var showNextButton: Bool {
        canAdvanceStep || (pendingBranch?.kind == .goto)
    }

    /// Lead do PRÓXIMO ginásio da rota, já pulando os marcados como "pular".
    /// Usado no rodapé "Próximo ginásio" para preparar a troca de Pokémon/itens certa.
    var upcomingGymLead: [GymLead]? {
        guard let node = currentNode else { return nil }
        var targetId: String?
        if let b = node.branch, b.kind == .goto { targetId = b.nodeId } else { targetId = node.skipTo }
        guard var tid = targetId else { return nil }
        var guardCount = 0
        while shouldAutoSkip?(tid) == true, let nxt = solve.nodes[tid]?.skipTo, guardCount < 40 {
            tid = nxt; guardCount += 1
        }
        return solve.nodes[tid]?.gymLead
    }

    /// Nó do próximo ginásio (pulando os ignorados) — para o título no rodapé.
    var upcomingGymTitle: String? {
        guard let node = currentNode else { return nil }
        var targetId: String?
        if let b = node.branch, b.kind == .goto { targetId = b.nodeId } else { targetId = node.skipTo }
        guard var tid = targetId else { return nil }
        var guardCount = 0
        while shouldAutoSkip?(tid) == true, let nxt = solve.nodes[tid]?.skipTo, guardCount < 40 {
            tid = nxt; guardCount += 1
        }
        return solve.nodes[tid]?.title
    }

    /// Passos "PÓS-LUTA" (`setup`) do PRÓXIMO ginásio ATIVO, para mostrar no FIM do ginásio atual.
    /// Assim a instrução de entrada ("cure + troque o item") aparece na luta ativa ANTERIOR, já
    /// pulando os ginásios desativados. Só quando o nó atual encaminha pro próximo (branch = goto).
    var upcomingSetupSteps: [Step] {
        guard currentNode?.branch?.kind == .goto, let node = currentNode else { return [] }
        guard var tid = node.branch?.nodeId ?? node.skipTo else { return [] }
        var guardCount = 0
        while shouldAutoSkip?(tid) == true, let nxt = solve.nodes[tid]?.skipTo, guardCount < 40 {
            tid = nxt; guardCount += 1
        }
        return (solve.nodes[tid]?.steps ?? []).filter { $0.kind == .setup }
    }

    /// Estamos num nó terminal (fim do solve)?
    var isTerminal: Bool {
        atLastStep && currentNode?.branch == nil
    }

    /// Conjuntos de números de time ("Oponente está usando o time N, …") encontrados nos nós
    /// VISITADOS no caminho atual (lead → nó atual). Cada conjunto estreita os times possíveis.
    func lineNumberSetsAlongPath() -> [Set<Int>] {
        var ids: [String] = history.compactMap { $0.nodeId }
        if let cur = currentNodeId { ids.append(cur) }
        var out: [Set<Int>] = []
        for id in ids {
            guard let node = solve.nodes[id] else { continue }
            for step in node.steps where step.kind == .setup {
                guard let text = step.text, text.contains("usando o time") else { continue }
                let nums = Set(text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) })
                if !nums.isEmpty { out.append(nums) }
            }
        }
        return out
    }

    // MARK: - Ações

    func jumpTo(_ entry: EntryPoint, group: EntryGroup? = nil) {
        currentGroupName = group?.name
        push()
        pathTrail = [entry.label]
        goto(entry.nodeId, autoSkip: false)
    }

    // MARK: - Grupos sequenciais (Elite 4: elite 1 → … → campeão)

    /// Índice do grupo atual dentro de `solve.groups`.
    private var currentGroupIndex: Int? {
        guard let name = currentGroupName, let groups = solve.groups else { return nil }
        return groups.firstIndex { $0.name == name }
    }

    /// Próximo treinador da sequência (Elite 4). `nil` se for o último (campeão) ou modo não sequencial.
    var nextGroup: EntryGroup? {
        guard solve.sequentialGroups == true, let groups = solve.groups,
              let i = currentGroupIndex, i + 1 < groups.count else { return nil }
        return groups[i + 1]
    }

    /// Estamos terminando a luta do campeão (último da sequência da Elite 4)?
    var isChampionTerminal: Bool {
        guard solve.sequentialGroups == true, let groups = solve.groups,
              let i = currentGroupIndex else { return false }
        return i == groups.count - 1
    }

    /// Avança para a seleção de leads do PRÓXIMO treinador da sequência (Elite 4).
    func advanceToNextGroup() {
        guard let nxt = nextGroup else { return }
        history.removeAll()
        currentNodeId = nil
        stepIndex = 0
        currentGroupName = nil
        pathTrail = []
        selectedGroupName = nxt.name
    }

    /// Fim do campeão (Liga concluída): volta pra SELEÇÃO dos treinadores da Elite 4 (o group
    /// picker), em vez de sair pro menu. Assim dá pra escolher outra luta e seguir o farm.
    func restartSequence() {
        guard solve.sequentialGroups == true else { return }
        history.removeAll()
        currentNodeId = nil
        stepIndex = 0
        currentGroupName = nil
        pathTrail = []
        selectedGroupName = nil
    }

    func choose(_ option: Option) {
        push()
        pathTrail.append(option.label)
        goto(option.nodeId, autoSkip: false)
    }

    /// Pula esta parada e vai direto para a próxima (cidade/ginásio seguinte).
    func skip() {
        guard let target = currentNode?.skipTo else { return }
        push()
        goto(target)
    }

    func next() {
        guard let node = currentNode else { return }
        if stepIndex < node.steps.count - 1 {
            push()
            stepIndex += 1
        } else if let branch = node.branch, branch.kind == .goto, let target = branch.nodeId {
            push()
            goto(target)
        }
    }

    func back() {
        guard let prev = history.popLast() else { return }
        currentNodeId = prev.nodeId
        stepIndex = prev.stepIndex
        pathTrail = prev.trail
    }

    func reset() {
        history.removeAll()
        currentNodeId = nil
        stepIndex = 0
        currentGroupName = nil
        pathTrail = []
        // Volta para a seleção de treinadores/grupos (não para a lista de leads).
        selectedGroupName = nil
    }

    // MARK: - Internos

    private func push() {
        history.append(Snapshot(nodeId: currentNodeId, stepIndex: stepIndex, trail: pathTrail))
    }

    private func goto(_ id: String, autoSkip: Bool = true) {
        currentNodeId = id
        stepIndex = 0

        // Modo "revela tudo": mostra todos os passos do nó de uma vez.
        if solve.revealAll == true, let node = currentNode, !node.steps.isEmpty {
            stepIndex = node.steps.count - 1
        }

        // Cidade marcada como "pular": no fluxo linear, salta direto para a próxima.
        if autoSkip, let node = currentNode, let target = node.skipTo,
           shouldAutoSkip?(id) == true {
            goto(target, autoSkip: true)
            return
        }

        // Nó "ponte": sem passos e com salto direto -> segue em frente automaticamente.
        if let node = currentNode, node.steps.isEmpty,
           let branch = node.branch, branch.kind == .goto, let target = branch.nodeId,
           target != id {
            goto(target, autoSkip: autoSkip)
        }
    }
}
