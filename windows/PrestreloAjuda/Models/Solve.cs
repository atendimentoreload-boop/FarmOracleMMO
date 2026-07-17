using System.Text.Json;
using System.Text.Json.Serialization;

namespace PrestreloAjuda.Models;

// Modelo data-driven (porte fiel do Solve.swift do app Mac).
// Uma "luta" (Solve) = coleção de nós + pontos de entrada. O motor não conhece nada
// específico de uma luta; basta trocar o JSON.

public sealed class Solve
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    /// Mensagem fixa na tela inicial (ex.: "Lidere com Infernape").
    public string? Lead { get; set; }
    /// Pergunta acima da grade de entradas (ex.: "O que o Red colocou?").
    public string? HomePrompt { get; set; }
    /// Título acima da lista de grupos (ex.: "Escolha a região:").
    public string? GroupPrompt { get; set; }
    /// Mostra o botão "pular" em cada entrada (rota de farm).
    public bool? AllowSkip { get; set; }
    /// Mostra TODOS os passos de um nó de uma vez (listas curtas de gym).
    public bool? RevealAll { get; set; }
    /// Aviso destacado (âmbar) na tela inicial do modo (ex.: 5ª vitória na Elite 4).
    public string? Warning { get; set; }
    /// Grupos feitos em ordem (Elite 4): habilita "Próximo treinador" e "Reiniciar" no campeão.
    public bool? SequentialGroups { get; set; }
    public List<LegendEntry>? Legend { get; set; }
    /// Link do Poképaste com o time exato a ser montado.
    public string? Pokepaste { get; set; }
    /// Link do documento oficial (Google Docs) da estratégia, se houver.
    public string? Doc { get; set; }
    /// Entradas diretas (quando NÃO há groups).
    public List<EntryPoint>? EntryPoints { get; set; }
    /// Agrupamento em duas etapas (região → cidade).
    public List<EntryGroup>? Groups { get; set; }
    public List<PaletteEntry>? Palette { get; set; }
    public Dictionary<string, Node> Nodes { get; set; } = new();
}

public sealed class PaletteEntry
{
    public string Name { get; set; } = "";
    public string Color { get; set; } = "";
    public List<string> Moves { get; set; } = new();
}

public sealed class EntryGroup
{
    public string Name { get; set; } = "";
    public List<EntryPoint> Entries { get; set; } = new();
    /// Arquivo (sem extensão) do retrato em data/trainers (ex.: "cynthia").
    public string? Portrait { get; set; }
}

public sealed class LegendEntry
{
    public string Term { get; set; } = "";
    public string Meaning { get; set; } = "";
}

public sealed class EntryPoint
{
    public string Label { get; set; } = "";
    public string NodeId { get; set; } = "";
    public string? Portrait { get; set; }
}

public sealed class Node
{
    public string Id { get; set; } = "";
    public string? Title { get; set; }
    public List<Step> Steps { get; set; } = new();
    public Branch? Branch { get; set; }
    /// Habilita "Pular esta parada" saltando direto para este nó (próxima cidade).
    public string? SkipTo { get; set; }
    public string? LeadHint { get; set; }
    /// Lead estruturado (Pokémon + item) mostrado no topo do ginásio.
    public List<GymLead>? GymLead { get; set; }
}

public sealed class GymLead
{
    public string Pokemon { get; set; } = "";
    public string? Item { get; set; }
}

public enum StepKind { Action, Note, Setup, Conditional }

public sealed class Step
{
    public string Id { get; set; } = "";
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public StepKind Kind { get; set; }
    public string? Text { get; set; }
    public ConditionalTable? Table { get; set; }
}

public sealed class ConditionalTable
{
    public string? Title { get; set; }
    public List<ConditionalRow> Rows { get; set; } = new();
}

public sealed class ConditionalRow
{
    public string Move { get; set; } = "";
    public List<string> Targets { get; set; } = new();
}

public enum BranchKind { Choice, Goto }

public sealed class Branch
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public BranchKind Kind { get; set; }
    public string? Prompt { get; set; }
    public List<Option>? Options { get; set; }
    public string? NodeId { get; set; }
}

public sealed class Option
{
    public string Label { get; set; } = "";
    public string NodeId { get; set; } = "";
}
