using System.IO;
using System.Text.Json;

namespace PrestreloAjuda.Services;

/// Estado do sistema de Cooldown/Alarme (#33): carrega o catálogo-semente, guarda os personagens e
/// as marcações do usuário (persistido em %LOCALAPPDATA%\PrestreloAjuda\cooldowns.state.json),
/// calcula tempo restante e AGENDA os alarmes. Porte 1:1 de CooldownStore.swift do Mac —
/// a verdade é sempre o timestamp absoluto (ms); alarme e contador são derivados.
public sealed class CooldownStore
{
    public CooldownCatalog Catalog { get; }
    public CooldownState State { get; private set; }
    public CooldownNotifications Notifications { get; }

    private static string Dir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PrestreloAjuda");
    private static string FilePath => Path.Combine(Dir, "cooldowns.state.json");

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    public CooldownStore(CooldownNotifications? notifications = null)
    {
        Catalog = CooldownCatalog.Load();
        Notifications = notifications ?? new CooldownNotifications();
        State = LoadState();
        Reconcile();
    }

    // MARK: - Persistência

    private static CooldownState LoadState()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<CooldownState>(File.ReadAllText(FilePath), JsonOpts) ?? new CooldownState();
        }
        catch { /* decoder tolerante: qualquer falha → estado zerado */ }
        return new CooldownState();
    }

    private void Touch()
    {
        State.UpdatedAt = Cd.NowMs();
        try
        {
            Directory.CreateDirectory(Dir);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(State, JsonOpts));
        }
        catch { /* persistência é best-effort */ }
    }

    /// Ao abrir: re-agenda os alarmes ainda no futuro (sobrevive a fechar/reabrir o app).
    private void Reconcile()
    {
        foreach (var ch in State.Characters)
        {
            foreach (var task in ShownBattle(ch))
                if (IsBattleActive(ch, task)) ScheduleBattle(ch, task);
            foreach (var berry in ShownBerries)
                if (State.Berry.ContainsKey(BerryKey(ch, berry))) ScheduleBerry(ch, berry);
        }
    }

    // MARK: - Personagens (cadastro)

    public void AddCharacter(string name)
    {
        var n = name.Trim();
        if (n.Length == 0) return;
        State.Characters.Add(new GameCharacter { Id = "char_" + ShortId(), Name = Clip(n, 30) });
        Touch();
    }

    public void RenameCharacter(string id, string name)
    {
        var n = name.Trim();
        if (n.Length == 0) return;
        var c = State.Characters.FirstOrDefault(x => x.Id == id);
        if (c == null) return;
        c.Name = Clip(n, 30);
        Touch();
    }

    /// Define (ou limpa, com null) a foto do boneco. `pngBase64` = PNG 128×128 já redimensionado.
    public void SetAvatar(string id, string? pngBase64)
    {
        var c = State.Characters.FirstOrDefault(x => x.Id == id);
        if (c == null) return;
        c.Avatar = pngBase64;
        Touch();
    }

    public void RemoveCharacter(string id)
    {
        State.Characters.RemoveAll(x => x.Id == id);
        foreach (var k in State.Battle.Keys.Where(k => k.StartsWith(id + ":", StringComparison.Ordinal)).ToList())
            State.Battle.Remove(k);
        foreach (var k in State.Berry.Keys.Where(k => k.StartsWith(id + ":", StringComparison.Ordinal)).ToList())
            State.Berry.Remove(k);
        Notifications.CancelPrefix($"cd.battle.{id}.");
        Notifications.CancelPrefix($"cd.berry.{id}.");
        Touch();
    }

    // MARK: - Tarefas de batalha

    /// Batalhas mostradas por boneco: as obrigatórias (catalog.battleTasks). As opcionais ficam num
    /// grupo à parte na UI (via Catalog.OptionalTasks).
    public IReadOnlyList<BattleTask> ShownBattle(GameCharacter ch) => Catalog.BattleTasks;

    private static string BattleKey(GameCharacter ch, string id) => $"{ch.Id}:{id}";
    private static string BattleNotifId(GameCharacter ch, string id) => $"cd.battle.{ch.Id}.{id}";

    public bool IsBattleActive(GameCharacter ch, BattleTask task)
        => State.Battle.ContainsKey(BattleKey(ch, task.Id)) && BattleRemainingMs(ch, task) > 0;

    /// Ms restantes; <= 0 (ou nunca marcado) = pronto.
    public double BattleRemainingMs(GameCharacter ch, BattleTask task)
    {
        if (!State.Battle.TryGetValue(BattleKey(ch, task.Id), out var markedAt)) return 0;
        return markedAt + task.Hours * 3_600_000 - Cd.NowMs();
    }

    public bool BattleReady(GameCharacter ch, BattleTask task) => BattleRemainingMs(ch, task) <= 0;

    public enum BattlePhase { Idle, Running, Ready }

    /// Idle = nunca marcado · Running = em cooldown · Ready = já marcado e liberou.
    public BattlePhase Phase(GameCharacter ch, BattleTask task)
    {
        if (!State.Battle.ContainsKey(BattleKey(ch, task.Id))) return BattlePhase.Idle;
        return BattleRemainingMs(ch, task) > 0 ? BattlePhase.Running : BattlePhase.Ready;
    }

    public void MarkBattle(GameCharacter ch, BattleTask task)
    {
        State.Battle[BattleKey(ch, task.Id)] = Cd.NowMs();
        Touch();
        ScheduleBattle(ch, task);
    }

    public void ClearBattle(GameCharacter ch, BattleTask task)
    {
        State.Battle.Remove(BattleKey(ch, task.Id));
        Notifications.Cancel(BattleNotifId(ch, task.Id));
        Touch();
    }

    private void ScheduleBattle(GameCharacter ch, BattleTask task)
    {
        if (!State.Battle.TryGetValue(BattleKey(ch, task.Id), out var markedAt)) return;
        Notifications.Schedule(
            BattleNotifId(ch, task.Id),
            markedAt + task.Hours * 3_600_000,
            string.Format(Strings.T(L.CdNotifReady), task.Name.Localized),
            string.Format(Strings.T(L.CdNotifCharacter), ch.Name));
    }

    // MARK: - Berries

    /// Berries mostradas: as defaultOn + as que o usuário adicionou (EnabledBerry).
    public IReadOnlyList<BerryDef> ShownBerries =>
        Catalog.Berries.Where(b => b.DefaultOn || State.EnabledBerry.Contains(b.Id)).ToList();

    public void AddBerry(string id)
    {
        if (State.EnabledBerry.Contains(id)) return;
        State.EnabledBerry.Add(id);
        Touch();
    }

    public void RemoveBerry(GameCharacter? ch, string id)
    {
        State.EnabledBerry.RemoveAll(x => x == id);
        // limpa plantios dessa berry (de todos os bonecos) + cancela alarmes
        foreach (var k in State.Berry.Keys.Where(k => k.Contains($":{id}:", StringComparison.Ordinal)).ToList())
            State.Berry.Remove(k);
        foreach (var c in State.Characters) Notifications.CancelPrefix($"cd.berry.{c.Id}.{id}.");
        Touch();
    }

    private static string BerryKey(GameCharacter ch, BerryDef berry, int plot = 0) => $"{ch.Id}:{berry.Id}:{plot}";
    private static string BerryNotifPrefix(GameCharacter ch, BerryDef berry, int plot = 0) => $"cd.berry.{ch.Id}.{berry.Id}.{plot}.";

    public enum BerryPhase { Empty, Growing, Ready, Wilted }

    /// Instantâneo do canteiro: fase + tempos (plantar/regar/colher) + progresso de rega.
    public sealed class BerryStatus
    {
        public BerryPhase Phase;
        public double HarvestRemainMs;
        public double? NextWaterRemainMs;
        public bool WaterPending;
        public int Waterings;      // regas já confirmadas
        public int TotalWaters;    // regas do tier no ciclo todo
    }

    /// Fase atual + tempos derivados do PlantedAt + tier. (Nome BerryStat p/ não colidir com o tipo.)
    public BerryStatus BerryStat(GameCharacter ch, BerryDef berry, int plot = 0)
    {
        if (!State.Berry.TryGetValue(BerryKey(ch, berry, plot), out var p) ||
            Catalog.FindTier(berry.Tier) is not { } tier)
        {
            return new BerryStatus { Phase = BerryPhase.Empty };
        }
        double now = Cd.NowMs();
        int total = tier.WaterWindowsHours.Count;
        double harvestAt = p.PlantedAt + tier.GrowthHours * 3_600_000;
        double wiltAt = harvestAt + tier.WiltHours * 3_600_000;
        // próxima rega ainda não confirmada
        double? nextWaterRemain = null;
        bool pending = false;
        if (p.Waterings < total)
        {
            double limit = tier.WaterWindowsHours[p.Waterings] * 3_600_000;
            double fireAt = p.PlantedAt + limit - tier.WaterLeadHours * 3_600_000;
            nextWaterRemain = fireAt - now;
            pending = now >= fireAt;   // já entrou na janela de regar
        }
        var phase = now < harvestAt ? BerryPhase.Growing : (now < wiltAt ? BerryPhase.Ready : BerryPhase.Wilted);
        return new BerryStatus
        {
            Phase = phase,
            HarvestRemainMs = harvestAt - now,
            NextWaterRemainMs = nextWaterRemain,
            WaterPending = pending,
            Waterings = p.Waterings,
            TotalWaters = total,
        };
    }

    public void PlantBerry(GameCharacter ch, BerryDef berry, int plot = 0)
    {
        State.Berry[BerryKey(ch, berry, plot)] = new BerryProgress { PlantedAt = Cd.NowMs(), Waterings = 0 };
        Touch();
        ScheduleBerry(ch, berry, plot);
    }

    public void WaterBerry(GameCharacter ch, BerryDef berry, int plot = 0)
    {
        var key = BerryKey(ch, berry, plot);
        if (!State.Berry.TryGetValue(key, out var p) || Catalog.FindTier(berry.Tier) is not { } tier
            || p.Waterings >= tier.WaterWindowsHours.Count) return;
        p.Waterings += 1;
        State.Berry[key] = p;
        Notifications.Cancel(BerryNotifPrefix(ch, berry, plot) + "w" + (p.Waterings - 1));
        Touch();
    }

    public void HarvestBerry(GameCharacter ch, BerryDef berry, int plot = 0)
    {
        State.Berry.Remove(BerryKey(ch, berry, plot));
        Notifications.CancelPrefix(BerryNotifPrefix(ch, berry, plot));
        Touch();
    }

    private void ScheduleBerry(GameCharacter ch, BerryDef berry, int plot = 0)
    {
        if (!State.Berry.TryGetValue(BerryKey(ch, berry, plot), out var p) ||
            Catalog.FindTier(berry.Tier) is not { } tier) return;
        var prefix = BerryNotifPrefix(ch, berry, plot);
        var body = string.Format(Strings.T(L.CdNotifCharacter), ch.Name);
        // lembretes de rega (a partir da próxima ainda não feita)
        for (int i = p.Waterings; i < tier.WaterWindowsHours.Count; i++)
        {
            double fireAt = p.PlantedAt + (tier.WaterWindowsHours[i] - tier.WaterLeadHours) * 3_600_000;
            Notifications.Schedule(prefix + "w" + i, fireAt,
                string.Format(Strings.T(L.CdNotifWater), berry.Name.Localized), body);
        }
        // pronta pra colher
        double harvestAt = p.PlantedAt + tier.GrowthHours * 3_600_000;
        Notifications.Schedule(prefix + "harvest", harvestAt,
            string.Format(Strings.T(L.CdNotifBerryReady), berry.Name.Localized), body);
        // aviso de wilt (1h antes de murchar)
        double wiltAt = harvestAt + tier.WiltHours * 3_600_000;
        Notifications.Schedule(prefix + "wilt", wiltAt - 3_600_000,
            string.Format(Strings.T(L.CdNotifWilt), berry.Name.Localized), body);
    }

    // MARK: - Util

    private static string Clip(string s, int max) => s.Length > max ? s.Substring(0, max) : s;

    private static readonly Random Rng = new();
    private static string ShortId()
    {
        const string hex = "0123456789abcdef";
        var chars = new char[8];
        for (int i = 0; i < chars.Length; i++) chars[i] = hex[Rng.Next(hex.Length)];
        return new string(chars);
    }
}
