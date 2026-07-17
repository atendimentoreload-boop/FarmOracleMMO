using System.IO;
using System.Text.Json;

namespace PrestreloAjuda.Services;

// Catálogo dos times do adversário (Elite 4), extraído do Pokeking sem filtro de CODE.
// Porte fiel do OpponentCatalog.swift (Mac). Fonte: data/elite4-opponents.json (copiado de /data).
// Estrutura: regiões → treinador → [times]. Usado pelo overlay "Ver times".

public sealed class OpponentMon
{
    public string Pokemon { get; set; } = "";
    public string Ability { get; set; } = "";
    public string Item { get; set; } = "";
    public List<string> Moves { get; set; } = new();
}

public sealed class OpponentTeam
{
    public int Team { get; set; }                 // número "N号队伍" (bate com o lineList do roteiro)
    public List<OpponentMon> Pokemon { get; set; } = new();

    public bool Contains(string name)
    {
        var n = name.ToLowerInvariant();
        return Pokemon.Any(m => m.Pokemon.ToLowerInvariant() == n);
    }
}

public static class OpponentCatalog
{
    private sealed class CatalogFile
    {
        public Dictionary<string, Dictionary<string, List<OpponentTeam>>> Regions { get; set; } = new();
    }

    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true };

    private static Dictionary<string, Dictionary<string, List<OpponentTeam>>>? _regions;

    /// regiões → treinador → [times]. Carregado uma vez do data/. Fail-safe: vazio se faltar.
    public static Dictionary<string, Dictionary<string, List<OpponentTeam>>> Regions
    {
        get
        {
            if (_regions != null) return _regions;
            try
            {
                var path = Path.Combine(SolveLoader.DataDir, "elite4-opponents.json");
                var json = File.ReadAllText(path);
                _regions = JsonSerializer.Deserialize<CatalogFile>(json, Options)?.Regions ?? new();
            }
            catch { _regions = new(); }
            return _regions;
        }
    }

    /// `elite4_sinnoh` → `Sinnoh`. null para modos que não são da Elite 4.
    public static string? RegionName(string modeId) => modeId switch
    {
        "elite4_kanto" => "Kanto",
        "elite4_hoenn" => "Hoenn",
        "elite4_sinnoh" => "Sinnoh",
        "elite4_johto" => "Johto",
        "elite4_unova" => "Unova",
        _ => null,
    };

    /// Nome do grupo no roteiro → chave no catálogo. Casos especiais:
    /// Kanto "Gary" = campeão "Blue"; Johto "Bruno"/"Lance" distintos dos de Kanto.
    public static string TrainerKey(string region, string group)
    {
        if (region == "Johto")
        {
            if (group == "Bruno") return "Bruno (Johto)";
            if (group == "Lance") return "Lance (Johto)";
        }
        if (region == "Kanto" && group == "Gary") return "Blue";
        return group;
    }

    public static List<OpponentTeam> Teams(string region, string trainer) =>
        Regions.TryGetValue(region, out var t) && t.TryGetValue(trainer, out var teams)
            ? teams : new List<OpponentTeam>();
}
