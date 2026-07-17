using System.IO;
using System.Text.Json;

namespace PrestreloAjuda.Services;

// Modelo do sistema de Cooldown/Alarme (#33). Porte fiel de CooldownModel.swift do Mac.
// - CATÁLOGO: templates lidos de data/cooldowns.json (batalhas, tiers de berry, 64 berries).
// - ESTADO: o que o usuário criou/marcou (personagens + marcações), salvo em
//   %LOCALAPPDATA%\PrestreloAjuda\cooldowns.state.json (ver CooldownStore).
//
// Regra de robustez: a VERDADE é sempre um timestamp absoluto (epoch em MILISSEGUNDOS). Contador e
// alarme são derivados; reconciliar no startup a partir dos timestamps.

/// Utilidades do sistema de cooldown (funções livres do Mac: nowMs / fmtRemain / fmtHoursLabel).
public static class Cd
{
    /// Milissegundos desde 1970 (mesma base do protótipo web e do futuro sync).
    public static double NowMs() => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

    /// Formata ms restantes em "d h", "h m", "m s" ou "s" (igual ao protótipo / fmtRemain do Mac).
    /// 0 (ou negativo) → "0s"; arredonda para cima.
    public static string FmtRemain(double ms)
    {
        if (ms <= 0) return "0s";
        int s = (int)Math.Ceiling(ms / 1000.0);
        int d = s / 86400; s -= d * 86400;
        int h = s / 3600; s -= h * 3600;
        int m = s / 60; s -= m * 60;
        if (d > 0) return $"{d}d {h}h";
        if (h > 0) return $"{h}h {m:00}m";
        if (m > 0) return $"{m}m {s:00}s";
        return $"{s}s";
    }

    /// "6h", "18h", "7d" — rótulo curto de uma duração em horas (múltiplo de 24 vira dias).
    public static string FmtHoursLabel(double hours)
    {
        if (hours >= 24 && hours % 24 == 0) return $"{(int)(hours / 24)}d";
        return $"{(int)hours}h";
    }
}

// MARK: - Catálogo (data/cooldowns.json)

/// Nome bilíngue (PT/EN) vindo do catálogo.
public sealed class LocalizedName
{
    public string Pt { get; set; } = "";
    public string En { get; set; } = "";
    /// EN se o idioma atual for EN, senão PT (espelha `.localized` do Mac).
    public string Localized => Strings.Current == Lang.En ? En : Pt;
}

/// Tarefa de batalha com cooldown simples (um timer). Campos extras (type/note/source) são ignorados.
public sealed class BattleTask
{
    public string Id { get; set; } = "";
    public string Category { get; set; } = "";
    public LocalizedName Name { get; set; } = new();
    public double Hours { get; set; }
    public string Color { get; set; } = "#888888";
    public string Confidence { get; set; } = "";
    public bool DefaultOn { get; set; }
    /// Especificação do ícone: "region:x" | "trainer:x" | "item:x" | "sprite:x" | "sf:símbolo".
    /// null = cai no ponto colorido.
    public string? Icon { get; set; }
    /// Agrupador na UI (ex.: "elite4" junta as 5 ligas num submenu). null = tarefa avulsa.
    public string? Group { get; set; }
}

/// Tier de berry: a matemática do ciclo (uma vez), compartilhada por várias berries.
public sealed class BerryTier
{
    public string Tier { get; set; } = "";
    public double GrowthHours { get; set; }        // plantar -> pronta pra colher (fixo)
    public double WiltHours { get; set; }          // janela de colheita depois de pronta
    public List<double> WaterWindowsHours { get; set; } = new(); // limite (h após plantar) de cada rega
    public double WaterLeadHours { get; set; }     // disparar o lembrete tantas h ANTES do limite
    public string Yield { get; set; } = "";
    public string Id => Tier;
}

/// Uma berry específica (nome/ícone) que aponta pro seu tier.
public sealed class BerryDef
{
    public string Id { get; set; } = "";
    public string Tier { get; set; } = "";
    public LocalizedName Name { get; set; } = new();
    public bool Popular { get; set; }
    public bool DefaultOn { get; set; }
}

/// O catálogo-semente inteiro.
public sealed class CooldownCatalog
{
    public List<BattleTask> BattleTasks { get; set; } = new();
    public List<BattleTask> OptionalTasks { get; set; } = new();
    public List<BerryTier> BerryTiers { get; set; } = new();
    public List<BerryDef> Berries { get; set; } = new();

    public static readonly CooldownCatalog Empty = new();

    /// Todas as tarefas de batalha (obrigatórias + opcionais).
    public IEnumerable<BattleTask> AllBattle => BattleTasks.Concat(OptionalTasks);

    public BattleTask? FindBattleTask(string id) => AllBattle.FirstOrDefault(t => t.Id == id);
    public BerryDef? FindBerry(string id) => Berries.FirstOrDefault(b => b.Id == id);
    public BerryTier? FindTier(string id) => BerryTiers.FirstOrDefault(t => t.Tier == id);

    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true };

    /// Carrega o catálogo de data/cooldowns.json ao lado do executável (copiado de ../../data pelo
    /// csproj). Mesmo padrão do SolveLoader/AppModel. Falha silenciosa → catálogo vazio.
    public static CooldownCatalog Load()
    {
        try
        {
            var path = Path.Combine(SolveLoader.DataDir, "cooldowns.json");
            if (!File.Exists(path)) return Empty;
            return JsonSerializer.Deserialize<CooldownCatalog>(File.ReadAllText(path), Options) ?? Empty;
        }
        catch { return Empty; }
    }
}

// MARK: - Estado do usuário (persistido)

/// Um "boneco" (conta/ALT) cadastrado pelo usuário.
public sealed class GameCharacter
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    /// Foto do ícone (PNG 128×128 em base64). null = usa o monograma (1ª letra).
    public string? Avatar { get; set; }
}

/// Progresso de uma berry plantada num canteiro. `PlantedAt` é a verdade — tudo (colheita, wilt,
/// janelas de rega) deriva dele + do tier. `Waterings` = quantas regas o usuário já confirmou.
public sealed class BerryProgress
{
    public double PlantedAt { get; set; }   // ms
    public int Waterings { get; set; }
}

/// Estado completo do usuário. Salvo como um único blob JSON (preparado pra sync futuro).
/// Decoder tolerante: campos ausentes mantêm os defaults (System.Text.Json só seta o que existe).
public sealed class CooldownState
{
    public int Version { get; set; } = 2;
    public List<GameCharacter> Characters { get; set; } = new();
    /// "charId:battleTaskId" -> ms da marcação.
    public Dictionary<string, double> Battle { get; set; } = new();
    /// "charId:berryId:plot" -> progresso.
    public Dictionary<string, BerryProgress> Berry { get; set; } = new();
    /// Ids de tarefas de batalha que o usuário DESATIVOU (as defaultOn começam ligadas).
    public List<string> HiddenBattle { get; set; } = new();
    /// Ids de berries que o usuário ATIVOU além das defaultOn.
    public List<string> EnabledBerry { get; set; } = new();
    public double UpdatedAt { get; set; }
}
