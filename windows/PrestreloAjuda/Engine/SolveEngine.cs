using PrestreloAjuda.Models;

namespace PrestreloAjuda.Engine;

/// Máquina de estado que percorre a árvore de um Solve (porte fiel do SolveEngine.swift).
/// Estado = nó atual + índice do passo revelado. Mantém pilha de histórico para "Voltar".
/// currentNodeId == null significa a tela inicial.
public sealed class SolveEngine
{
    public Solve Solve { get; }

    private string? _currentNodeId;
    private int _stepIndex;
    private readonly Stack<(string? nodeId, int stepIndex, List<string> trail)> _history = new();

    /// Trilha do caminho: lead + cada escolha feita (para o feedback saber o caminho EXATO).
    public List<string> PathTrail { get; private set; } = new();

    /// Consultado no fluxo linear: se true, o nó é pulado automaticamente (cidade "pular").
    public Func<string, bool>? ShouldAutoSkip { get; set; }

    /// Grupo (Elite/região) da luta em andamento — encadeia o "Próximo treinador".
    public string? CurrentGroupName { get; private set; }
    /// Retrato/nome padrão do modo (fallback quando entrada/grupo não tem treinador — ex.: Red).
    public string? DefaultPortrait { get; set; }
    public string? DefaultTrainerName { get; set; }

    public string? CurrentNodeId => _currentNodeId;

    // Índice reverso nó → treinador da entrada (só entradas COM retrato: líderes do farm).
    private Dictionary<string, (string portrait, string label)>? _trainerByNode;
    private Dictionary<string, (string portrait, string label)> TrainerByNode
    {
        get
        {
            if (_trainerByNode != null) return _trainerByNode;
            _trainerByNode = new();
            var all = (Solve.Groups?.SelectMany(g => g.Entries) ?? Enumerable.Empty<EntryPoint>())
                .Concat(Solve.EntryPoints ?? new());
            foreach (var e in all)
                if (e.Portrait is string p) _trainerByNode[e.NodeId] = (p, e.Label);
            return _trainerByNode;
        }
    }

    private EntryGroup? CurrentGroup =>
        CurrentGroupName != null ? Solve.Groups?.FirstOrDefault(g => g.Name == CurrentGroupName) : null;

    /// Foto de quem o jogador enfrenta agora: nó (ginásio do farm) → grupo (Elite 4) → padrão (Red).
    public string? TopPortrait =>
        (_currentNodeId != null && TrainerByNode.TryGetValue(_currentNodeId, out var t)) ? t.portrait
        : CurrentGroup?.Portrait ?? DefaultPortrait;

    public string? TopName =>
        (_currentNodeId != null && TrainerByNode.TryGetValue(_currentNodeId, out var t)) ? t.label
        : CurrentGroup?.Name ?? DefaultTrainerName;

    /// Próximo treinador da sequência (Elite 4); null se for o último (campeão) ou modo não sequencial.
    public EntryGroup? NextGroup
    {
        get
        {
            if (Solve.SequentialGroups != true || Solve.Groups == null) return null;
            int i = Solve.Groups.FindIndex(g => g.Name == CurrentGroupName);
            return i >= 0 && i + 1 < Solve.Groups.Count ? Solve.Groups[i + 1] : null;
        }
    }

    /// Estamos terminando a luta do campeão (último da sequência)?
    public bool IsChampionTerminal
    {
        get
        {
            if (Solve.SequentialGroups != true || Solve.Groups == null) return false;
            int i = Solve.Groups.FindIndex(g => g.Name == CurrentGroupName);
            return i >= 0 && i == Solve.Groups.Count - 1;
        }
    }

    /// Disparado sempre que o estado muda (a janela re-renderiza ouvindo isto).
    public event Action? Changed;

    public SolveEngine(Solve solve)
    {
        Solve = solve;
        _currentNodeId = null;
    }

    private void Notify() => Changed?.Invoke();

    // MARK: - Consultas

    public bool IsHome => _currentNodeId == null;

    public Node? CurrentNode =>
        _currentNodeId != null && Solve.Nodes.TryGetValue(_currentNodeId, out var n) ? n : null;

    public bool CanBack => _history.Count > 0;

    public int StepIndex => _stepIndex;

    /// Há uma "próxima parada" para a qual se pode pular.
    public bool CanSkip => CurrentNode?.SkipTo != null;

    /// Passos já revelados (do início até o índice atual).
    public List<Step> RevealedSteps
    {
        get
        {
            var node = CurrentNode;
            if (node == null || node.Steps.Count == 0) return new();
            int upper = Math.Min(_stepIndex, node.Steps.Count - 1);
            if (upper < 0) return new();
            return node.Steps.GetRange(0, upper + 1);
        }
    }

    /// Ainda há passos a revelar neste nó.
    public bool CanAdvanceStep
    {
        get
        {
            var node = CurrentNode;
            return node != null && _stepIndex < node.Steps.Count - 1;
        }
    }

    /// Estamos no último passo (ou o nó não tem passos).
    public bool AtLastStep
    {
        get
        {
            var node = CurrentNode;
            return node != null && _stepIndex >= node.Steps.Count - 1;
        }
    }

    /// A ramificação a oferecer agora (só ao fim dos passos).
    public Branch? PendingBranch => AtLastStep ? CurrentNode?.Branch : null;

    /// O botão "Próximo" deve aparecer? (mais passos, ou salto automático a seguir).
    public bool ShowNextButton => CanAdvanceStep || PendingBranch?.Kind == BranchKind.Goto;

    /// Lead do PRÓXIMO ginásio (pulando os marcados como "pular").
    public List<GymLead>? UpcomingGymLead => ResolveUpcoming()?.GymLead;

    /// Título do próximo ginásio (pulando os ignorados).
    public string? UpcomingGymTitle => ResolveUpcoming()?.Title;

    private Node? ResolveUpcoming()
    {
        var node = CurrentNode;
        if (node == null) return null;
        string? targetId = node.Branch is { Kind: BranchKind.Goto } b ? b.NodeId : node.SkipTo;
        if (targetId == null) return null;
        string tid = targetId;
        int guard = 0;
        while (ShouldAutoSkip?.Invoke(tid) == true
               && Solve.Nodes.TryGetValue(tid, out var cur) && cur.SkipTo is string nxt
               && guard < 40)
        {
            tid = nxt; guard++;
        }
        return Solve.Nodes.TryGetValue(tid, out var node2) ? node2 : null;
    }

    /// Passos "PÓS-LUTA" (setup) do PRÓXIMO ginásio ativo, para mostrar no FIM do atual (branch=goto).
    /// Assim a instrução de entrada ("cure + troque o item") aparece na luta ativa ANTERIOR.
    public List<Step> UpcomingSetupSteps
    {
        get
        {
            if (CurrentNode?.Branch is not { Kind: BranchKind.Goto }) return new();
            return ResolveUpcoming()?.Steps.Where(s => s.Kind == StepKind.Setup).ToList() ?? new();
        }
    }

    /// nodeIds dos ginásios da SEQUÊNCIA (alvos de SkipTo). Só nesses o setup de entrada é escondido
    /// (aparece no fim do ginásio ativo anterior via UpcomingSetupSteps).
    private HashSet<string>? _gymSequenceIds;
    private HashSet<string> GymSequenceIds => _gymSequenceIds ??=
        Solve.Nodes.Values.Select(n => n.SkipTo).Where(s => s != null).Select(s => s!).ToHashSet();
    public bool HidesEntrySetup => CurrentNodeId is string id && GymSequenceIds.Contains(id);

    /// Nó terminal (fim do solve)?
    public bool IsTerminal => AtLastStep && CurrentNode?.Branch == null;

    /// Conjuntos de números de time ("Oponente está usando o time N, …") encontrados nos nós
    /// VISITADOS no caminho atual (lead → nó atual). Cada conjunto estreita os times possíveis.
    /// Porte fiel do lineNumberSetsAlongPath() do Mac.
    public List<HashSet<int>> LineNumberSetsAlongPath()
    {
        // _history é uma pilha (topo = mais recente); Reverse() dá ordem de visita (lead → atual).
        var ids = _history.Reverse().Select(h => h.nodeId).Where(x => x != null).Select(x => x!).ToList();
        if (_currentNodeId != null) ids.Add(_currentNodeId);

        var outSets = new List<HashSet<int>>();
        foreach (var id in ids)
        {
            if (!Solve.Nodes.TryGetValue(id, out var node)) continue;
            foreach (var step in node.Steps)
            {
                if (step.Kind != StepKind.Setup) continue;
                var text = step.Text;
                if (text == null || !text.Contains("usando o time")) continue;
                var nums = ExtractNumbers(text);
                if (nums.Count > 0) outSets.Add(nums);
            }
        }
        return outSets;
    }

    private static HashSet<int> ExtractNumbers(string text)
    {
        var set = new HashSet<int>();
        int i = 0;
        while (i < text.Length)
        {
            if (char.IsDigit(text[i]))
            {
                int j = i;
                while (j < text.Length && char.IsDigit(text[j])) j++;
                set.Add(int.Parse(text.Substring(i, j - i)));
                i = j;
            }
            else i++;
        }
        return set;
    }

    // MARK: - Ações

    public void JumpTo(EntryPoint entry, EntryGroup? group = null)
    {
        CurrentGroupName = group?.Name;
        Push();
        PathTrail = new List<string> { entry.Label };
        Goto(entry.NodeId, autoSkip: false);
        Notify();
    }

    /// Avança para a seleção de leads do PRÓXIMO treinador (Elite 4). Retorna o próximo grupo
    /// (ou null se for o campeão); a view usa o retorno para abrir a lista certa.
    public EntryGroup? AdvanceToNextGroup()
    {
        var nxt = NextGroup;
        if (nxt == null) return null;
        _history.Clear();
        _currentNodeId = null;
        _stepIndex = 0;
        CurrentGroupName = null;
        PathTrail = new();
        Notify();
        return nxt;
    }

    public void Choose(Option option)
    {
        Push();
        PathTrail = new List<string>(PathTrail) { option.Label };
        Goto(option.NodeId, autoSkip: false);
        Notify();
    }

    /// Pula esta parada e vai direto para a próxima.
    public void Skip()
    {
        var target = CurrentNode?.SkipTo;
        if (target == null) return;
        Push();
        Goto(target);
        Notify();
    }

    public void Next()
    {
        var node = CurrentNode;
        if (node == null) return;
        if (_stepIndex < node.Steps.Count - 1)
        {
            Push();
            _stepIndex++;
            Notify();
        }
        else if (node.Branch is { Kind: BranchKind.Goto } branch && branch.NodeId is string target)
        {
            Push();
            Goto(target);
            Notify();
        }
    }

    public void Back()
    {
        if (_history.Count == 0) return;
        var prev = _history.Pop();
        _currentNodeId = prev.nodeId;
        _stepIndex = prev.stepIndex;
        PathTrail = prev.trail;
        Notify();
    }

    public void Reset()
    {
        _history.Clear();
        _currentNodeId = null;
        _stepIndex = 0;
        CurrentGroupName = null;
        PathTrail = new();
        Notify();
    }

    // MARK: - Internos

    private void Push() => _history.Push((_currentNodeId, _stepIndex, new List<string>(PathTrail)));

    private void Goto(string id, bool autoSkip = true)
    {
        _currentNodeId = id;
        _stepIndex = 0;

        // Modo "revela tudo": mostra todos os passos de uma vez.
        if (Solve.RevealAll == true && CurrentNode is { } node0 && node0.Steps.Count > 0)
            _stepIndex = node0.Steps.Count - 1;

        // Cidade marcada como "pular": salta direto para a próxima.
        if (autoSkip && CurrentNode is { } node1 && node1.SkipTo is string target1
            && ShouldAutoSkip?.Invoke(id) == true)
        {
            Goto(target1, autoSkip: true);
            return;
        }

        // Nó "ponte": sem passos e com salto direto -> segue em frente.
        if (CurrentNode is { } node2 && node2.Steps.Count == 0
            && node2.Branch is { Kind: BranchKind.Goto } branch && branch.NodeId is string target2
            && target2 != id)
        {
            Goto(target2, autoSkip);
        }
    }
}
