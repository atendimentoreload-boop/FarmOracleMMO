using System.IO;
using System.Text.Json;
using PrestreloAjuda.Engine;
using PrestreloAjuda.Models;

namespace PrestreloAjuda.Services;

/// Um modo (luta/rota) da biblioteca.
public sealed record Mode(
    string Id,
    string Title,
    string Subtitle,
    string Symbol,
    Solve Solve,
    string? Category = null,
    /// Retrato de treinador (data/trainers) usado como ícone do card. Ex.: "red", "lorelei".
    string? Portrait = null,
    /// Ícone de item (data/items) usado como ícone do card. Ex.: "amulet-coin".
    string? Item = null,
    /// Modo ainda sem conteúdo pronto: mostra o selo "em breve" no card (ex.: Ho-Oh).
    bool ComingSoon = false
)
{
    /// Link do Poképaste do time deste modo (vem do JSON / do time ativo).
    public string? Pokepaste => Solve.Pokepaste;
    /// Link do documento oficial (Google Docs) da estratégia, se houver.
    public string? Doc => Solve.Doc;
}

/// Uma rota de farm de ginásios (time + solve próprios), trocável nas Configurações.
/// `Id` é o nome do arquivo de solve ("veteran" / "6pillars_basic" / "lucky_girl"); `Pokemon` é o
/// sprite do menu; `Doc` é o Google Docs oficial da estratégia (quando houver).
/// Rotas do MESMO `TeamGroup` (mesmo time) são agrupadas num submenu; muda só a variante da rota.
/// `Variant` é o nome curto mostrado dentro do submenu (ex.: "Veteran", "BASIC").
public sealed record FarmRoute(string Id, string Name, string Roster, string Pokepaste,
    string Pokemon, string? Doc = null, string TeamGroup = "", string Variant = "");

/// Estratégia/time do modo Cynthia & Morimoto (solve + time próprios), trocável nas Configurações.
public sealed record CynthiaMorimotoStrategy(string Id, string Name, string Roster, string Pokepaste,
    string? Doc = null);

/// Estratégia/time do modo Red (solve + time próprios), trocável nas Configurações — igual ao Cynthia & Morimoto.
/// `Id` é o nome do arquivo de solve ("red" / "red_colored"); `Pokemon` é o sprite do menu; `Doc` é o Google Docs.
public sealed record RedStrategy(string Id, string Name, string Roster, string Pokepaste,
    string Pokemon, string? Doc = null);

/// Estratégia/time do modo Ho-Oh (rematch), trocável nas Configurações — igual ao Red.
/// `Id` é o nome do arquivo de solve ("hooh" / "hooh_trickroom"); `Pokemon` é o sprite; `Video` = YouTube.
public sealed record HoohStrategy(string Id, string Name, string Roster, string Pokepaste,
    string Pokemon, string? Video = null);

/// Guarda quais paradas o usuário marcou para pular (por modo). Persiste em
/// %LOCALAPPDATA%\PrestreloAjuda\skips.json (mesmo padrão do TeamPrefs).
/// Porte de SkipStore.swift/SkipStore.kt: carrega no construtor, salva a cada Toggle.
public sealed class SkipStore
{
    private static string Dir => System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PrestreloAjuda");
    private static string FilePath => System.IO.Path.Combine(Dir, "skips.json");

    // Chaves compostas "modeId::nodeId" das paradas marcadas para pular (serializadas como array).
    private readonly HashSet<string> _skipped;

    public SkipStore() { _skipped = Load(); }

    private static string Key(string modeId, string nodeId) => modeId + "::" + nodeId;

    public bool IsSkipped(string modeId, string nodeId) => _skipped.Contains(Key(modeId, nodeId));

    public void Toggle(string modeId, string nodeId)
    {
        var k = Key(modeId, nodeId);
        if (!_skipped.Add(k)) _skipped.Remove(k);
        Save();
    }

    private static HashSet<string> Load()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                var keys = JsonSerializer.Deserialize<string[]>(File.ReadAllText(FilePath));
                if (keys != null) return new HashSet<string>(keys);
            }
        }
        catch { /* best-effort */ }
        return new HashSet<string>();
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(Dir);
            File.WriteAllText(FilePath,
                JsonSerializer.Serialize(_skipped, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* persistência é best-effort */ }
    }
}

/// Estado global do app: biblioteca de modos + time ativo + modo atual + motor ativo.
public sealed class AppModel
{
    public TeamsConfig Teams { get; }
    public string ActiveTeamId { get; private set; }
    public bool EmojiMode { get; private set; }
    public Lang Language { get; private set; }
    /// Estratégia/time ativo do modo Cynthia & Morimoto (id do solve). Trocável nas Configurações.
    public string ActiveCmStrategyId { get; private set; }
    /// Estratégia/time ativo do modo Red (id do solve). Trocável nas Configurações.
    public string ActiveRedStrategyId { get; private set; }
    /// Estratégia/time ativo do modo Ho-Oh (id do solve). Trocável nas Configurações.
    public string ActiveHoohStrategyId { get; private set; }

    public TeamInfo ActiveTeam => Teams.Resolve(ActiveTeamId);
    public IReadOnlyList<TeamInfo> AvailableTeams => Teams.Teams;
    /// O modo Emoji só faz sentido (e só fica ligado) se o time ativo tiver versão emoji.
    public bool EmojiAvailable => ActiveTeam.HasEmoji;

    public List<Mode> Modes { get; private set; }
    public SkipStore Skips { get; } = new();

    /// Rota ativa do Farm de Ginásios (Six Pillars / Seven Hells). Escolhida nas Configurações.
    public string ActiveFarmRouteId { get; private set; }
    public FarmRoute ActiveFarmRoute => FarmRoutes.FirstOrDefault(r => r.Id == ActiveFarmRouteId) ?? FarmRoutes[0];

    /// Estratégia/time ativo do modo Red (Pós Choice Nerf / Colored). Escolhida nas Configurações.
    public RedStrategy ActiveRedStrategy => RedStrategies.FirstOrDefault(r => r.Id == ActiveRedStrategyId) ?? RedStrategies[0];

    /// Estratégia/time ativo do modo Ho-Oh (Allen - Yatsura / Trick Room). Escolhida nas Configurações.
    public HoohStrategy ActiveHoohStrategy => HoohStrategies.FirstOrDefault(r => r.Id == ActiveHoohStrategyId) ?? HoohStrategies[0];

    /// Rotas de farm cadastradas (fonte da verdade = Mac AppModel.swift / Android Modes.kt).
    /// Novas rotas entram aqui + um JSON `<id>.json` em /data (e /data/en).
    public static readonly IReadOnlyList<FarmRoute> FarmRoutes = new[]
    {
        new FarmRoute("veteran", "Six Pillars (Veteran Route)",
            "Typhlosion, Togekiss, Blastoise, Vanilluxe, Weezing, Garchomp",
            "https://pokepast.es/f00df8948e58939c", "garchomp",
            "https://docs.google.com/document/d/1XnFfsSVh1x5sEBLzvkletNfBuKY5ymSL_UHKNjoDaeE/edit",
            "six_pillars", "Veteran"),
        new FarmRoute("6pillars_basic", "Six Pillars (BASIC Route)",
            "Typhlosion, Togekiss, Blastoise, Vanilluxe, Weezing, Garchomp",
            "https://pokepast.es/f00df8948e58939c", "garchomp",
            "https://docs.google.com/document/d/1cWYvyJ7JxlkQqnrIeLZj0l_Yra0JKMuT2dIPwGwNjGA/edit",
            "six_pillars", "BASIC"),
        new FarmRoute("lucky_girl", "Seven Hells (Lucky Girl)",
            "Typhlosion, Blastoise, Vanilluxe, Aerodactyl, Excadrill, Meloetta",
            "https://pokepast.es/852ceef5515a4f85", "meloetta",
            null, "seven_hells", "Lucky Girl"),
    };

    /// Nome de exibição de um TeamGroup (cabeçalho do submenu de Farm). Porte do farmTeamName do Mac.
    public static string FarmTeamName(string group) => group switch
    {
        "six_pillars" => "Six Pillars",
        "seven_hells" => "Seven Hells (Lucky Girl)",
        _ => group,
    };

    /// TeamGroups do Farm na ordem de 1ª aparição (pro seletor agrupar preservando a ordem).
    public static IReadOnlyList<string> FarmTeamGroupsOrdered
    {
        get
        {
            var seen = new HashSet<string>();
            var outList = new List<string>();
            foreach (var r in FarmRoutes)
                if (seen.Add(r.TeamGroup)) outList.Add(r.TeamGroup);
            return outList;
        }
    }

    /// Rotas de Farm pertencentes a um TeamGroup (na ordem de cadastro).
    public static IReadOnlyList<FarmRoute> FarmRoutesIn(string group)
        => FarmRoutes.Where(r => r.TeamGroup == group).ToList();

    /// Estratégias cadastradas do modo Cynthia & Morimoto (fonte da verdade = Mac AppModel.swift / Android Modes.kt).
    /// Novas entram aqui + um JSON `<id>.json` em /data (e /data/en).
    public static readonly IReadOnlyList<CynthiaMorimotoStrategy> CynthiaMorimotoStrategies = new[]
    {
        new CynthiaMorimotoStrategy("cynthia_morimoto", "Metagross / Swellow (padrão)",
            "Metagross, Swellow, Umbreon, Garchomp ×2, Slowking",
            "https://pokepast.es/73afd6d7af99592f"),
        new CynthiaMorimotoStrategy("cynthia_morimoto_cadozz", "cadozz — Torterra/Scyther",
            "Chansey, Smeargle, Infernape, Torterra, Scyther",
            "https://pokepast.es/acbe0d2c63e3c68c",
            "https://forums.pokemmo.com/index.php?/topic/198035-beating-cynthia-fast-a-strategy-guide/"),
    };

    /// Estratégias cadastradas do modo Red (fonte da verdade = Mac AppModel.swift / Android Modes.kt).
    /// Novas entram aqui + um JSON `<id>.json` em /data (e /data/en).
    public static readonly IReadOnlyList<RedStrategy> RedStrategies = new[]
    {
        new RedStrategy("red", "Pós Choice Nerf (JinxedBoon)",
            "Infernape, Weavile, Jolteon, Bisharp, Breloom, Gliscor",
            "https://pokepast.es/8a207ad044e70c5a", "infernape",
            "https://docs.google.com/document/d/1dXaJNGqA2xjUACgcCshcIktBlCjcZgTT839O-Q1pGoA/edit"),
        new RedStrategy("red_colored", "Colored (ZzPSYCHOzZ)",
            "Blissey, Honchkrow, Gliscor, Lapras, Golduck, Breloom",
            "https://pokepast.es/433ccc371e07d52c", "blissey",
            "https://docs.google.com/document/d/1hcpaFvBere2nWb0C61PVqteTeouoNiMMsmln3YLmFk8/edit"),
    };

    /// Estratégias cadastradas do modo Ho-Oh (fonte da verdade = Mac AppModel.swift / Android Modes.kt).
    /// Novas entram aqui + um JSON `<id>.json` em /data (e /data/en).
    public static readonly IReadOnlyList<HoohStrategy> HoohStrategies = new[]
    {
        new HoohStrategy("hooh", "Allen - Yatsura",
            "Shuckle, Rotom, Ducklett",
            "https://pokepast.es/95c7ab2b67af6a1a", "rotom",
            "https://youtu.be/TR-8IkhyRJE"),
        new HoohStrategy("hooh_trickroom", "Trick Room (Lewis Nield)",
            "Chandelure, Rotom-Heat, Lunatone",
            "https://pokepast.es/bf35cfea0d1b7356", "chandelure",
            "https://youtu.be/_fcYxnPJKA0"),
    };

    public SolveEngine? Engine { get; private set; }
    public Mode? CurrentMode { get; private set; }

    public bool InMenu => Engine == null;
    public string? CurrentTitle => CurrentMode?.Title;

    /// Disparado quando algo muda (entra/sai de modo, troca de time/visual).
    public event Action? Changed;

    private AppModel(TeamsConfig teams, string activeTeamId, bool emoji, Lang language,
                    string farmRouteId, string cmStrategy, string redStrategy, string hoohStrategy)
    {
        Teams = teams;
        ActiveTeamId = activeTeamId;
        EmojiMode = emoji;
        Language = language;
        ActiveFarmRouteId = farmRouteId;
        ActiveCmStrategyId = cmStrategy;
        ActiveRedStrategyId = redStrategy;
        ActiveHoohStrategyId = hoohStrategy;
        Strings.Current = language;
        Modes = BuildModes();
    }

    // MARK: - Construção dos modos conforme time/visual

    private List<Mode> BuildModes()
    {
        var team = ActiveTeam;
        bool emoji = EmojiMode && team.HasEmoji;

        // Resolve o caminho de um modo: compartilhado (raiz) ou por time (teams/<id>[/emoji]/<nome>).
        string Path(string name)
        {
            if (!Teams.IsTeamScoped(name) || string.IsNullOrEmpty(team.Id)) return name;
            var b = "teams/" + team.Id + (emoji ? "/emoji" : "");
            return b + "/" + name;
        }

        Mode Elite(string name, string title, L subtitle)
        {
            var solve = SolveLoader.Load(Path(name), Language);
            solve.Pokepaste = team.Pokepaste;   // botão "?" mostra o Poképaste do time
            return new Mode(name, title, Strings.T(subtitle), "crown", solve, "Elite 4");
        }

        // A rota Veteran embute a luta de Cynthia & Morimoto no fim. Se o jogador escolheu a
        // estratégia cadozz de C&M, carrega a variante veteran_cadozz (injeta o TIME cadozz
        // nessa seção), pra bater com o time selecionado no menu de C&M. #veteran-cadozz
        string farmSolveName = (ActiveFarmRoute.Id == "veteran" && ActiveCmStrategyId == "cynthia_morimoto_cadozz")
            ? "veteran_cadozz" : ActiveFarmRoute.Id;

        // A ORDEM aqui é a ordem dos cards na home: Elite 4 (categoria) → Farm → Cynthia &
        // Morimoto → Red → Ho-Oh. O card de Configurações é renderizado à parte pelo picker.
        return new List<Mode>
        {
            Elite("elite4_kanto", "Kanto", L.ModeElite4KantoSubtitle),
            Elite("elite4_hoenn", "Hoenn", L.ModeElite4HoennSubtitle),
            Elite("elite4_unova", "Unova", L.ModeElite4UnovaSubtitle),
            Elite("elite4_sinnoh", "Sinnoh", L.ModeElite4SinnohSubtitle),
            Elite("elite4_johto", "Johto", L.ModeElite4JohtoSubtitle),
            // Farm de Ginásios: 1 modo só (id "veteran"); a rota ATIVA (Six Pillars / Seven Hells)
            // vem de ActiveFarmRoute (escolhida nas Configurações), igual ao Mac/Android.
            new("veteran", Strings.T(L.ModeGymFarmTitle),
                Strings.T(L.ModeGymFarmSubtitle), "map",
                SolveLoader.Load(farmSolveName, Language), Item: "gym"),
            // Cynthia & Morimoto: carrega o solve da estratégia ATIVA (selecionável nas Configurações).
            new("cynthia_morimoto", Strings.T(L.ModeCynthiaMorimotoTitle),
                Strings.T(L.ModeCynthiaMorimotoSubtitle), "crown",
                SolveLoader.Load(
                    (CynthiaMorimotoStrategies.FirstOrDefault(s => s.Id == ActiveCmStrategyId)
                        ?? CynthiaMorimotoStrategies[0]).Id, Language), Portrait: "cynthia"),
            // Red: carrega o solve da estratégia ATIVA (Pós Choice Nerf / Colored), selecionável nas Configurações.
            new("red", Strings.T(L.ModeRedTitle),
                Strings.T(L.ModeRedSubtitle), "bolt",
                SolveLoader.Load(
                    (RedStrategies.FirstOrDefault(s => s.Id == ActiveRedStrategyId)
                        ?? RedStrategies[0]).Id, Language), Portrait: "red"),
            // Ho-Oh: carrega o solve da estratégia ATIVA (Allen - Yatsura / Trick Room), selecionável nas Configurações.
            new("hooh", Strings.T(L.ModeHoohTitle), Strings.T(L.ModeHoohSubtitle), "bolt",
                SolveLoader.Load(
                    (HoohStrategies.FirstOrDefault(s => s.Id == ActiveHoohStrategyId)
                        ?? HoohStrategies[0]).Id, Language)),
        };
    }

    public void SetTeam(string id)
    {
        if (id == ActiveTeamId) return;
        ActiveTeamId = id;
        TeamPrefs.Team = id;
        if (!ActiveTeam.HasEmoji && EmojiMode) { EmojiMode = false; TeamPrefs.Emoji = false; }
        Rebuild();
    }

    /// Troca a rota ativa do Farm de Ginásios (Six Pillars / Seven Hells). Persiste e reconstrói.
    /// No-op se já for a ativa ou se o id não existir.
    public void SetFarmRoute(string id)
    {
        if (id == ActiveFarmRouteId || !FarmRoutes.Any(r => r.Id == id)) return;
        ActiveFarmRouteId = id;
        TeamPrefs.FarmRoute = id;
        Rebuild();
    }

    /// Troca a estratégia ativa do modo Cynthia & Morimoto (recarrega o solve dela e volta ao menu).
    public void SetCmStrategy(string id)
    {
        if (id == ActiveCmStrategyId) return;
        if (!CynthiaMorimotoStrategies.Any(s => s.Id == id)) return;
        ActiveCmStrategyId = id;
        TeamPrefs.CynthiaMorimotoStrategy = id;
        Rebuild();
    }

    /// Troca a estratégia/time ativo do modo Red (recarrega o solve dela e volta ao menu).
    public void SetRedStrategy(string id)
    {
        if (id == ActiveRedStrategyId) return;
        if (!RedStrategies.Any(s => s.Id == id)) return;
        ActiveRedStrategyId = id;
        TeamPrefs.RedStrategy = id;
        Rebuild();
    }

    /// Troca a estratégia/time ativo do modo Ho-Oh (recarrega o solve dela e volta ao menu).
    public void SetHoohStrategy(string id)
    {
        if (id == ActiveHoohStrategyId) return;
        if (!HoohStrategies.Any(s => s.Id == id)) return;
        ActiveHoohStrategyId = id;
        TeamPrefs.HoohStrategy = id;
        Rebuild();
    }

    public void ToggleEmoji()
    {
        if (!ActiveTeam.HasEmoji) return;
        EmojiMode = !EmojiMode;
        TeamPrefs.Emoji = EmojiMode;
        Rebuild();
    }

    /// Troca o idioma da interface (PT/EN). Reconstrói os modos (recarrega os JSON no idioma
    /// certo, com fallback PT) e volta ao menu. No-op se já estiver no idioma pedido.
    public void SetLanguage(Lang lang)
    {
        if (lang == Language) return;
        Language = lang;
        Strings.Current = lang;
        TeamPrefs.Language = Strings.Code(lang);
        Rebuild();
    }

    private void Rebuild()
    {
        Modes = BuildModes();
        Engine = null;            // troca de time/visual volta ao menu
        CurrentMode = null;
        Changed?.Invoke();
    }

    // MARK: - Modo atual

    public void Select(Mode mode)
    {
        var engine = new SolveEngine(mode.Solve)
        {
            ShouldAutoSkip = nodeId => Skips.IsSkipped(mode.Id, nodeId),
            DefaultPortrait = mode.Portrait,
            DefaultTrainerName = mode.Id == "red" ? "Red" : mode.Title,
        };
        Engine = engine;
        CurrentMode = mode;
        Changed?.Invoke();
    }

    public void ExitToMenu()
    {
        Engine = null;
        CurrentMode = null;
        Changed?.Invoke();
    }

    // MARK: - "Ver times" do adversário (porte fiel do AppModel.swift)

    /// Times possíveis do adversário no ponto atual do roteiro (pro overlay "Ver times").
    public sealed record PossibleOpponentTeams(
        List<OpponentTeam> Teams, bool Confirmed, string Trainer, string Lead);

    /// Calcula os times possíveis: base = todos os times do treinador que CONTÊM o lead;
    /// estreitada pelo lineList do roteiro (com segurança: filtro que zeraria é ignorado).
    /// Retorna null fora da Elite 4 ou quando não há dado pra mostrar.
    public PossibleOpponentTeams? PossibleOpponentTeamsNow()
    {
        var engine = Engine;
        if (engine == null || InMenu) return null;
        var region = OpponentCatalog.RegionName(engine.Solve.Id);
        if (region == null) return null;
        var group = engine.CurrentGroupName;
        if (string.IsNullOrEmpty(group)) return null;
        var lead = engine.PathTrail.FirstOrDefault();
        if (string.IsNullOrEmpty(lead)) return null;

        var key = OpponentCatalog.TrainerKey(region, group);
        var all = OpponentCatalog.Teams(region, key);
        if (all.Count == 0) return null;

        // Base: times que contêm o lead. Se nenhum casar, cai pra todos.
        var baseTeams = all.Where(t => t.Contains(lead)).ToList();
        var nums = new HashSet<int>((baseTeams.Count == 0 ? all : baseTeams).Select(t => t.Team));

        // Estreita pelo lineList; só aplica a interseção se ela NÃO zerar.
        foreach (var set in engine.LineNumberSetsAlongPath())
        {
            var inter = new HashSet<int>(nums);
            inter.IntersectWith(set);
            if (inter.Count > 0) nums = inter;
        }

        var teams = all.Where(t => nums.Contains(t.Team)).OrderBy(t => t.Team).ToList();
        if (teams.Count == 0) return null;
        return new PossibleOpponentTeams(teams, teams.Count == 1, group, lead);
    }

    /// Carrega o manifesto de times + preferências e monta a biblioteca.
    public static AppModel LoadDefault()
    {
        var teams = TeamsConfig.Load();
        var active = teams.Resolve(TeamPrefs.Team).Id;
        var emoji = TeamPrefs.Emoji && teams.Resolve(active).HasEmoji;
        var lang = Strings.ParseLang(TeamPrefs.Language);
        return new AppModel(teams, active, emoji, lang, TeamPrefs.FarmRoute, TeamPrefs.CynthiaMorimotoStrategy, TeamPrefs.RedStrategy, TeamPrefs.HoohStrategy);
    }
}
