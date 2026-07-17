import Foundation
import Combine

/// Estado do sistema de Cooldown/Alarme (#33): carrega o catálogo-semente, guarda os personagens
/// e as marcações do usuário (persistido em UserDefaults), calcula tempo restante e AGENDA os
/// alarmes. A verdade é sempre o timestamp absoluto (ms) — o alarme e o contador são derivados.
@MainActor
final class CooldownStore: ObservableObject {
    @Published private(set) var catalog: CooldownCatalog
    @Published private(set) var state: CooldownState

    let notifications = NotificationScheduler()
    private let defaultsKey = "cooldowns.state.v2"

    init() {
        catalog = CooldownCatalog.loadFromBundle()
        if let data = UserDefaults.standard.data(forKey: "cooldowns.state.v2"),
           let s = try? JSONDecoder().decode(CooldownState.self, from: data) {
            state = s
        } else {
            state = .current
        }
        reconcile()
    }

    /// Pede permissão de notificação (chamado no launch pelo AppDelegate).
    func start() { notifications.requestAuthIfNeeded() }

    // MARK: - Persistência

    private func touch() {
        state.updatedAt = nowMs()
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    /// Ao abrir: re-agenda os alarmes ainda no futuro (sobrevive a reinstalar o app / limpar pendências).
    private func reconcile() {
        for char in state.characters {
            for task in shownBattle(for: char) where isBattleActive(char, task) {
                scheduleBattle(char, task)
            }
            for berry in shownBerries where state.berry[berryKey(char, berry)] != nil {
                scheduleBerry(char, berry)
            }
        }
    }

    // MARK: - Personagens (cadastro)

    func addCharacter(name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        state.characters.append(GameCharacter(id: "char_" + shortId(), name: String(n.prefix(30))))
        touch()
    }

    func renameCharacter(_ id: String, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = state.characters.firstIndex(where: { $0.id == id }) else { return }
        state.characters[i].name = String(n.prefix(30))
        touch()
    }

    /// Define (ou limpa, com nil) a foto do boneco. `pngBase64` = PNG 128×128 já redimensionado.
    func setAvatar(_ id: String, pngBase64: String?) {
        guard let i = state.characters.firstIndex(where: { $0.id == id }) else { return }
        state.characters[i].avatar = pngBase64
        touch()
    }

    func removeCharacter(_ id: String) {
        state.characters.removeAll { $0.id == id }
        for k in state.battle.keys where k.hasPrefix(id + ":") { state.battle[k] = nil }
        for k in state.berry.keys where k.hasPrefix(id + ":") { state.berry[k] = nil }
        notifications.cancel(prefix: "cd.battle.\(id).")
        notifications.cancel(prefix: "cd.berry.\(id).")
        touch()
    }

    // MARK: - Tarefas de batalha

    /// Batalhas mostradas por boneco: as obrigatórias (defaultOn) sempre; as opcionais ficam num
    /// grupo à parte na UI (via `catalog.optionalTasks`).
    func shownBattle(for char: GameCharacter) -> [BattleTask] { catalog.battleTasks }

    private func battleKey(_ char: GameCharacter, _ id: String) -> String { "\(char.id):\(id)" }
    private func battleNotifId(_ char: GameCharacter, _ id: String) -> String { "cd.battle.\(char.id).\(id)" }

    func isBattleActive(_ char: GameCharacter, _ task: BattleTask) -> Bool {
        state.battle[battleKey(char, task.id)] != nil && battleRemainingMs(char, task) > 0
    }

    /// Ms restantes; <= 0 (ou nunca marcado) = pronto.
    func battleRemainingMs(_ char: GameCharacter, _ task: BattleTask) -> Double {
        guard let markedAt = state.battle[battleKey(char, task.id)] else { return 0 }
        return markedAt + task.hours * 3_600_000 - nowMs()
    }
    func battleReady(_ char: GameCharacter, _ task: BattleTask) -> Bool { battleRemainingMs(char, task) <= 0 }

    enum BattlePhase { case idle, running, ready }
    /// idle = nunca marcado · running = em cooldown · ready = já marcado e liberou.
    func battlePhase(_ char: GameCharacter, _ task: BattleTask) -> BattlePhase {
        guard state.battle[battleKey(char, task.id)] != nil else { return .idle }
        return battleRemainingMs(char, task) > 0 ? .running : .ready
    }

    func markBattle(_ char: GameCharacter, _ task: BattleTask) {
        state.battle[battleKey(char, task.id)] = nowMs()
        touch()
        scheduleBattle(char, task)
    }
    func clearBattle(_ char: GameCharacter, _ task: BattleTask) {
        state.battle[battleKey(char, task.id)] = nil
        notifications.cancel(id: battleNotifId(char, task.id))
        touch()
    }

    private func scheduleBattle(_ char: GameCharacter, _ task: BattleTask) {
        guard let markedAt = state.battle[battleKey(char, task.id)] else { return }
        notifications.schedule(
            id: battleNotifId(char, task.id),
            fireAtMs: markedAt + task.hours * 3_600_000,
            title: String(format: tr(.cdNotifReady), task.name.localized),
            body: String(format: tr(.cdNotifCharacter), char.name))
    }

    // MARK: - Berries

    /// Berries mostradas: as defaultOn + as que o usuário adicionou (enabledBerry).
    var shownBerries: [BerryDef] {
        catalog.berries.filter { $0.defaultOn || state.enabledBerry.contains($0.id) }
    }
    func addBerry(_ id: String) {
        guard !state.enabledBerry.contains(id) else { return }
        state.enabledBerry.append(id); touch()
    }
    func removeBerry(_ char: GameCharacter?, _ id: String) {
        state.enabledBerry.removeAll { $0 == id }
        // limpa plantios dessa berry (de todos os bonecos) + cancela alarmes
        for k in state.berry.keys where k.contains(":\(id):") { state.berry[k] = nil }
        for c in state.characters { notifications.cancel(prefix: "cd.berry.\(c.id).\(id).") }
        touch()
    }

    private func berryKey(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) -> String {
        "\(char.id):\(berry.id):\(plot)"
    }
    private func berryNotifPrefix(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) -> String {
        "cd.berry.\(char.id).\(berry.id).\(plot)."
    }

    enum BerryPhase { case empty, growing, ready, wilted }

    /// Instantâneo do canteiro: fase + os três tempos (plantar/regar/colher) + progresso de rega.
    struct BerryStatus {
        var phase: BerryPhase
        var harvestRemainMs: Double
        var nextWaterRemainMs: Double?
        var waterPending: Bool
        var waterings: Int      // regas já confirmadas
        var totalWaters: Int    // regas do tier no ciclo todo
    }

    /// Fase atual + tempos derivados do `plantedAt` + tier.
    func berryStatus(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) -> BerryStatus {
        guard let p = state.berry[berryKey(char, berry, plot: plot)],
              let tier = catalog.tier(berry.tier) else {
            return BerryStatus(phase: .empty, harvestRemainMs: 0, nextWaterRemainMs: nil,
                               waterPending: false, waterings: 0, totalWaters: 0)
        }
        let now = nowMs()
        let total = tier.waterWindowsHours.count
        let harvestAt = p.plantedAt + tier.growthHours * 3_600_000
        let wiltAt = harvestAt + tier.wiltHours * 3_600_000
        // próxima rega ainda não confirmada
        var nextWaterRemain: Double? = nil
        var pending = false
        if p.waterings < total {
            let limit = tier.waterWindowsHours[p.waterings] * 3_600_000
            let fireAt = p.plantedAt + limit - tier.waterLeadHours * 3_600_000
            nextWaterRemain = fireAt - now
            pending = now >= fireAt          // já entrou na janela de regar
        }
        let phase: BerryPhase = now < harvestAt ? .growing : (now < wiltAt ? .ready : .wilted)
        return BerryStatus(phase: phase, harvestRemainMs: harvestAt - now,
                           nextWaterRemainMs: nextWaterRemain, waterPending: pending,
                           waterings: p.waterings, totalWaters: total)
    }

    func plantBerry(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) {
        state.berry[berryKey(char, berry, plot: plot)] = BerryProgress(plantedAt: nowMs(), waterings: 0)
        touch()
        scheduleBerry(char, berry, plot: plot)
    }
    func waterBerry(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) {
        let key = berryKey(char, berry, plot: plot)
        guard var p = state.berry[key], let tier = catalog.tier(berry.tier),
              p.waterings < tier.waterWindowsHours.count else { return }
        p.waterings += 1
        state.berry[key] = p
        notifications.cancel(id: berryNotifPrefix(char, berry, plot: plot) + "w\(p.waterings - 1)")
        touch()
    }
    func harvestBerry(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) {
        state.berry[berryKey(char, berry, plot: plot)] = nil
        notifications.cancel(prefix: berryNotifPrefix(char, berry, plot: plot))
        touch()
    }

    private func scheduleBerry(_ char: GameCharacter, _ berry: BerryDef, plot: Int = 0) {
        guard let p = state.berry[berryKey(char, berry, plot: plot)],
              let tier = catalog.tier(berry.tier) else { return }
        let prefix = berryNotifPrefix(char, berry, plot: plot)
        let body = String(format: tr(.cdNotifCharacter), char.name)
        // lembretes de rega (a partir da próxima ainda não feita)
        for i in p.waterings..<tier.waterWindowsHours.count {
            let fireAt = p.plantedAt + (tier.waterWindowsHours[i] - tier.waterLeadHours) * 3_600_000
            notifications.schedule(id: prefix + "w\(i)", fireAtMs: fireAt,
                title: String(format: tr(.cdNotifWater), berry.name.localized), body: body)
        }
        // pronta pra colher
        let harvestAt = p.plantedAt + tier.growthHours * 3_600_000
        notifications.schedule(id: prefix + "harvest", fireAtMs: harvestAt,
            title: String(format: tr(.cdNotifBerryReady), berry.name.localized), body: body)
        // aviso de wilt (1h antes de murchar)
        let wiltAt = harvestAt + tier.wiltHours * 3_600_000
        notifications.schedule(id: prefix + "wilt", fireAtMs: wiltAt - 3_600_000,
            title: String(format: tr(.cdNotifWilt), berry.name.localized), body: body)
    }

    // MARK: - Dev (snapshot)

    /// Semeia um estado de DEMONSTRAÇÃO só em memória (NÃO persiste) — usado pelo `--cdshot`
    /// pra tirar screenshot da tela sem tocar no estado real do usuário.
    func seedDemoNoPersist() {
        var s = CooldownState.current
        let c = GameCharacter(id: "char_demo", name: "Vinicios1")
        // segundo boneco com FOTO (usa um retrato do bundle só pra demonstrar o avatar no snapshot)
        var alt = GameCharacter(id: "char_demo2", name: "Alt Farmer")
        if let url = Bundle.module.url(forResource: "cynthia", withExtension: "png", subdirectory: "trainers"),
           let d = try? Data(contentsOf: url) {
            alt.avatar = d.base64EncodedString()
        }
        s.characters = [c, alt]
        let now = nowMs()
        s.battle["char_demo:e4_sinnoh"] = now - 2 * 3_600_000     // em CD (6h → faltam 4h)
        s.battle["char_demo:red"] = now - 100 * 3_600_000         // em CD (168h)
        s.battle["char_demo:rota_farm"] = now - 6 * 3_600_000     // liberou (6h)
        s.berry["char_demo:berry_oran:0"] = BerryProgress(plantedAt: now - 1 * 3_600_000, waterings: 0)   // regar agora
        s.berry["char_demo:berry_leppa:0"] = BerryProgress(plantedAt: now - 3 * 3_600_000, waterings: 1)  // próxima rega em ~7h
        s.berry["char_demo:berry_sitrus:0"] = BerryProgress(plantedAt: now - 45 * 3_600_000, waterings: 3) // pronta
        state = s
    }

    // MARK: - Util

    private func shortId() -> String {
        let hex = "0123456789abcdef"
        return String((0..<8).map { _ in hex.randomElement()! })
    }
}

/// Formata ms restantes em "d h", "h m", "m s" ou "s" (igual ao protótipo).
func fmtRemain(_ ms: Double) -> String {
    if ms <= 0 { return "0s" }
    var s = Int((ms / 1000).rounded(.up))
    let d = s / 86400; s -= d * 86400
    let h = s / 3600; s -= h * 3600
    let m = s / 60; s -= m * 60
    if d > 0 { return "\(d)d \(h)h" }
    if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
    if m > 0 { return "\(m)m \(String(format: "%02d", s))s" }
    return "\(s)s"
}
