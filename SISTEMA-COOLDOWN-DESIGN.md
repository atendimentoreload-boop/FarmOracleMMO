# Sistema de Cooldown/Alarme — Design (#33)

> Sistema separado dentro do FarmOracleMMO: um **"reloginho" no canto superior** abre a tela; o usuário **cadastra bonecos** (contas/ALTs) e tem **2 sub-telas — Batalhas** (CD de ligas/Elite 4, rotas de farm, Red, Cynthia & Morimoto) e **Berries** (plantar→regar→colher). Ao **marcar**, inicia o CD e **notifica no sistema (banner+som) na hora exata, mesmo com o app fechado**.
>
> Baseado no protótipo `cooldowns-pokemmo` (ver [[cooldowns-pokemmo-projeto]]) + mapeamento de arquitetura das 3 plataformas (workflow 04/07). **Nenhuma API foi inventada**; incertezas marcadas **[a confirmar por teste]**.

## ✅ Decisões travadas (04/07)
- **Rollout:** Mac primeiro (dev/teste) → depois Windows + Android com paridade.
- **Sincronização:** sincronizado PC ⇄ celular (o usuário quer marcar num e ver/avisar no outro). *Nota do design: o caminho mais seguro é entregar o alarme funcionando primeiro e plugar o sync com o `CooldownStore` já preparado pra isso — ver Fase 4.*
- **Aviso:** notificação do sistema (banner + som), **agendada** pra hora exata (dispara com app fechado). Não é alarme insistente.
- **Cadastro por BONECO** (conta/ALT).
- **Cynthia & Morimoto:** UM timer combinado, **20h** (travado pelo usuário 04/07). *(A pesquisa achou Morimoto ~24h / Cynthia sazonal, mas o usuário usa 20h na prática da rota — vale a palavra dele; editável na tela.)*
- **"Rota de Farm" = 20h** — mantido como está no protótipo (decisão do usuário; é uma rota própria do usuário, não bate com CD de batalha padrão).
- **Berries = ciclo COMPLETO com lembretes de rega** (plantar → regar nas janelas → colher → aviso de wilt 8h). Regas por tier vêm do catálogo (1 fonte) como **default editável** — a confirmar in-game: T1=1×, T2=2×, T3=3×, T4=3×, T5=4×; 1ª rega 7–8h, entre regas 12–15h.
- **Assinatura Mac:** `codesign` **ad-hoc** (grátis) no build-app.sh + CI; testar se basta pro alarme registrar antes de confiar.
- **Tempos:** **catálogo pesquisado com fontes** → ver **[SISTEMA-COOLDOWN-CATALOGO.md](SISTEMA-COOLDOWN-CATALOGO.md)**. Confirmados: Elite 4 (5 regiões) **6h** (timer começa ao **ENTRAR** na sala), Gym rerun **18h**, Red **168h**, **Morimoto ~24h**. **Cynthia e Morimoto são batalhas SEPARADAS** (Cynthia = ⚠️ 18h/24h sazonal, a confirmar). Berries: crescimento fixo por tier (Leppa **20h**) + **wilt/colheita 8h**; regas por tier = ⚠️ 1 fonte. **"Rota de Farm = 20h" do protótipo NÃO bate com nenhuma batalha** — a confirmar. Nunca chutar (ver [[seguir-guia-nunca-inventar]]).

---

## 1. Modelo de dados unificado
Um único blob JSON, **idêntico nas 3 plataformas e no protótipo** (chave da paridade e do sync). Cada plataforma só troca o tipo nativo que (de)serializa: Swift `Codable`, C# POCO (`System.Text.Json`), Kotlin `@Serializable`.

**Regra de robustez:** a VERDADE é sempre um **timestamp absoluto** (epoch ms / `Date`). Contador vivo e alarme agendado são **derivados**. Ao abrir app / ligar overlay / boot, **reconciliar** recomputando `ready`/`remain` — nunca confiar em timer em memória.

```json
{
  "version": 2,
  "characters": [ { "id": "char_a1b2c3", "name": "Meu Farmer" } ],
  "tasks": [
    { "id":"elite4", "type":"cooldown", "category":"liga", "name":{"pt":"Elite 4","en":"Elite 4"}, "hours":6,   "color":"#f59e0b", "paste":"https://pokepast.es/..." },
    { "id":"red",    "type":"cooldown", "category":"boss", "name":{"pt":"Red","en":"Red"},         "hours":168, "color":"#a855f7", "paste":"..." },
    { "id":"cynthia_morimoto", "type":"cooldown", "category":"boss", "name":{"pt":"Cynthia & Morimoto","en":"Cynthia & Morimoto"}, "hours":0, "color":"#38bdf8", "paste":"<rota-Veteran>" },
    { "id":"berry_leppa", "type":"berry", "category":"berry", "name":{"pt":"Leppa","en":"Leppa"}, "color":"#84cc16", "loop":true, "plots":1,
      "stages":[
        { "key":"plant",   "name":{"pt":"Plantar","en":"Plant"},   "hours":0 },
        { "key":"water",   "name":{"pt":"Regar","en":"Water"},     "hours":4 },
        { "key":"harvest", "name":{"pt":"Colher","en":"Harvest"},  "hours":8 }
      ] }
  ],
  "done": {
    "char_a1b2c3:elite4":        1720000000000,
    "char_a1b2c3:berry_leppa:0": { "stage":1, "at":1720000000000 }
  },
  "_mig": { "red":true, "paste":true, "berriesSeed":true },
  "updatedAt": 1720000000000
}
```

**Semântica (travada, igual ao protótipo):**
- **Cooldown simples:** `done[key]` = número (ms da marcação). `dur = hours*3600000`; `ready = !last || now-last >= dur`; `remain = dur-(now-last)`.
- **Berry (estágios):** `done[key]` = `{stage, at}` (`stage` = índice do ÚLTIMO passo feito). `nextStage = loop ? (stage+1)%N : min(stage+1,N-1)`; `nextReadyAt = at + stages[stage].hours*3600000`; clicar quando `ready` **AVANÇA** o estágio (não reinicia). **Convenção:** `stages[i].hours` = tempo que começa ao executar o passo `i` até o PRÓXIMO ficar disponível (`harvest.hours` = espera até replantar; `0` = imediato).
- **Chave de `done`:** `"<charId>:<taskId>"` (cooldown) / `"<charId>:<taskId>:<plot>"` (berry; MVP 1 canteiro `:0`).
- **Bilíngue obrigatório:** `name` sempre `{pt,en}` (ver [[bilingual-parity-pt-en]]).
- **`hours` sempre do guia/`data/`**, nunca chutado.
- **ID de alarme (estável, cross-plataforma):** `"cd::<charId>::<taskId>"` (+ `"::<plot>"`) — agendar/cancelar/reagendar idempotente.

**⚠️ Armadilha a corrigir do protótipo:** o `applyLoaded` copia só campos conhecidos e **descarta desconhecidos** → um build antigo apagaria os campos novos (berries/version) no próximo save. Todo loader nativo deve **preservar campos desconhecidos** e tratar `version`.

## 2. Persistência (mesmo blob nas 3, molde = `SkipStore`)
| Plataforma | Como | Molde | Chave/arquivo |
|---|---|---|---|
| **Mac** | `UserDefaults`, `CooldownStore: ObservableObject` (`@Published`), `JSONEncoder/Decoder`, injeta via `@EnvironmentObject` no AppDelegate | `SkipStore.swift` | `"cooldowns.v1"` |
| **Windows** | `System.Text.Json` → `File.WriteAllText` em `%LOCALAPPDATA%/PrestreloAjuda/`, instância no `AppModel` (UTC já é padrão) | `SkipStore` em `Services/AppModel.cs` | `cooldowns.json` |
| **Android** | `kotlinx.serialization` (já no projeto) → 1 string JSON em SharedPrefs; `Json{ignoreUnknownKeys=true}` | `SkipStore.kt` + `SolveLoader`/`TeamsConfig` | prefs `"cooldowns"` |

Salvar a cada marcar/limpar/cadastrar/avançar; reconciliar no startup.

### Sincronização PC ⇄ celular (reusa o protótipo)
- **Token de pareamento** `room` (32 hex/128 bits) guardado na config local de cada app (não na URL). Mesmo `room` nos 2 aparelhos = mesmo estado.
- Contrato idêntico: `GET/PUT /api/state?room=<hex>`, corpo = blob inteiro, KV `room:<id>`, cap 300KB. **Backend Cloudflare não muda.**
- Cliente replica `poll()` (~15s + ao focar) e `push` (debounce ~350ms); cache local = fonte offline.
- **Pareamento amigável:** gerar `room` no PC → **QR code / código curto** pro celular adotar.
- **Mudança obrigatória vs. protótipo:** trocar o LWW de documento inteiro por **merge do `done` por chave (maior `at`)** — berries têm vários timers em voo e o LWW de doc inteiro perderia dados. Manter `version` + loader tolerante; considerar HEAD/ETag pra não baixar o blob todo a cada poll.
- **Fronteira limpa:** o `CooldownStore` expõe load/save de blob → o sync pluga sem reescrever a UI.

## 3. Notificação/alarme — "dispara com o app FECHADO" (o ponto crítico)
Padrão comum: **timestamp persistido = verdade**; ao MARCAR grava no store **E** agenda no OS; ao LIMPAR/RE-MARCAR cancela por identificador e reagenda (idempotente). Sempre com **fallback in-app** (lista + badge no reloginho) recomputando por timestamp.

### Mac — `UserNotifications` (greenfield; tem 1 bloqueio real)
- **API:** `UNUserNotificationCenter` + `UNTimeIntervalNotificationTrigger`/`UNCalendarNotificationTrigger` + `add(request)`. Uma vez aceito, o daemon `usernoted` **entrega mesmo com o app QUIT**. Cancelar via `removePendingNotificationRequests(withIdentifiers:)`.
- **Permissão:** `requestAuthorization([.alert,.sound])` uma vez. `.accessory`/LSUIElement **não** impede. Delegate no AppDelegate.
- **🔴 BLOQUEIO #1:** o app é distribuído **SEM ASSINATURA** (`build-app.sh` e o CI não fazem `codesign`). Sem assinatura, `requestAuthorization` costuma falhar (`UNErrorDomain Code=1`) e `add()` não agenda. **Fix:** `codesign --force --deep --sign -` (ad-hoc, bundle ID estável `com.reload.prestreloajuda`) no build-app.sh **e** no release.yml. **[a confirmar por teste]** se ad-hoc basta na máquina.
- **Riscos:** Mac precisa estar ligado/logado (CD que vence com a tampa fechada só apita ao acordar); usuário pode negar (fallback in-app); limite de **64 pendentes** → agendar só CDs ativos.

### Windows — `ScheduledToastNotification` (encaixe perfeito; faltam 2 mudanças de build)
- **API:** `ToastNotificationManagerCompat.CreateToastNotifier().AddToSchedule(new ScheduledToastNotification(xml, deliveryTime))` — a hora de disparo já é conhecida ao marcar → Windows dispara **com o processo fechado**. Cancelar via `RemoveFromSchedule`.
- **🟠 Faltam (zero infra hoje):** (1) **TFM** — `net8.0-windows` não projeta WinRT → subir p/ `net8.0-windows10.0.19041.0` **ou** NuGet `CommunityToolkit.WinUI.Notifications`. (2) **Identidade (app unpackaged)** — toast agendado c/ app fechado + ativação ao clicar exigem AUMID + atalho no Menu Iniciar + ativador COM; o **`ToastNotificationManagerCompat` cria isso automaticamente no 1º uso** (Win32 sem pacote).
- **Fallback (app aberto):** `DispatcherTimer` + banner no overlay + `System.Media.SystemSounds`. Ideal = os dois juntos.
- **Riscos:** Focus Assist / fullscreen exclusivo suprime toasts; **testar o .exe PUBLICADO** single-file (não `dotnet run`) — **[a confirmar]** interop WinRT no single-file.

### Android — `AlarmManager.setExactAndAllowWhileIdle` (viável; MIUI é o maior risco)
- **API:** `setExactAndAllowWhileIdle(RTC_WAKEUP, endAtMillis, pendingIntent)` → `BroadcastReceiver` → `NotificationCompat` num **canal novo `"cooldowns"` IMPORTANCE_HIGH** (heads-up/som; separado do canal LOW do foreground service). Dispara com app fechado, inclusive em Doze. **WorkManager não serve** (mín. 15 min, inexato).
- **Permissões:** distribuição é **APK direto (não Play)** → `USE_EXACT_ALARM` concedida na instalação sem prompt (evita a dança do runtime-grant). Declarar também `SCHEDULE_EXACT_ALARM`; em API 31–32 checar `canScheduleExactAlarms()`. `POST_NOTIFICATIONS` **já resolvida**.
- **Boot:** `RECEIVE_BOOT_COMPLETED` + `BootReceiver` reagenda a partir dos timestamps. **Maior alavanca:** acoplar o alarme ao **foreground `OverlayService`** (já existe) → muito mais confiável no Xiaomi.
- **🔴 Riscos (o device de teste é Xiaomi):** MIUI mata background e bloqueia Autostart por padrão → sem foreground ativo os alarmes podem sumir. Exige o usuário habilitar **Autostart + Bateria "Sem restrições" + travar nos recentes** (não dá 100% por código → guia in-app). POST_NOTIFICATIONS negada → fallback in-app.

## 4. UI — reloginho + Batalhas/Berries (reusar o que existe)
- **Entrada:** Mac = `iconButton("clock")` no `HeaderBar` (ContentView); Windows = `Glyph(<relógio MDL2>)` no `BuildHeader()`; Android = `ChromeBtn("⏰")` na barra do `OverlayPanel` (+ `ModeCard` no modo "Abrir aqui").
- **Navegação:** roteador por flag que já existe (não há NavigationStack em nenhuma) — Mac `@State showCooldowns` + ramo no `Group`; Windows `_showCooldown` + `RenderCooldown()`; Android flag no `AppState` + ramo no `when` do `AppRoot`.
- **Tela (idêntica ao SettingsView):** lista principal = **bonecos**; cada boneco → sub-telas **Batalhas** e **Berries** (sub-painel interno, mesmo padrão do Settings). Cada tarefa = linha com **"Fazer agora"** (verde/acionável) ou tempo restante + barra; berry mostra o **próximo passo** e clicar **avança o estágio**. Reusar `settingsGroup`/`navRow`/`toggleRow`/`CollapsibleTeamGroup`/`Theme.*`. i18n obrigatório.
- **📇 Cadastro de personagens (peça central — reforçado pelo usuário 04/07):** na tela do reloginho, um campo **"+ Adicionar boneco"** (nome, máx ~30 chars) cria o personagem (id via uuid); cada boneco vira uma linha com **✎ renomear** e **✕ remover** (remove também as marcações `done` daquele boneco). Opcional: escolher um **ícone/sprite** pro boneco (reusar `PokemonIcon`/`AssetImage`). Igual ao protótipo `cooldowns-pokemmo` (`addChar`/`renameChar`/`removeChar`), mas nativo. É o que amarra tudo: as tarefas (Batalhas/Berries) são por **(boneco × tarefa)**.

## 5. Plano de fases (Mac → paridade)
Antes de portar: `python3 tools/parity/check.py --gate <plataforma>` + cadastrar a feature em `features.json` (ver [[sistema-de-paridade]]).

- **Fase 0 — Modelo + dados (compartilhado):** ✅ **catálogo-semente `data/cooldowns.json` criado (04/07)** — 9 batalhas + 6 opcionais + 5 berryTiers + 64 berries (bilíngue; tempos do [SISTEMA-COOLDOWN-CATALOGO.md](SISTEMA-COOLDOWN-CATALOGO.md)); esquema de estado v2 (characters + done) documentado no próprio arquivo. **Falta (na Fase 1, junto do 1º port):** loader que preserva campos desconhecidos + matemática cooldown/berry com retrocompat (`number | {stage,at}`) + testes.
- **Fase 1 — Mac MVP + alarme:** ✅ **IMPLEMENTADO (04/07):** `CooldownModel`/`CooldownStore` (molde SkipStore, carrega `cooldowns.json`), `NotificationScheduler` (UserNotifications: permissão + agendar/cancelar por id + delegate), `CooldownView` (reloginho `clock.arrow.circlepath` no HeaderBar → **cadastro de personagens** + abas **Batalhas** (9 CDs + opcionais recolhidos) + **Berries** (10 default + biblioteca de 64 por tier: plantar→regar→colher→wilt)), wiring ContentView/AppDelegate, 30 chaves i18n PT/EN, `codesign` ad-hoc no build-app.sh. **Compila, builda, ASSINA (`valid on disk`), abre sem crash.**
  - **✅ Risco #1 RESOLVIDO:** ad-hoc signing **basta** — o app registra no sistema de notificações do macOS (retorna `authStatus` real, não erro). O bloqueio era só a assinatura.
  - **⚙️ Descoberta do build:** pro `codesign` passar, o bundle de recursos tem que ficar **só em `Contents/Resources`** (cópia na raiz do .app / `Contents/MacOS` = "unsealed contents" → falha). Corrigido: local assina com 1 cópia; as cópias-extra (Bundle.module do CI) ficam **só no CI** (que não assina). **TODO:** assinar a RELEASE no CI sem a cópia da raiz.
  - **✅ ENTREGA CONFIRMADA (04/07):** com a permissão habilitada, o `--notiftest` agendou uma notificação, o processo SAIU (nada do FarmOracle rodando) e 10s depois o macOS **entregou** (`--notifcheck` → `delivered=["notiftest"]`). **Alarme com o app FECHADO provado end-to-end.** (Obs.: a permissão tinha ficado `denied` pelas aberturas sem assinatura de hoje — resolvido habilitando em Ajustes > Notificações. Hooks dev `--notiftest`/`--notifcheck` no main.swift.)
- **Fase 2 — Windows (paridade):** TFM/NuGet; `cooldowns.json`; reloginho + `RenderCooldown()`; `ToastNotificationManagerCompat.AddToSchedule` + fallback. Marco: **testar o .exe publicado** — CD, fechar, toast dispara, clique reabre.
- **Fase 3 — Android (paridade):** `CooldownStore` (kotlinx); reloginho + `CooldownsScreen`; canal HIGH + `setExactAndAllowWhileIdle` + receiver + `BootReceiver`; acoplar ao foreground service; guia MIUI. Marco (device Xiaomi via adb): dispara com app fora dos recentes; sobrevive a reboot.
- **Fase 4 (sync) — PC ⇄ celular:** só depois do alarme estável nas 3. Reusar room/KV com **merge de `done` por chave (max `at`)** + pareamento por QR.

**Maiores riscos de bug:** app fechado (assinatura Mac / identidade Win / alarme exato + foreground + Autostart MIUI); fuso/relógio (clock skew → CD errado e LWW "viaja no tempo"); sync concorrente (LWW de doc → usar merge por chave); limite de agendamentos (64 no Mac, Doze no Android) → agendar só CDs ativos.

## 6. Decisões abertas (precisam de você)
1. **Assinatura no Mac:** OK adicionar `codesign` ad-hoc no `build-app.sh` e no CI? (pré-requisito do alarme). Ou já partir pra Developer ID?
2. **Windows:** subir o TFM pra alvo Win10 **ou** adotar o NuGet `CommunityToolkit.WinUI.Notifications` (hoje o projeto tem zero NuGet)?
3. **Cynthia & Morimoto** tem cooldown real (quantas horas?) ou é só atalho pro pokepaste sem timer?
4. **Berries do MVP:** quais berries e se precisa de **múltiplos canteiros** por boneco já no v1 (ou 1 canteiro e evoluir).
5. **Bonecos:** pré-cadastrar puxando do time ativo ou cadastro 100% manual na tela?
6. **Tempos exatos** (catálogo em pesquisa): Elite 4 por região? Rotas? Red 168h? Cynthia&Morimoto? ciclo de cada berry.
