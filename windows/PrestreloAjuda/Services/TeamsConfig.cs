using System.IO;
using System.Text.Json;

namespace PrestreloAjuda.Services;

/// Um time jogável (define qual conjunto de soluções a Elite 4 usa).
public sealed class TeamInfo
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    /// Sprite usado como ícone do time (data/sprites/<icon>.png).
    public string? Icon { get; set; }
    public List<string> Pokemon { get; set; } = new();
    public string? Pokepaste { get; set; }
    /// CODE do Pokeking pra extrair o time no jogo (mostrado no botão de fonte).
    public string? Code { get; set; }
    /// Se o time tem versão "Modo Emoji" (combate na notação original do autor).
    public bool HasEmoji { get; set; }
}

/// Manifesto data/teams.json: lista de times + quais modos variam por time.
public sealed class TeamsConfig
{
    public string Default { get; set; } = "";
    public List<string> TeamScopedModes { get; set; } = new();
    public List<TeamInfo> Teams { get; set; } = new();

    private static readonly JsonSerializerOptions Opts = new() { PropertyNameCaseInsensitive = true };

    public TeamInfo? Get(string id) => Teams.FirstOrDefault(t => t.Id == id);
    public bool IsTeamScoped(string modeId) => TeamScopedModes.Contains(modeId);

    public TeamInfo Resolve(string? id) =>
        (id != null ? Get(id) : null) ?? Get(Default) ?? Teams.FirstOrDefault()
        ?? new TeamInfo { Id = "default", Name = "Padrão" };

    public static TeamsConfig Load()
    {
        var path = Path.Combine(SolveLoader.DataDir, "teams.json");
        try
        {
            if (File.Exists(path))
                return JsonSerializer.Deserialize<TeamsConfig>(File.ReadAllText(path), Opts) ?? Fallback();
        }
        catch { /* cai no fallback */ }
        return Fallback();
    }

    /// Sem manifesto: um único "time" que lê os elite4 da raiz (compat retro).
    private static TeamsConfig Fallback() => new()
    {
        Default = "",
        TeamScopedModes = new(),
        Teams = new() { new TeamInfo { Id = "", Name = "Padrão" } }
    };
}
